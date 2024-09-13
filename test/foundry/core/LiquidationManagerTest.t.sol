// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {BorrowerOperationsTest} from "./BorrowerOperationsTest.t.sol";

contract LiquidationManagerTest is BorrowerOperationsTest {

    function setUp() public virtual override {
        super.setUp();

        // verify staked btc trove manager enabled for liquidation
        assertTrue(liquidationMgr.isTroveManagerEnabled(stakedBTCTroveMgr));
    }

    /* fuzz version - not working yet, get hard-coded version working first
    function test_liquidate(uint256 collateralAmount, uint256 debtAmount, uint256 btcPrice) external {
        // first open a new trove
        (uint256 actualCollateralAmount, uint256 actualDebtAmount)
            = test_openTrove(collateralAmount, debtAmount, btcPrice);

        // new trove should never be immediately subject to liquidation
        vm.expectRevert("LiquidationManager: nothing to liquidate");
        liquidationMgr.liquidate(stakedBTCTroveMgr, users.user1);

        // set new btc price / 2 with mock oracle
        mockOracle.setResponse(mockOracle.roundId() + 1,
                               int256(0),
                               block.timestamp + 1,
                               block.timestamp + 1,
                               mockOracle.answeredInRound() + 1);
        // warp time to prevent cached price being used
        vm.warp(block.timestamp + 1);

        // then liquidate the user
        liquidationMgr.liquidate(stakedBTCTroveMgr, users.user1);
    }*/


    function test_impossibleToLiquidateSingleBorrower() external {
        // depositing 2 BTC collateral (price = $60,000 in MockOracle)
        // use this test to experiment with different hard-coded values
        uint256 collateralAmount = 2e18;

        uint256 debtAmountMax
            = (collateralAmount * _getScaledOraclePrice() / borrowerOps.CCR())
              - INIT_GAS_COMPENSATION;

        _openTrove(users.user1, collateralAmount, debtAmountMax);

        // set new value of btc to $1 which should ensure liquidation
        mockOracle.setResponse(mockOracle.roundId() + 1,
                               int256(1 * 10 ** 8),
                               block.timestamp + 1,
                               block.timestamp + 1,
                               mockOracle.answeredInRound() + 1);
        // warp time to prevent cached price being used
        vm.warp(block.timestamp + 1);

        // then liquidate the user - but it fails since the
        // `while` and `for` loops get bypassed when there is
        // only 1 active borrower!
        vm.expectRevert("LiquidationManager: nothing to liquidate");
        liquidationMgr.liquidate(stakedBTCTroveMgr, users.user1);

        // attempting to use the other liquidation function has same problem
        uint256 mcr = stakedBTCTroveMgr.MCR();
        vm.expectRevert("LiquidationManager: nothing to liquidate");
        liquidationMgr.liquidateTroves(stakedBTCTroveMgr, 1, mcr);
        // the borrower is impossible to liquidate
    }
}