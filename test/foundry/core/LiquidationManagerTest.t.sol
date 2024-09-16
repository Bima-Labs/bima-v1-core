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
    struct StateData {
        uint256 userDebt;
        uint256 userColl;
        uint256 userPendingDebtReward;
        uint256 userPendingCollateralReward;
    }

    function test_liquidateTroves_onlyOneTrove() external {
        // depositing 2 BTC collateral (price = $60,000 in MockOracle)
        // use this test to experiment with different hard-coded values
        uint256 collateralAmount = 2e18;

        uint256 debtAmountMax
            = (collateralAmount * _getScaledOraclePrice() / borrowerOps.CCR())
              - INIT_GAS_COMPENSATION;

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
        StateData memory statePre;
        (statePre.userDebt, statePre.userColl, statePre.userPendingDebtReward, statePre.userPendingCollateralReward)
            = stakedBTCTroveMgr.getEntireDebtAndColl(users.user1);

        // liquidate via `liquidateTroves`
        liquidationMgr.liquidateTroves(stakedBTCTroveMgr, 1, stakedBTCTroveMgr.MCR());

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

    function test_liquidate_onlyOneTrove() external {
        // depositing 2 BTC collateral (price = $60,000 in MockOracle)
        // use this test to experiment with different hard-coded values
        uint256 collateralAmount = 2e18;

        uint256 debtAmountMax
            = (collateralAmount * _getScaledOraclePrice() / borrowerOps.CCR())
              - INIT_GAS_COMPENSATION;

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


}