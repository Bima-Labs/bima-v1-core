// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IBorrowerOperations} from "../TestSetup.sol";

import {BabelMath} from "../../../contracts/dependencies/BabelMath.sol";
import {ITroveManager, IERC20} from "../../../contracts/interfaces/ITroveManager.sol";

contract BorrowerOperationsTest is TestSetup {

    ITroveManager stakedBTCTroveMgr;

    function setUp() public virtual override {
        super.setUp();

        // verify factory has deployed 1 TroveManager which has
        // StakedBTC as its collateral token
        assertEq(factory.troveManagerCount(), 1);
        stakedBTCTroveMgr = ITroveManager(factory.troveManagers(0));
        assertEq(address(stakedBTCTroveMgr.collateralToken()), address(stakedBTC));

        // verify StakedBTCTroveMgr has been registered with BorrowerOperations
        assertEq(borrowerOps.getTroveManagersCount(), 1);

        (IERC20 collateralToken, uint16 index) = borrowerOps.troveManagersData(stakedBTCTroveMgr);
        assertEq(address(collateralToken), address(stakedBTC));
        assertEq(index, 0);
    }

    function test_openTrove_failInvalidTroveManager() external {
        vm.expectRevert("Collateral not enabled");
        vm.prank(users.user1);
        borrowerOps.openTrove(troveMgr, users.user1, 1e18, 1e18, 0, address(0), address(0));
    }

    function test_openTrove(uint256 collateralAmount, uint256 debtAmount, uint256 btcPrice) external {
        // bound fuzz inputs
        collateralAmount = bound(collateralAmount, 3e17, 1_000_000e18);
        btcPrice = bound(btcPrice, MIN_BTC_PRICE_8DEC, MAX_BTC_PRICE_8DEC);

        // set new btc price with mock oracle
        mockOracle.setResponse(mockOracle.roundId() + 1,
                               int256(btcPrice),
                               block.timestamp + 1,
                               block.timestamp + 1,
                               mockOracle.answeredInRound() + 1);
        // warp time to prevent cached price being used
        vm.warp(block.timestamp + 1);

        // get max debt possible for random collateral amount and random btc price
        uint256 debtAmountMax
            = BabelMath._min(INIT_MAX_DEBT - INIT_GAS_COMPENSATION,
                             (collateralAmount * _getScaledOraclePrice() / borrowerOps.CCR())
                              - INIT_GAS_COMPENSATION);

        // get random debt between min and max possible for random collateral amount
        debtAmount = bound(debtAmount, INIT_MIN_NET_DEBT, debtAmountMax);                                

        _sendStakedBtc(users.user1, collateralAmount);

        vm.prank(users.user1);
        stakedBTC.approve(address(borrowerOps), collateralAmount);

        vm.prank(users.user1);
        borrowerOps.openTrove(stakedBTCTroveMgr,
                              users.user1,
                              0, // maxFeePercentage
                              collateralAmount,
                              debtAmount,
                              address(0), address(0)); // hints

        // verify borrower received debt tokens
        assertEq(debtToken.balanceOf(users.user1), debtAmount);

        // verify gas pool received gas compensation tokens
        assertEq(debtToken.balanceOf(users.gasPool), INIT_GAS_COMPENSATION);

        // verify TroveManager received collateral tokens
        assertEq(stakedBTC.balanceOf(address(stakedBTCTroveMgr)), collateralAmount);

        // verify system balances
        IBorrowerOperations.SystemBalances memory balances = borrowerOps.fetchBalances();
        assertEq(balances.collaterals.length, 1);
        assertEq(balances.collaterals.length, balances.debts.length);
        assertEq(balances.collaterals.length, balances.prices.length);

        assertEq(balances.collaterals[0], collateralAmount);
        assertEq(balances.debts[0], debtAmount + INIT_GAS_COMPENSATION);
        assertEq(balances.prices[0], _getScaledOraclePrice());
    }

    function test_openTrove_custom() external {
        // depositing 2 BTC collateral (price = $60,000 in MockOracle)
        uint256 collateralAmount = 2e18;

        uint256 debtAmountMax
            = (collateralAmount * _getScaledOraclePrice() / borrowerOps.CCR())
              - INIT_GAS_COMPENSATION;

        _sendStakedBtc(users.user1, collateralAmount);

        vm.prank(users.user1);
        stakedBTC.approve(address(borrowerOps), collateralAmount);

        vm.prank(users.user1);
        borrowerOps.openTrove(stakedBTCTroveMgr,
                              users.user1,
                              0, // maxFeePercentage
                              collateralAmount,
                              debtAmountMax,
                              address(0), address(0)); // hints

        // verify borrower received debt tokens
        assertEq(debtToken.balanceOf(users.user1), debtAmountMax);

        // verify gas pool received gas compensation tokens
        assertEq(debtToken.balanceOf(users.gasPool), INIT_GAS_COMPENSATION);

        // verify TroveManager received collateral tokens
        assertEq(stakedBTC.balanceOf(address(stakedBTCTroveMgr)), collateralAmount);

        // verify system balances
        IBorrowerOperations.SystemBalances memory balances = borrowerOps.fetchBalances();
        assertEq(balances.collaterals.length, 1);
        assertEq(balances.collaterals.length, balances.debts.length);
        assertEq(balances.collaterals.length, balances.prices.length);

        assertEq(balances.collaterals[0], collateralAmount);
        assertEq(balances.debts[0], debtAmountMax + INIT_GAS_COMPENSATION);
        assertEq(balances.prices[0], _getScaledOraclePrice());
    }




}