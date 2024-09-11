// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IBorrowerOperations} from "../TestSetup.sol";

import {BabelMath} from "../../../contracts/dependencies/BabelMath.sol";
import {ITroveManager, IERC20} from "../../../contracts/interfaces/ITroveManager.sol";

contract BorrowerOperationsTest is TestSetup {

    ITroveManager stakedBTCTroveMgr;
    uint256 internal minCollateral;
    uint256 internal maxCollateral;

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
    }

    function test_openTrove_failInvalidTroveManager() external {
        vm.expectRevert("Collateral not enabled");
        vm.prank(users.user1);
        borrowerOps.openTrove(troveMgr, users.user1, 1e18, 1e18, 0, address(0), address(0));
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

    function test_openTrove(uint256 collateralAmount, uint256 debtAmount, uint256 btcPrice) public {
        // bound fuzz inputs
        collateralAmount = bound(collateralAmount, minCollateral, maxCollateral);
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

        _openTrove(users.user1, collateralAmount, debtAmount);
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
        uint256 userDebtTokenBalPre = debtToken.balanceOf(users.user1);
        uint256 gasPoolDebtTokenBalPre = debtToken.balanceOf(users.gasPool);
        uint256 troveMgrSBTCBalPre = stakedBTC.balanceOf(address(stakedBTCTroveMgr));

        IBorrowerOperations.SystemBalances memory sysBalancesPre = borrowerOps.fetchBalances();
        assertEq(sysBalancesPre.collaterals.length, 1);
        assertEq(sysBalancesPre.collaterals.length, sysBalancesPre.debts.length);
        assertEq(sysBalancesPre.collaterals.length, sysBalancesPre.prices.length);

        // transfer approval
        vm.prank(users.user1);
        stakedBTC.approve(address(borrowerOps), addedCollateral);

        // add the new collateral to the existing trove
        vm.prank(users.user1);
        borrowerOps.addColl(stakedBTCTroveMgr,
                            users.user1,
                            addedCollateral,
                            address(0), address(0)); // hints

        // verify borrower received no new debt tokens
        assertEq(debtToken.balanceOf(users.user1), userDebtTokenBalPre);

        // verify gas pool received no new gas compensation tokens
        assertEq(debtToken.balanceOf(users.gasPool), gasPoolDebtTokenBalPre);

        // verify TroveManager received additional collateral tokens
        assertEq(stakedBTC.balanceOf(address(stakedBTCTroveMgr)), troveMgrSBTCBalPre + addedCollateral);

        // verify system balances
        IBorrowerOperations.SystemBalances memory sysBalancesPost = borrowerOps.fetchBalances();
        assertEq(sysBalancesPost.collaterals.length, 1);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.debts.length);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.prices.length);

        assertEq(sysBalancesPost.collaterals[0], sysBalancesPre.collaterals[0] + addedCollateral);
        assertEq(sysBalancesPost.debts[0], sysBalancesPre.debts[0]);
        assertEq(sysBalancesPost.prices[0], sysBalancesPre.prices[0]);
    }

    function test_withdrawColl(uint256 collateralAmount, uint256 debtAmount, uint256 btcPrice) external
        returns(uint256 withdrawnCollateral) {
        // first open a trove and add some extra collateral
        uint256 addedCollateral = test_addColl(collateralAmount, debtAmount, btcPrice);

        // bound fuzz inputs
        withdrawnCollateral = bound(addedCollateral, 1, addedCollateral);

        // save pre state
        uint256 userSBTCBalPre = stakedBTC.balanceOf(users.user1);
        uint256 userDebtTokenBalPre = debtToken.balanceOf(users.user1);
        uint256 gasPoolDebtTokenBalPre = debtToken.balanceOf(users.gasPool);
        uint256 troveMgrSBTCBalPre = stakedBTC.balanceOf(address(stakedBTCTroveMgr));
        
        IBorrowerOperations.SystemBalances memory sysBalancesPre = borrowerOps.fetchBalances();
        assertEq(sysBalancesPre.collaterals.length, 1);
        assertEq(sysBalancesPre.collaterals.length, sysBalancesPre.debts.length);
        assertEq(sysBalancesPre.collaterals.length, sysBalancesPre.prices.length);

        // withdraw the extra collateral
        vm.prank(users.user1);
        borrowerOps.withdrawColl(stakedBTCTroveMgr,
                                 users.user1,
                                 withdrawnCollateral,
                                 address(0), address(0)); // hints

        // verify borrower received no new debt tokens
        assertEq(debtToken.balanceOf(users.user1), userDebtTokenBalPre);

        // verify gas pool received no new gas compensation tokens
        assertEq(debtToken.balanceOf(users.gasPool), gasPoolDebtTokenBalPre);

        // verify TroveManager sent withdrawn collateral tokens
        assertEq(stakedBTC.balanceOf(address(stakedBTCTroveMgr)), troveMgrSBTCBalPre - withdrawnCollateral);

        // verify user received withdrawn collateral tokens
        assertEq(stakedBTC.balanceOf(users.user1), userSBTCBalPre + withdrawnCollateral);

        // verify system balances
        IBorrowerOperations.SystemBalances memory sysBalancesPost = borrowerOps.fetchBalances();
        assertEq(sysBalancesPost.collaterals.length, 1);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.debts.length);
        assertEq(sysBalancesPost.collaterals.length, sysBalancesPost.prices.length);

        assertEq(sysBalancesPost.collaterals[0], sysBalancesPre.collaterals[0] - withdrawnCollateral);
        assertEq(sysBalancesPost.debts[0], sysBalancesPre.debts[0]);
        assertEq(sysBalancesPost.prices[0], sysBalancesPre.prices[0]);
    }




}