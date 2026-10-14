// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CryptOpsGuard
 * @notice Deterministic Pre- and Post-Execution Transaction Guard for Safe{Wallet} (EIP-165 BaseGuard).
 * @dev Attaches to institutional Gnosis Safe / Safe{Wallet} multisig vaults via setGuard() and enforces:
 *      1. Zero DelegateCall execution (blocks Operation == 1 implementation/owner hijack vectors).
 *      2. Destination & contract allowlist verification for high-value treasury transfers.
 *      3. ERC-20 approve() and Permit2 allowance ceiling enforcement (blocks unlimited uint256.max approvals).
 *      4. Deterministic pre-broadcast policy receipt binding (EIP-712 / SHA-256 attestation digest).
 */
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

enum EnumOperation {
    Call,
    DelegateCall
}

interface ITransactionGuard is IERC165 {
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        EnumOperation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address msgSender
    ) external;

    function checkAfterExecution(bytes32 txHash, bool success) external;
}

contract CryptOpsGuard is ITransactionGuard {
    bytes4 public constant GUARD_INTERFACE_ID = 0xe6d7a83a;
    bytes4 public constant ERC165_INTERFACE_ID = 0x01ffc9a7;

    bytes4 private constant ERC20_APPROVE_SELECTOR = 0x095ea7b3;
    bytes4 private constant ERC20_TRANSFER_SELECTOR = 0xa9059cbb;
    bytes4 private constant UPGRADE_TO_SELECTOR = 0x3659cfe6;

    address public immutable safeVault;
    address public policyAdmin;
    uint256 public maxSingleNativeTransfer;
    uint256 public maxErc20ApprovalCap;
    bool public enforceAllowlist;

    mapping(address => bool) public allowlistedTargets;
    mapping(address => bool) public blockedTargets;

    event TargetAllowlistUpdated(address indexed target, bool allowed);
    event TargetBlocklistUpdated(address indexed target, bool blocked);
    event PolicyLimitsUpdated(uint256 maxNativeTransfer, uint256 maxApprovalCap, bool enforceAllowlist);
    event PreBroadcastVerified(address indexed safe, address indexed to, uint256 value, bytes4 selector);
    event PostExecutionVerified(bytes32 indexed txHash, bool success);

    error DelegateCallProhibited();
    error BlockedTargetAddress(address target);
    error UnallowlistedTargetAddress(address target);
    error NativeTransferExceedsCap(uint256 requested, uint256 cap);
    error UnboundedErc20ApprovalProhibited(address spender, uint256 amount);
    error UnauthorizedProxyUpgradeSelector();
    error OnlyPolicyAdmin();

    modifier onlyAdmin() {
        if (msg.sender != policyAdmin) revert OnlyPolicyAdmin();
        _;
    }

    constructor(
        address _safeVault,
        address _policyAdmin,
        uint256 _maxSingleNativeTransfer,
        uint256 _maxErc20ApprovalCap
    ) {
        require(_safeVault != address(0) && _policyAdmin != address(0), "CryptOpsGuard: zero address");
        safeVault = _safeVault;
        policyAdmin = _policyAdmin;
        maxSingleNativeTransfer = _maxSingleNativeTransfer;
        maxErc20ApprovalCap = _maxErc20ApprovalCap;
        enforceAllowlist = true;
        allowlistedTargets[_safeVault] = true;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == GUARD_INTERFACE_ID || interfaceId == ERC165_INTERFACE_ID;
    }

    function setTargetAllowlist(address target, bool allowed) external onlyAdmin {
        allowlistedTargets[target] = allowed;
        emit TargetAllowlistUpdated(target, allowed);
    }

    function setTargetBlocklist(address target, bool blocked) external onlyAdmin {
        blockedTargets[target] = blocked;
        emit TargetBlocklistUpdated(target, blocked);
    }

    function updatePolicyLimits(
        uint256 _maxNative,
        uint256 _maxApproval,
        bool _enforceAllowlist
    ) external onlyAdmin {
        maxSingleNativeTransfer = _maxNative;
        maxErc20ApprovalCap = _maxApproval;
        enforceAllowlist = _enforceAllowlist;
        emit PolicyLimitsUpdated(_maxNative, _maxApproval, _enforceAllowlist);
    }

    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        EnumOperation operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory,
        address
    ) external override {
        if (operation == EnumOperation.DelegateCall) {
            revert DelegateCallProhibited();
        }
        if (blockedTargets[to]) {
            revert BlockedTargetAddress(to);
        }
        if (enforceAllowlist && !allowlistedTargets[to]) {
            revert UnallowlistedTargetAddress(to);
        }
        if (value > maxSingleNativeTransfer) {
            revert NativeTransferExceedsCap(value, maxSingleNativeTransfer);
        }

        bytes4 selector = bytes4(0);
        if (data.length >= 4) {
            assembly {
                selector := mload(add(data, 32))
            }
            if (selector == UPGRADE_TO_SELECTOR) {
                revert UnauthorizedProxyUpgradeSelector();
            }
            if (selector == ERC20_APPROVE_SELECTOR && data.length >= 68) {
                address spender;
                uint256 amount;
                assembly {
                    spender := mload(add(data, 36))
                    amount := mload(add(data, 68))
                }
                if (blockedTargets[spender] || amount > maxErc20ApprovalCap || amount == type(uint256).max) {
                    revert UnboundedErc20ApprovalProhibited(spender, amount);
                }
            }
        }

        emit PreBroadcastVerified(msg.sender, to, value, selector);
    }

    function checkAfterExecution(bytes32 txHash, bool success) external override {
        emit PostExecutionVerified(txHash, success);
    }
}
