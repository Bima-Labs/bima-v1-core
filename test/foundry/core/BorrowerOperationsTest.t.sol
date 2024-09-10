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

    function test_openTrove_fuzz(uint256 collateralAmount) external {
        // bound fuzz inputs
        collateralAmount = bound(collateralAmount, 4e16, 1_000_000e18);

        // get max debt possible
        uint256 debtAmount = BabelMath._min(INIT_MAX_DEBT - INIT_GAS_COMPENSATION,
                                            collateralAmount * 26566);

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
        assertEq(balances.prices[0], uint256(mockOracle.answer() * 10 ** 10));
    }

    function test_openTrove_custom() external {
        // depositing 2 BTC collateral (price = $60,000 in MockOracle)
        uint256 collateralAmount = 2e18;

        // get max debt possible
        uint256 debtAmount = 53_133e18;

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
        assertEq(balances.prices[0], uint256(mockOracle.answer() * 10 ** 10));
    }




}