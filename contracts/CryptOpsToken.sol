// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CryptOps Protocol Token ($COPS)
 * @notice Fixed-Supply ERC-20 + EIP-2612 Permit Token for the CryptOps Pre-Broadcast Firewall & Verifier Network.
 * @dev Deterministic architecture:
 *      - Fixed 100,000,000 (100M) total supply minted once at deployment (no mint() function exists).
 *      - Zero transfer taxes, zero blacklists, zero pausable locks, zero proxy upgradeability.
 *      - Built-in burn() and EIP-2612 gasless permit() support.
 */
contract CryptOpsToken {
    string public constant name = "CryptOps Protocol";
    string public constant symbol = "COPS";
    uint8 public constant decimals = 18;
    uint256 public totalSupply = 100_000_000 * 10 ** 18; // 100 Million Fixed Supply

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(address treasuryReserve, address liquidityAndNodeVault) {
        require(treasuryReserve != address(0) && liquidityAndNodeVault != address(0), "COPS: zero address");

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );

        // 65% to Liquidity Ladder, Staking & Node Vaults | 35% to Protocol Treasury Reserve
        uint256 vaultAllocation = (totalSupply * 65) / 100;
        uint256 reserveAllocation = totalSupply - vaultAllocation;

        balanceOf[liquidityAndNodeVault] = vaultAllocation;
        balanceOf[treasuryReserve] = reserveAllocation;

        emit Transfer(address(0), liquidityAndNodeVault, vaultAllocation);
        emit Transfer(address(0), treasuryReserve, reserveAllocation);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        return _transfer(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "COPS: insufficient allowance");
            allowance[from][msg.sender] = allowed - value;
        }
        return _transfer(from, to, value);
    }

    function burn(uint256 value) external {
        require(balanceOf[msg.sender] >= value, "COPS: burn exceeds balance");
        balanceOf[msg.sender] -= value;
        totalSupply -= value;
        emit Transfer(msg.sender, address(0), value);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "COPS: permit expired");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recovered = ecrecover(digest, v, r, s);
        require(recovered != address(0) && recovered == owner, "COPS: invalid signature");
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint256 value) internal returns (bool) {
        require(to != address(0), "COPS: transfer to zero");
        require(balanceOf[from] >= value, "COPS: insufficient balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}
