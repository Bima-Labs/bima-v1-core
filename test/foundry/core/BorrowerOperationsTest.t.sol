// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {IBorrowerOperations} from "../TestSetup.sol";

import {StabilityPoolTest} from "./StabilityPoolTest.t.sol";

import {BabelMath} from "../../../contracts/dependencies/BabelMath.sol";
import {ITroveManager, IERC20} from "../../../contracts/interfaces/ITroveManager.sol";

contract BorrowerOperationsTest is StabilityPoolTest {

    ITroveManager internal stakedBTCTroveMgr;
    uint256 internal minCollateral;
    uint256 internal maxCollateral;
    uint256 internal minDebt;

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

        minCollateral = 3e17;
        maxCollateral = 1_000_000e18;
        minDebt       = INIT_MIN_NET_DEBT;
    }

    function test_openTrove_failInvalidTroveManager() external {
        vm.expectRevert("Collateral not enabled");
        vm.prank(users.user1);
        borrowerOps.openTrove(troveMgr, users.user1, 1e18, 1e18, 0, address(0), address(0));
    }

    // used to store relevant state before tests for verification afterwards
    struct BorrowerOpsState {
        uint256 userSBTCBal;
        uint256 userDebtTokenBal;
        uint256 gasPoolDebtTokenBal;
        uint256 troveMgrSBTCBal;
        IBorrowerOperations.SystemBalances sysBalances;
    }
    function _getBorrowerOpsState() internal returns(BorrowerOpsState memory state) {
        state.userSBTCBal = stakedBTC.balanceOf(users.user1);
        state.userDebtTokenBal = debtToken.balanceOf(users.user1);
        state.gasPoolDebtTokenBal = debtToken.balanceOf(users.gasPool);
        state.troveMgrSBTCBal = stakedBTC.balanceOf(address(stakedBTCTroveMgr));
        state.sysBalances = borrowerOps.fetchBalances();

        assertEq(state.sysBalances.collaterals.length, 1);
        assertEq(state.sysBalances.collaterals.length, state.sysBalances.debts.length);
        assertEq(state.sysBalances.collaterals.length, state.sysBalances.prices.length);
    }

    // helper function to open a trove
    function _openTrove(address user, uint256 collateralAmount, uint256 debtAmount) internal {
        _sendStakedBtc(user, collateralAmount);

        vm.prank(user);
        stakedBTC.approve(address(borrowerOps), collateralAmount);

        vm.prank(user);
        borrowerOps.openTrove(stakedBTCTroveMgr,
                              user,
                              0, // maxFeePercentage
                              collateralAmount,
                              debtAmount,
                              address(0), address(0)); // hints

        // verify borrower received debt tokens
        assertEq(debtToken.balanceOf(user), debtAmount);

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

    function test_openTrove(uint256 collateralAmount, uint256 debtAmount, uint256 btcPrice) public
        returns(uint256 actualCollateralAmount, uint256 actualDebtAmount) {
        // bound fuzz inputs
        actualCollateralAmount = bound(collateralAmount, minCollateral, maxCollateral);
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
                             (actualCollateralAmount * _getScaledOraclePrice() / borrowerOps.CCR())
                              - INIT_GAS_COMPENSATION);

        // get random debt between min and max possible for random collateral amount
        actualDebtAmount = bound(debtAmount, minDebt, debtAmountMax);

        _openTrove(users.user1, actualCollateralAmount, actualDebtAmount);
    }

    function test_openTrove_custom() external {
        // depositing 2 BTC collateral (price = $60,000 in MockOracle)
        // use this test to experiment with different hard-coded values
        uint256 collateralAmount = 2e18;

        uint256 debtAmountMax
            = (collateralAmount * _getScaledOraclePrice() / borrowerOps.CCR())
              - INIT_GAS_COMPENSATION;

        _openTrove(users.user1, collateralAmount, debtAmountMax);
    }

    function test_addColl(uint256 collateralAmount, uint256 debtAmount, uint256 btcPrice) public
        returns (uint256 addedCollateral) {
        // first limit the max collateral to ensure enough tokens remain
        maxCollateral /= 2;

        // bound fuzz inputs
        addedCollateral = bound(collateralAmount, 1, maxCollateral);

        // then open a new trove
        test_openTrove(collateralAmount, debtAmount, btcPrice);

        // give user extra staked btc collateral
        _sendStakedBtc(users.user1, addedCollateral);

        // save pre state
        BorrowerOpsState memory statePre = _getBorrowerOpsState();

        // transfer approval
        vm.prank(users.user1);
        stakedBTC.approve(address(borrowerOps), addedCollateral);

        // add the new collateral to the existing trove
        vm.prank(users.user1);
        borrowerOps.addColl(stakedBTCTroveMgr,
                            users.user1,
                            addedCollateral,
                            address(0), address(0)); // hints

        // verify borrower debt tokens unchanged
        assertEq(debtToken.balanceOf(users.user1), statePre.userDebtTokenBal);

        // verify gas pool gas compensation tokens unchanged
        assertEq(debtToken.balanceOf(users.gasPool), statePre.gasPoolDebtTokenBal);

        // verify TroveManager received additional collateral tokens
        assertEq(stakedBTC.balanceOf(address(stakedBTCTroveMgr)), statePre.troveMgrSBTCBal + addedCollateral);

        // verify system balances
        IBorrowerOperations.SystemBalances memory sysBalancesPost = borrowerOps.fetchBalances();
        assertEq(sysBalancesPost.collaterals.length, 1);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.debts.length);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.prices.length);

        assertEq(sysBalancesPost.collaterals[0], statePre.sysBalances.collaterals[0] + addedCollateral);
        assertEq(sysBalancesPost.debts[0], statePre.sysBalances.debts[0]);
        assertEq(sysBalancesPost.prices[0], statePre.sysBalances.prices[0]);
    }

    function test_withdrawColl(uint256 collateralAmount, uint256 debtAmount, uint256 btcPrice) external
        returns(uint256 withdrawnCollateral) {
        // first open a trove and add some extra collateral
        uint256 addedCollateral = test_addColl(collateralAmount, debtAmount, btcPrice);

        // bound fuzz inputs
        withdrawnCollateral = bound(addedCollateral, 1, addedCollateral);

        // save pre state
        BorrowerOpsState memory statePre = _getBorrowerOpsState();

        // withdraw the extra collateral
        vm.prank(users.user1);
        borrowerOps.withdrawColl(stakedBTCTroveMgr,
                                 users.user1,
                                 withdrawnCollateral,
                                 address(0), address(0)); // hints

        // verify borrower debt tokens unchanged
        assertEq(debtToken.balanceOf(users.user1), statePre.userDebtTokenBal);

        // verify gas pool compensation tokens unchanged
        assertEq(debtToken.balanceOf(users.gasPool), statePre.gasPoolDebtTokenBal);

        // verify TroveManager sent withdrawn collateral tokens
        assertEq(stakedBTC.balanceOf(address(stakedBTCTroveMgr)), statePre.troveMgrSBTCBal - withdrawnCollateral);

        // verify user received withdrawn collateral tokens
        assertEq(stakedBTC.balanceOf(users.user1), statePre.userSBTCBal + withdrawnCollateral);

        // verify system balances
        IBorrowerOperations.SystemBalances memory sysBalancesPost = borrowerOps.fetchBalances();
        assertEq(sysBalancesPost.collaterals.length, 1);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.debts.length);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.prices.length);

        assertEq(sysBalancesPost.collaterals[0], statePre.sysBalances.collaterals[0] - withdrawnCollateral);
        assertEq(sysBalancesPost.debts[0], statePre.sysBalances.debts[0]);
        assertEq(sysBalancesPost.prices[0], statePre.sysBalances.prices[0]);
    }

    function test_withdrawDebt(uint256 collateralAmount, uint256 debtAmount, uint256 btcPrice) external
        returns(uint256 withdrawnDebt) {
        // first limit the max collateral to prevent max debt being taken
        // when opening a trove
        maxCollateral = 4e18;

        // then open a trove and add some extra collateral
        uint256 addedCollateral = test_addColl(collateralAmount, debtAmount, btcPrice);

        // get max debt possible for extra collateral amount
        uint256 debtAmountMax = addedCollateral * _getScaledOraclePrice() / borrowerOps.CCR();

        // get random debt between min and max possible for extra collateral amount
        withdrawnDebt = bound(debtAmount, 1, debtAmountMax);

        // save pre state
        BorrowerOpsState memory statePre = _getBorrowerOpsState();

        // withdraw the debt
        vm.prank(users.user1);
        borrowerOps.withdrawDebt(stakedBTCTroveMgr,
                                 users.user1,
                                 0, // maxFeePercentage
                                 withdrawnDebt,
                                 address(0), address(0)); // hints

        // verify borrower received withdrawn debt tokens
        assertEq(debtToken.balanceOf(users.user1), statePre.userDebtTokenBal + withdrawnDebt);

        // verify gas pool compensation tokens unchanged
        assertEq(debtToken.balanceOf(users.gasPool), statePre.gasPoolDebtTokenBal);

        // verify TroveManager collateral tokens unchanged
        assertEq(stakedBTC.balanceOf(address(stakedBTCTroveMgr)), statePre.troveMgrSBTCBal);

        // verify user collateral tokens unchanged
        assertEq(stakedBTC.balanceOf(users.user1), statePre.userSBTCBal);

        // verify system balances
        IBorrowerOperations.SystemBalances memory sysBalancesPost = borrowerOps.fetchBalances();
        assertEq(sysBalancesPost.collaterals.length, 1);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.debts.length);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.prices.length);

        assertEq(sysBalancesPost.collaterals[0], statePre.sysBalances.collaterals[0]);
        assertEq(sysBalancesPost.debts[0], statePre.sysBalances.debts[0] + withdrawnDebt);
        assertEq(sysBalancesPost.prices[0], statePre.sysBalances.prices[0]);
    }

    function test_closeTrove(uint256 collateralAmount, uint256 debtAmount, uint256 btcPrice) external {
        // first open a new trove
        (uint256 actualCollateralAmount, ) = test_openTrove(collateralAmount, debtAmount, btcPrice);

        // save pre state
        BorrowerOpsState memory statePre = _getBorrowerOpsState();

        // then close it
        vm.prank(users.user1);
        borrowerOps.closeTrove(stakedBTCTroveMgr, users.user1);

        // verify borrower has zero debt tokens
        assertEq(debtToken.balanceOf(users.user1), 0);

        // verify gas pool compensation has zero tokens
        assertEq(debtToken.balanceOf(users.gasPool), 0);

        // verify TroveManager has zero collateral tokens
        assertEq(stakedBTC.balanceOf(address(stakedBTCTroveMgr)), 0);

        // verify user received collateral tokens
        assertEq(stakedBTC.balanceOf(users.user1), statePre.userSBTCBal + actualCollateralAmount);

        // verify system balances
        IBorrowerOperations.SystemBalances memory sysBalancesPost = borrowerOps.fetchBalances();
        assertEq(sysBalancesPost.collaterals.length, 1);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.debts.length);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.prices.length);

        assertEq(sysBalancesPost.collaterals[0], 0);
        assertEq(sysBalancesPost.debts[0], 0);
        assertEq(sysBalancesPost.prices[0], statePre.sysBalances.prices[0]);
    }

    function test_repayDebt(uint256 collateralAmount, uint256 debtAmount, uint256 btcPrice) external
        returns(uint256 repayAmount) {
        // increase the minimum debt to ensure repay won't revert
        // due to going below the minimum debt value
        minDebt = INIT_MIN_NET_DEBT * 130 / 100;

        // open a new trove
        (, uint256 actualDebtAmount)
            = test_openTrove(collateralAmount, debtAmount, btcPrice);

        // bound repay amount to prevent revert due to going below
        // mininum debt value
        repayAmount = bound(actualDebtAmount, 1, actualDebtAmount - INIT_MIN_NET_DEBT);

        // save pre state
        BorrowerOpsState memory statePre = _getBorrowerOpsState();

        // repay some debt
        vm.prank(users.user1);
        borrowerOps.repayDebt(stakedBTCTroveMgr, users.user1, repayAmount, address(0), address(0));

        // verify borrower has reduced debt tokens
        assertEq(debtToken.balanceOf(users.user1), actualDebtAmount - repayAmount);

        // verify gas pool compensation debt tokens unchanged
        assertEq(debtToken.balanceOf(users.gasPool), statePre.gasPoolDebtTokenBal);

        // verify TroveManager has collateral tokens unchanged
        assertEq(stakedBTC.balanceOf(address(stakedBTCTroveMgr)), statePre.troveMgrSBTCBal);

        // verify user collateral tokens unchanged
        assertEq(stakedBTC.balanceOf(users.user1), statePre.userSBTCBal);

        // verify system balances
        IBorrowerOperations.SystemBalances memory sysBalancesPost = borrowerOps.fetchBalances();
        assertEq(sysBalancesPost.collaterals.length, 1);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.debts.length);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.prices.length);

        assertEq(sysBalancesPost.collaterals[0], statePre.sysBalances.collaterals[0]);
        assertEq(sysBalancesPost.debts[0], statePre.sysBalances.debts[0] - repayAmount);
        assertEq(sysBalancesPost.prices[0], statePre.sysBalances.prices[0]);
    }
}
