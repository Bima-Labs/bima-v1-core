// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IIncentiveVoting, SafeCast} from "../TestSetup.sol";

import {BIMA_100_PCT} from "../../../contracts/dependencies/Constants.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StabilityPoolTest is TestSetup {
    function setUp() public virtual override {
        super.setUp();

        // only 1 collateral token exists due to base setup
        assertEq(stabilityPool.getNumCollateralTokens(), 1);
    }

    function test_enableCollateral() public returns (IERC20 newCollateral) {
        // add 1 new collateral
        newCollateral = IERC20(address(0x1234));

        vm.prank(address(factory));
        stabilityPool.enableCollateral(newCollateral);

        // verify storage
        assertEq(stabilityPool.getNumCollateralTokens(), 2);
        assertEq(stabilityPool.indexByCollateral(newCollateral), 2);
        assertEq(address(stabilityPool.collateralTokens(1)), address(newCollateral));
    }

    function test_enableCollateral_failToAddMoreThanMaxCollaterals() external {
        for (uint160 i = 1; i <= 255; i++) {
            address newCollateral = address(i);

            vm.prank(address(factory));
            stabilityPool.enableCollateral(IERC20(newCollateral));
        }

        // try to add one more
        vm.expectRevert("Maximum collateral length reached");
        vm.prank(address(factory));
        stabilityPool.enableCollateral(IERC20(address(uint160(256))));
    }

    function test_startCollateralSunset() public returns (IERC20 sunsetCollateral) {
        // first add new collateral
        sunsetCollateral = test_enableCollateral();

        // get sunset queue before sunset
        (, uint16 nextSunsetIndexKeyPre) = stabilityPool.getSunsetQueueKeys();

        // then sunset it
        vm.prank(users.owner);
        stabilityPool.startCollateralSunset(sunsetCollateral);

        // verify storage
        assertEq(stabilityPool.getNumCollateralTokens(), 2);
        assertEq(stabilityPool.indexByCollateral(sunsetCollateral), 0);
        assertEq(address(stabilityPool.collateralTokens(1)), address(sunsetCollateral));

        (uint128 idx, uint128 expiry) = stabilityPool.getSunsetIndexes(nextSunsetIndexKeyPre);
        assertEq(idx, 1);
        assertEq(expiry, block.timestamp + stabilityPool.SUNSET_DURATION());

        (, uint16 nextSunsetIndexKeyPost) = stabilityPool.getSunsetQueueKeys();
        assertEq(nextSunsetIndexKeyPost, nextSunsetIndexKeyPre + 1);
    }

    function test_enableCollateral_overwriteSunsetCollateral() external {
        // first add new collateral then sunset it
        IERC20 sunsetCollateral = test_startCollateralSunset();

        // then add another new collateral
        IERC20 newCollateral1 = IERC20(address(0x12345));
        vm.prank(address(factory));
        stabilityPool.enableCollateral(newCollateral1);

        // verify storage
        assertEq(stabilityPool.getNumCollateralTokens(), 3);
        assertEq(stabilityPool.indexByCollateral(newCollateral1), 3);
        assertEq(address(stabilityPool.collateralTokens(1)), address(sunsetCollateral));
        assertEq(address(stabilityPool.collateralTokens(2)), address(newCollateral1));

        // warp time past the sunset expiry
        vm.warp(block.timestamp + stabilityPool.SUNSET_DURATION() + 1);

        // get sunset queue before overwrite
        (uint16 firstSunsetIndexKeyPre, ) = stabilityPool.getSunsetQueueKeys();

        // add 1 more new collateral; this should over-write the sunsetted one
        IERC20 newCollateral2 = IERC20(address(0x123456));

        vm.prank(address(factory));
        stabilityPool.enableCollateral(newCollateral2);

        // verify that this over-wrote the sunsetted collateral
        assertEq(stabilityPool.getNumCollateralTokens(), 3);
        assertEq(stabilityPool.indexByCollateral(newCollateral2), 2);
        assertEq(stabilityPool.indexByCollateral(sunsetCollateral), 0);
        assertEq(address(stabilityPool.collateralTokens(1)), address(newCollateral2));
        assertEq(address(stabilityPool.collateralTokens(2)), address(newCollateral1));

        (uint128 idx, uint128 expiry) = stabilityPool.getSunsetIndexes(firstSunsetIndexKeyPre);
        assertEq(idx, 0);
        assertEq(expiry, 0);

        (uint16 firstSunsetIndexKeyPost, ) = stabilityPool.getSunsetQueueKeys();
        assertEq(firstSunsetIndexKeyPost, firstSunsetIndexKeyPre + 1);
    }

    // used to get around "stack too deep errors"
    struct DepositWithdrawState {
        uint128 accountTotalDep;
        uint128 accountLastDepositTime;
        uint256 totalDebtTokenDeposits;
        uint128 scale;
        uint128 epoch;
        uint256 userDebtTokenBalance;
        uint256 poolDebtTokenBalance;
    }

    function _getDepositWithdrawState(address user) internal view returns (DepositWithdrawState memory state) {
        (state.accountTotalDep, state.accountLastDepositTime) = stabilityPool.accountDeposits(user);
        state.totalDebtTokenDeposits = stabilityPool.getTotalDebtTokenDeposits();
        state.scale = stabilityPool.currentScale();
        state.epoch = stabilityPool.currentEpoch();
        state.userDebtTokenBalance = debtToken.balanceOf(user);
        state.poolDebtTokenBalance = debtToken.balanceOf(address(stabilityPool));
    }

    // helper function to execute one or more successful deposits into the stability pool
    function _provideToSP(address user, uint96 depositAmount, uint256 numDeposits) internal {
        // cache state before call
        DepositWithdrawState memory statePre = _getDepositWithdrawState(user);

        for (uint256 i = 1; i <= numDeposits; i++) {
            // mint user1 some tokens
            vm.prank(address(borrowerOps));
            debtToken.mint(user, depositAmount);
            assertEq(debtToken.balanceOf(user), depositAmount);

            // user1 deposits them into stability pool
            vm.prank(user);
            stabilityPool.provideToSP(depositAmount);

            // verify depositor lost tokens so balance remains the same as
            // tokens were just minted to the user
            assertEq(debtToken.balanceOf(user), statePre.userDebtTokenBalance);

            // verify stability pool received tokens
            assertEq(debtToken.balanceOf(address(stabilityPool)), statePre.poolDebtTokenBalance + depositAmount * i);

            // verify storage updates
            assertEq(stabilityPool.getTotalDebtTokenDeposits(), statePre.totalDebtTokenDeposits + depositAmount * i);

            (uint128 accountTotalDepPost, uint128 accountLastDepositTimePost) = stabilityPool.accountDeposits(user);
            assertEq(accountTotalDepPost, statePre.accountTotalDep + depositAmount * i);
            assertEq(accountLastDepositTimePost, block.timestamp);

            assertEq(stabilityPool.getStoredPendingReward(user), 0);

            assertEq(stabilityPool.currentScale(), statePre.scale);
            assertEq(stabilityPool.currentEpoch(), statePre.epoch);

            (uint256 depositorP, uint256 depositorG, uint128 depositorScale, uint128 depositorEpoch) = stabilityPool
                .depositSnapshots(user);

            assertEq(depositorP, stabilityPool.P());
            assertEq(depositorG, stabilityPool.epochToScaleToG(statePre.epoch, statePre.scale));
            assertEq(depositorScale, statePre.scale);
            assertEq(depositorEpoch, statePre.epoch);
        }
    }

    function test_provideToSP(uint96 depositAmount, uint256 numDeposits) external {
        // bound fuzz inputs
        depositAmount = uint96(bound(depositAmount, 1, type(uint96).max));
        numDeposits = bound(numDeposits, 1, 10);

        _provideToSP(users.user1, depositAmount, numDeposits);
    }

    // helper function to execute a successful withdrawal from the stability pool
    function _withdrawFromToSP(address user, uint96 withdrawAmount) internal {
        // cache state before call
        DepositWithdrawState memory statePre = _getDepositWithdrawState(user);

        // then perform the withdrawal
        vm.prank(user);
        stabilityPool.withdrawFromSP(withdrawAmount);

        // verify depositor received withdrawn tokens
        assertEq(debtToken.balanceOf(user), statePre.userDebtTokenBalance + withdrawAmount);

        // verify stability pool sent tokens
        assertEq(debtToken.balanceOf(address(stabilityPool)), statePre.poolDebtTokenBalance - withdrawAmount);

        // verify storage updates
        assertEq(stabilityPool.getTotalDebtTokenDeposits(), statePre.totalDebtTokenDeposits - withdrawAmount);

        (uint128 accountTotalDepPost, uint128 accountLastDepositTimePost) = stabilityPool.accountDeposits(user);
        assertEq(accountTotalDepPost, statePre.accountTotalDep - withdrawAmount);
        assertEq(accountLastDepositTimePost, statePre.accountLastDepositTime);

        assertEq(stabilityPool.getStoredPendingReward(user), 0);

        assertEq(stabilityPool.currentScale(), statePre.scale);
        assertEq(stabilityPool.currentEpoch(), statePre.epoch);

        (uint256 depositorP, uint256 depositorG, uint128 depositorScale, uint128 depositorEpoch) = stabilityPool
            .depositSnapshots(user);

        if (accountTotalDepPost == 0) {
            assertEq(depositorP, 0);
            assertEq(depositorG, 0);
            assertEq(depositorScale, 0);
            assertEq(depositorEpoch, 0);
        } else {
            assertEq(depositorP, stabilityPool.P());
            assertEq(depositorG, stabilityPool.epochToScaleToG(statePre.epoch, statePre.scale));
            assertEq(depositorScale, statePre.scale);
            assertEq(depositorEpoch, statePre.epoch);
        }
    }

    function test_withdrawFromSP(uint96 depositAmount, uint96 withdrawAmount) external {
        // bound fuzz inputs
        depositAmount = uint96(bound(depositAmount, 1, type(uint96).max));
        withdrawAmount = uint96(bound(withdrawAmount, 1, depositAmount));

        // first perform a deposit
        _provideToSP(users.user1, depositAmount, 1);

        // warp forward since deposits & withdraws not allowed in same block
        vm.warp(block.timestamp + 1);

        _withdrawFromToSP(users.user1, withdrawAmount);
    }

    function test_claimReward_smallAmountOfStabilityPoolRewardsLost() external {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY / 2, true);

        // user votes for stability pool to get emissions
        IIncentiveVoting.Vote[] memory votes = new IIncentiveVoting.Vote[](1);
        votes[0].id = stabilityPool.SP_EMISSION_ID();
        votes[0].points = incentiveVoting.MAX_POINTS();

        vm.prank(users.user1);
        incentiveVoting.registerAccountWeightAndVote(users.user1, 52, votes);

        // user1 and user 2 both deposit 10K into the stability pool
        uint96 spDepositAmount = 10_000e18;
        _provideToSP(users.user1, spDepositAmount, 1);
        _provideToSP(users.user2, spDepositAmount, 1);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // calculate expected first week emissions
        uint256 firstWeekEmissions = (initialUnallocated * INIT_ES_WEEKLY_PCT) / BIMA_100_PCT;
        assertEq(firstWeekEmissions, 536870911875000000000000000);
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated);

        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());

        // no rewards in the same week as emissions
        assertEq(stabilityPool.claimableReward(users.user1), 0);
        assertEq(stabilityPool.claimableReward(users.user2), 0);

        vm.prank(users.user1);
        uint256 userReward = stabilityPool.claimReward(users.user1);
        assertEq(userReward, 0);
        vm.prank(users.user2);
        userReward = stabilityPool.claimReward(users.user2);
        assertEq(userReward, 0);

        // verify emissions correctly set in BimaVault for first week
        assertEq(bimaVault.weeklyEmissions(systemWeek), firstWeekEmissions);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // rewards for the first week can be claimed now
        // users receive slightly less due to precision loss
        assertEq(firstWeekEmissions / 2, 268435455937500000000000000);
        uint256 actualUserReward = 268435455937499999999890000;

        assertEq(stabilityPool.claimableReward(users.user1), actualUserReward);
        assertEq(stabilityPool.claimableReward(users.user2), actualUserReward);

        // verify user1 rewards
        vm.prank(users.user1);
        userReward = stabilityPool.claimReward(users.user1);
        assertEq(userReward, actualUserReward);

        // verify user2 rewards
        vm.prank(users.user2);
        userReward = stabilityPool.claimReward(users.user2);
        assertEq(userReward, actualUserReward);

        // firstWeekEmissions = 536870911875000000000000000
        // userReward * 2     = 536870911874999999999780000
        //
        // a small amount of rewards was not distributed and is effectively lost

        // if either users tries to claim again, nothing is returned
        vm.prank(users.user1);
        userReward = stabilityPool.claimReward(users.user1);
        assertEq(userReward, 0);
        vm.prank(users.user2);
        userReward = stabilityPool.claimReward(users.user2);
        assertEq(userReward, 0);

        // user2 withdraws from the stability pool
        _withdrawFromToSP(users.user2, spDepositAmount);

        uint256 secondWeekEmissions = ((initialUnallocated - firstWeekEmissions) * INIT_ES_WEEKLY_PCT) / BIMA_100_PCT;
        assertEq(secondWeekEmissions, 402653183906250000000000000);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // user2 can't claim anything as they withdrew
        assertEq(stabilityPool.claimableReward(users.user2), 0);
        vm.prank(users.user2);
        userReward = stabilityPool.claimReward(users.user2);
        assertEq(userReward, 0);

        // user1 gets almost all the weekly emissions apart
        // from a small amount that is lost
        actualUserReward = 402653183906249999999540000;
        assertEq(stabilityPool.claimableReward(users.user1), actualUserReward);

        vm.prank(users.user1);
        userReward = stabilityPool.claimReward(users.user1);
        assertEq(userReward, actualUserReward);

        // weekly emissions 402653183906250000000000000
        // user1 received   402653183906249999999540000

        // user1 can't claim more rewards
        assertEq(stabilityPool.claimableReward(users.user1), 0);
        vm.prank(users.user1);
        userReward = stabilityPool.claimReward(users.user1);
        assertEq(userReward, 0);
    }
}
