// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {BorrowerOperationsTest} from "./BorrowerOperationsTest.t.sol";
import {BIMA_DECIMAL_PRECISION} from "../../../contracts/dependencies/Constants.sol";

contract LiquidationManagerTest is BorrowerOperationsTest {

    function setUp() public virtual override {
        super.setUp();

        // verify staked btc trove manager enabled for liquidation
        assertTrue(liquidationMgr.isTroveManagerEnabled(stakedBTCTroveMgr));
    }

    // helper functions
    function _getCollGasCompensation(uint256 coll) internal view returns (uint256 result) {
        result = coll / liquidationMgr.PERCENT_DIVISOR();
    }

    // used to save important state for verification
    struct LiquidationState {
        uint256 troveOwnersCount; 

        uint256 totalDebt;
        uint256 totalColl;

        uint256 userDebt;
        uint256 userColl;
        uint256 userPendingDebtReward;
        uint256 userPendingCollateralReward;

        uint256 stabPoolTotalDebtTokenDeposits;
    }
    function _getLiquidationState(address user) internal view returns (LiquidationState memory state) {
        state.troveOwnersCount = stakedBTCTroveMgr.getTroveOwnersCount();

        state.totalDebt = stakedBTCTroveMgr.getTotalActiveDebt();
        state.totalColl = stakedBTCTroveMgr.getTotalActiveCollateral();

        (state.userDebt, state.userColl, state.userPendingDebtReward, state.userPendingCollateralReward)
            = stakedBTCTroveMgr.getEntireDebtAndColl(user);

        state.stabPoolTotalDebtTokenDeposits = stabilityPool.getTotalDebtTokenDeposits();
    }

    function test_liquidate_oneTroveWithoutStabilityPool(
        uint256 collateralAmount, bool functionSwitch) external {

        // bound fuzz inputs - reduce max debt to prevent over-collateralization
        // so that liquidation will occur
        collateralAmount = bound(collateralAmount, minCollateral, maxCollateral/30_000);

        // get max debt
        uint256 debtAmountMax = _getMaxDebtAmount(collateralAmount);
        
        _openTrove(users.user1, collateralAmount, debtAmountMax);
        
        // set new value of btc to $50,000 to make trove liquidatable
        mockOracle.setResponse(mockOracle.roundId() + 1,
                               int256(50000 * 10 ** 8),
                               block.timestamp + 1,
                               block.timestamp + 1,
                               mockOracle.answeredInRound() + 1);
        // warp time to prevent cached price being used
        vm.warp(block.timestamp + 1);

        // save previous state
        LiquidationState memory statePre = _getLiquidationState(users.user1);

        // function switch uses different liquidate functions
        if(functionSwitch) {
            liquidationMgr.liquidateTroves(stakedBTCTroveMgr, 1, stakedBTCTroveMgr.MCR());
        }
        else {
            liquidationMgr.liquidate(stakedBTCTroveMgr, users.user1);
        }

        // save after state
        LiquidationState memory statePost = _getLiquidationState(users.user1);

        // verify trove owners count decreased
        assertEq(statePost.troveOwnersCount, statePre.troveOwnersCount - 1);

        // user after state all zeros
        assertEq(statePost.userDebt, 0);
        assertEq(statePost.userColl, 0);
        assertEq(statePost.userPendingDebtReward, 0);
        assertEq(statePost.userPendingCollateralReward, 0);

        // verify total active debt & collateral reduced by liquidation
        assertEq(statePost.totalDebt, statePre.totalDebt - debtAmountMax - INIT_GAS_COMPENSATION);
        assertEq(statePost.totalColl, statePre.totalColl - collateralAmount);

        // verify defaulted debt & collateral calculated correctly
        assertEq(stakedBTCTroveMgr.defaultedDebt(),
                 statePre.userDebt + statePre.userPendingDebtReward);
        assertEq(stakedBTCTroveMgr.defaultedCollateral(),
                 statePre.userColl - _getCollGasCompensation(statePre.userColl));


        // verify defaulted collateral and debt correctly calculated
        assertEq(stakedBTCTroveMgr.defaultedCollateral(),
                 collateralAmount - _getCollGasCompensation(collateralAmount));
        assertEq(stakedBTCTroveMgr.defaultedDebt(),
                 debtAmountMax + INIT_GAS_COMPENSATION);

        assertEq(stakedBTCTroveMgr.L_collateral(), stakedBTCTroveMgr.defaultedCollateral());
        assertEq(stakedBTCTroveMgr.L_debt(), stakedBTCTroveMgr.defaultedDebt());

        // no errors
        assertEq(stakedBTCTroveMgr.lastCollateralError_Redistribution(), 0);
        assertEq(stakedBTCTroveMgr.lastDebtError_Redistribution(), 0);
    }

    /* todo
    function test_liquidate_withStabilityPoolDeposits() external {
        // user2 deposits into the stability pool
        uint96 spDepositAmount = 1e18;
        _provideToSP(users.user2, spDepositAmount, 1);

        // user1 opens a trove using 2 BTC collateral (price = $60,000 in MockOracle)
        uint256 collateralAmount = 2e18;

        uint256 debtAmountMax // 53332 333333333333333333
            = (collateralAmount * _getScaledOraclePrice() / borrowerOps.CCR())
              - INIT_GAS_COMPENSATION;

        _openTrove(users.user1, collateralAmount, debtAmountMax);

        // 2250000000000000000
        uint256 ICR = stakedBTCTroveMgr.getCurrentICR(users.user1, stakedBTCTroveMgr.fetchPrice());

        // set new value of btc to $50,000 to make trove liquidatable
        mockOracle.setResponse(mockOracle.roundId() + 1,
                               int256(50000 * 10 ** 8),
                               block.timestamp + 1,
                               block.timestamp + 1,
                               mockOracle.answeredInRound() + 1);
        // warp time to prevent cached price being used
        vm.warp(block.timestamp + 1);

        // PREV ICR : 2250000000000000000
        // NOW  ICR : 1875000000000000000
        //
        // TM MCR   : 2000000000000000000
        ICR = stakedBTCTroveMgr.getCurrentICR(users.user1, stakedBTCTroveMgr.fetchPrice());

        // save previous state
        StateData memory statePre;
        (statePre.userDebt, statePre.userColl, statePre.userPendingDebtReward, statePre.userPendingCollateralReward)
            = stakedBTCTroveMgr.getEntireDebtAndColl(users.user1);

        // liquidate via `liquidate`
        liquidationMgr.liquidate(stakedBTCTroveMgr, users.user1);

        // user after state all zeros
        StateData memory statePost;
        (statePost.userDebt, statePost.userColl, statePost.userPendingDebtReward, statePost.userPendingCollateralReward)
            = stakedBTCTroveMgr.getEntireDebtAndColl(users.user1);
        assertEq(statePost.userDebt, 0);
        assertEq(statePost.userColl, 0);
        assertEq(statePost.userPendingDebtReward, 0);
        assertEq(statePost.userPendingCollateralReward, 0);

        // since there was only 1 trove, these should also be zero
        assertEq(stakedBTCTroveMgr.getTotalActiveDebt(), 0);
        assertEq(stakedBTCTroveMgr.getTotalActiveCollateral(), 0);

        
        // verify defaulted debt & collateral calculated correctly
        assertEq(stakedBTCTroveMgr.defaultedDebt(),
                 statePre.userDebt + statePre.userPendingDebtReward);
        
        assertEq(stakedBTCTroveMgr.defaultedCollateral(),
                 statePre.userColl - _getCollGasCompensation(statePre.userColl));

        // just defaulted values * BIMA_DECIMAL_PRECISION as no previous errors
        // and only 1 trove total (the one being liquidated)
        assertEq(stakedBTCTroveMgr.L_collateral(),
                 stakedBTCTroveMgr.defaultedCollateral() * BIMA_DECIMAL_PRECISION);
        assertEq(stakedBTCTroveMgr.L_debt(),
                 stakedBTCTroveMgr.defaultedDebt() * BIMA_DECIMAL_PRECISION);

        // no errors
        assertEq(stakedBTCTroveMgr.lastCollateralError_Redistribution(), 0);
        assertEq(stakedBTCTroveMgr.lastDebtError_Redistribution(), 0);
    }
    */
}