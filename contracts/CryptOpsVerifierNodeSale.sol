// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CryptOpsVerifierNodeSale
 * @notice On-Chain Verifier Node License & Genesis Allocation Registry.
 * @dev Manages institutional Verifier Node license issuance in USDC:
 *      - Issues tiered CryptOps Pre-Broadcast Verifier Node Licenses in USDC.
 *      - Routes 100% of USDC settlement directly in the same transaction to the Treasury Multisig.
 *      - Records on-chain Verifier Node License ownership and associated $COPS staking allocation.
 */

interface IERC20USDC {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract CryptOpsVerifierNodeSale {
    IERC20USDC public immutable usdc;
    address public treasuryMultisig;
    address public immutable owner;

    struct Tier {
        string name;
        uint256 priceUsdc;        // 6 decimals (e.g. 2,500 * 1e6)
        uint256 copsAllocation;   // 18 decimals
        uint256 maxSupply;
        uint256 minted;
    }

    Tier[3] public tiers;
    uint256 public totalUsdcRaised;
    uint256 public totalNodesMinted;

    mapping(address => uint256) public nodesOwned;
    mapping(address => uint256) public copsAllocationOwed;

    event NodeLicensePurchased(
        address indexed buyer,
        uint8 indexed tierId,
        uint256 quantity,
        uint256 usdcPaid,
        uint256 copsAllocated
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "NodeSale: not owner");
        _;
    }

    constructor(address _usdc, address _treasuryMultisig) {
        require(_usdc != address(0) && _treasuryMultisig != address(0), "NodeSale: zero address");
        usdc = IERC20USDC(_usdc);
        treasuryMultisig = _treasuryMultisig;
        owner = msg.sender;

        // Tier 0: Sentinel Light Verifier Node ($1,000 USDC -> 20,000 $COPS @ $0.05 implied)
        tiers[0] = Tier("Sentinel Light Verifier", 1_000 * 1e6, 20_000 * 1e18, 2500, 0);
        // Tier 1: Pro Enclave Verifier Node ($2,500 USDC -> 55,000 $COPS)
        tiers[1] = Tier("Pro Enclave Verifier", 2_500 * 1e6, 55_000 * 1e18, 1500, 0);
        // Tier 2: Institutional Guardian Node ($10,000 USDC -> 250,000 $COPS)
        tiers[2] = Tier("Institutional Guardian Node", 10_000 * 1e6, 250_000 * 1e18, 375, 0);
        // Full sell-out across 3 tiers = $2.5M + $3.75M + $3.75M = $10,000,000 USDC
    }

    function purchaseNodeLicense(uint8 tierId, uint256 quantity) external {
        require(tierId < 3 && quantity > 0, "NodeSale: invalid tier or qty");
        Tier storage t = tiers[tierId];
        require(t.minted + quantity <= t.maxSupply, "NodeSale: tier sold out");

        uint256 totalCostUsdc = t.priceUsdc * quantity;
        uint256 totalCops = t.copsAllocation * quantity;

        // Route 100% of USDC directly to Treasury Multisig in the same block (zero trapped contract balance)
        require(usdc.transferFrom(msg.sender, treasuryMultisig, totalCostUsdc), "NodeSale: USDC payment failed");

        t.minted += quantity;
        totalNodesMinted += quantity;
        totalUsdcRaised += totalCostUsdc;
        nodesOwned[msg.sender] += quantity;
        copsAllocationOwed[msg.sender] += totalCops;

        emit NodeLicensePurchased(msg.sender, tierId, quantity, totalCostUsdc, totalCops);
    }

    function setTreasuryMultisig(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "NodeSale: zero address");
        treasuryMultisig = _newTreasury;
    }
}
