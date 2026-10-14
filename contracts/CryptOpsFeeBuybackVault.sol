// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CryptOpsFeeBuybackVault
 * @notice On-Chain Verifier Staking & Protocol Fee Distribution Vault for $COPS.
 * @dev Core protocol staking and fee-settlement functions:
 *      1. Verifier Staking Lockup: Enforces a 14-day cooldown window for active verifier node operators.
 *      2. Deterministic Fee Settlement: Distributes USDC protocol verification fees pro-rata to active stakers.
 */

interface IERC20Minimal {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CryptOpsFeeBuybackVault {
    IERC20Minimal public immutable copsToken;
    IERC20Minimal public immutable usdcToken;
    address public immutable owner;

    uint256 public constant COOLDOWN_PERIOD = 14 days;
    uint256 public totalStaked;
    uint256 public accUsdcPerShare; // Scaled by 1e18
    uint256 public totalUsdcDistributed;

    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 unstakeAvailableAt;
    }

    mapping(address => StakeInfo) public stakes;

    event Staked(address indexed user, uint256 amount);
    event UnstakeRequested(address indexed user, uint256 unlockTimestamp);
    event Withdrawn(address indexed user, uint256 amount);
    event ProtocolUsdcRevenueInjected(address indexed source, uint256 usdcAmount, uint256 cumulativeUsdc);
    event UsdcYieldClaimed(address indexed user, uint256 usdcAmount);

    constructor(address _copsToken, address _usdcToken) {
        copsToken = IERC20Minimal(_copsToken);
        usdcToken = IERC20Minimal(_usdcToken);
        owner = msg.sender;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Vault: zero amount");
        StakeInfo storage user = stakes[msg.sender];
        _harvest(msg.sender);

        require(copsToken.transferFrom(msg.sender, address(this), amount), "Vault: transfer failed");
        user.amount += amount;
        user.unstakeAvailableAt = block.timestamp + COOLDOWN_PERIOD;
        totalStaked += amount;
        user.rewardDebt = (user.amount * accUsdcPerShare) / 1e18;

        emit Staked(msg.sender, amount);
    }

    function injectProtocolUsdcRevenue(uint256 usdcAmount) external {
        require(usdcAmount > 0 && totalStaked > 0, "Vault: invalid injection");
        require(usdcToken.transferFrom(msg.sender, address(this), usdcAmount), "Vault: USDC transfer failed");
        accUsdcPerShare += (usdcAmount * 1e18) / totalStaked;
        totalUsdcDistributed += usdcAmount;

        emit ProtocolUsdcRevenueInjected(msg.sender, usdcAmount, totalUsdcDistributed);
    }

    function claimUsdcYield() external {
        _harvest(msg.sender);
        StakeInfo storage user = stakes[msg.sender];
        user.rewardDebt = (user.amount * accUsdcPerShare) / 1e18;
    }

    function withdraw(uint256 amount) external {
        StakeInfo storage user = stakes[msg.sender];
        require(user.amount >= amount && amount > 0, "Vault: insufficient staked");
        require(block.timestamp >= user.unstakeAvailableAt, "Vault: 14-day cooldown active");

        _harvest(msg.sender);
        user.amount -= amount;
        totalStaked -= amount;
        user.rewardDebt = (user.amount * accUsdcPerShare) / 1e18;

        require(copsToken.transfer(msg.sender, amount), "Vault: withdraw transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    function _harvest(address account) internal {
        StakeInfo storage user = stakes[account];
        if (user.amount > 0) {
            uint256 pending = ((user.amount * accUsdcPerShare) / 1e18) - user.rewardDebt;
            if (pending > 0) {
                require(usdcToken.transfer(account, pending), "Vault: USDC payout failed");
                emit UsdcYieldClaimed(account, pending);
            }
        }
    }
}
