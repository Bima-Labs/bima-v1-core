// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IBabelVault, ITokenLocker} from "../TestSetup.sol";

import {console} from "forge-std/console.sol";

contract TokenLockerTest is TestSetup {

    function setUp() public virtual override {
        super.setUp();

        // setup the vault to get BabelTokens which are used for voting
        uint128[] memory _fixedInitialAmounts;
        IBabelVault.InitialAllowance[] memory initialAllowances 
            = new IBabelVault.InitialAllowance[](1);
        
        // give user1 allowance over the entire supply of voting tokens
        initialAllowances[0].receiver = users.user1;
        initialAllowances[0].amount = INIT_BAB_TKN_TOTAL_SUPPLY;

        vm.prank(users.owner);
        babelVault.setInitialParameters(emissionSchedule,
                                        boostCalc,
                                        INIT_BAB_TKN_TOTAL_SUPPLY,
                                        INIT_VLT_LOCK_WEEKS,
                                        _fixedInitialAmounts,
                                        initialAllowances);

        // transfer voting tokens to recipients
        vm.prank(users.user1);
        babelToken.transferFrom(address(babelVault), users.user1, INIT_BAB_TKN_TOTAL_SUPPLY);

        // verify recipients have received voting tokens
        assertEq(babelToken.balanceOf(users.user1), INIT_BAB_TKN_TOTAL_SUPPLY);
    }

    // helper function
    function _lock(uint256 amountToLock, uint256 weeksToLockFor) internal
        returns(uint256 lockedAmount, uint256 weeksLockedFor) 
    {
        // save user initial balance
        uint256 userPreLockTokedBalance = babelToken.balanceOf(users.user1);

        (uint256 userPreLockLockedBalance, ) = tokenLocker.getAccountBalances(users.user1);

        // lock up specified amount for specified weeks
        vm.prank(users.user1);
        tokenLocker.lock(users.user1, amountToLock, weeksToLockFor);

        // verify locked amount is correct
        (lockedAmount, ) = tokenLocker.getAccountBalances(users.user1);
        lockedAmount -= userPreLockLockedBalance;

        assertEq(lockedAmount, amountToLock);
        // when checking actual token balances, need to multipy lockedAmount by
        // lockToTokenRatio since the token transfer multiplies by lockToTokenRatio
        assertEq(babelToken.balanceOf(users.user1), userPreLockTokedBalance - lockedAmount*INIT_LOCK_TO_TOKEN_RATIO);

        // verify user has positive voting weight in the current week
        uint256 userWeight = tokenLocker.getAccountWeight(users.user1);
        assertTrue(userWeight > 0);

        // verify user has no voting weight for future weeks
        assertEq(tokenLocker.getAccountWeightAt(users.user1, tokenLocker.getWeek()+1), 0);

        // verify total weight for current week all belongs to user
        assertEq(tokenLocker.getTotalWeight(), userWeight);

        // verify no total weight for future weeks
        assertEq(tokenLocker.getTotalWeightAt(tokenLocker.getWeek()+1), 0);

        // verify user active locks are correct
        (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount)
            = tokenLocker.getAccountActiveLocks(users.user1, 0);

        assertEq(activeLockData.length, 1);
        assertEq(frozenAmount, 0);
        assertEq(activeLockData[0].amount, lockedAmount);

        // this behavior is weird and not sure if it is correct;
        // if user locks for   1 week, activeLockData[0].weeksToUnlock == weeksToLockFor + 1 == 2
        // if user locks for > 1 week, activeLockData[0].weeksToUnlock == weeksToLockFor
        assertEq(activeLockData[0].weeksToUnlock, weeksToLockFor == 1 ? 2 : weeksToLockFor);

        weeksLockedFor = activeLockData[0].weeksToUnlock;
    }

    function test_lock(uint256 amountToLock, uint256 weeksToLockFor) public
        returns(uint256, uint256) 
    {
        // bound fuzz inputs
        // need to divide by lockToTokenRatio when calling the
        // lock function since the token transfer multiplies by lockToTokenRatio
        amountToLock = bound(amountToLock, 1, babelToken.balanceOf(users.user1)/INIT_LOCK_TO_TOKEN_RATIO);

        // using -1 week since withdrawing early penalties doesn't reach to tokens
        // locked in the last week
        weeksToLockFor = bound(weeksToLockFor, 1, tokenLocker.MAX_LOCK_WEEKS() - 1);

        return _lock(amountToLock, weeksToLockFor);
    }

    function test_lock_immediate_withdraw(uint256 amountToLock, uint256 weeksToLockFor, uint256 relockFor) external {
        // bound fuzz input
        relockFor = bound(relockFor, 0, tokenLocker.MAX_LOCK_WEEKS());

        // perform the lock
        test_lock(amountToLock, weeksToLockFor);

        // verify immediate withdraw reverts with correct error
        vm.expectRevert("No unlocked tokens");
        vm.prank(users.user1);
        tokenLocker.withdrawExpiredLocks(relockFor);
    }

    function test_lock_warp_withdraw(uint256 amountToLock, uint256 weeksToLockFor, uint256 relockFor) external {
        // bound fuzz input
        relockFor = bound(relockFor, 0, tokenLocker.MAX_LOCK_WEEKS());

        // perform the lock
        (uint256 lockedAmount, uint256 weeksLockedFor) = test_lock(amountToLock, weeksToLockFor);

        // see note about weird behavior at the end of test_lock
        uint256 weeksToWarp = weeksLockedFor == 1 ? 2 : weeksLockedFor;

        // warp time forward so the lock elapses
        vm.warp(block.timestamp + 1 weeks * weeksToWarp);

        // perform the unlock
        vm.prank(users.user1);
        tokenLocker.withdrawExpiredLocks(relockFor);

        // if no relocking, verify user received their tokens
        if(relockFor == 0) {
            assertEq(babelToken.balanceOf(users.user1), INIT_BAB_TKN_TOTAL_SUPPLY);

            // verify no locked amount
            (uint256 locked, uint256 unlocked) = tokenLocker.getAccountBalances(users.user1);
            assertEq(locked, 0);
            assertEq(unlocked, 0);

            // verify user has no voting weight in the current week
            uint256 userWeight = tokenLocker.getAccountWeight(users.user1);
            assertEq(userWeight, 0);

            // verify user has no voting weight for future weeks
            assertEq(tokenLocker.getAccountWeightAt(users.user1, tokenLocker.getWeek()+1), 0);

            // verify no total weight for current week
            assertEq(tokenLocker.getTotalWeight(), 0);

            // verify no total weight for future weeks
            assertEq(tokenLocker.getTotalWeightAt(tokenLocker.getWeek()+1), 0);

            // verify no user active locks
            (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount)
                = tokenLocker.getAccountActiveLocks(users.user1, 0);

            assertEq(activeLockData.length, 0);
            assertEq(frozenAmount, 0);
        }
        // otherwise verify that relocking has occured correctly
        else{
            // verify locked amount is correct
            (uint256 locked, uint256 unlocked) = tokenLocker.getAccountBalances(users.user1);
            assertEq(locked, lockedAmount);
            assertEq(unlocked, 0);
            // when checking actual token balances, need to multipy lockedAmount by
            // lockToTokenRatio since the token transfer multiplies by lockToTokenRatio
            assertEq(babelToken.balanceOf(users.user1), 
                     INIT_BAB_TKN_TOTAL_SUPPLY - lockedAmount*INIT_LOCK_TO_TOKEN_RATIO);

            // verify user has positive voting weight in the current week
            uint256 userWeight = tokenLocker.getAccountWeight(users.user1);
            assertTrue(userWeight > 0);

            // verify user has no voting weight for future weeks
            assertEq(tokenLocker.getAccountWeightAt(users.user1, tokenLocker.getWeek()+1), 0);

            // verify total weight for current week all belongs to user
            assertEq(tokenLocker.getTotalWeight(), userWeight);

            // verify no total weight for future weeks
            assertEq(tokenLocker.getTotalWeightAt(tokenLocker.getWeek()+1), 0);

            // verify user active locks are correct
            (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount)
                = tokenLocker.getAccountActiveLocks(users.user1, 0);

            assertEq(activeLockData.length, 1);
            assertEq(frozenAmount, 0);
            assertEq(activeLockData[0].amount, lockedAmount);

            // this behavior is weird and not sure if it is correct;
            // if user locks for   1 week, activeLockData[0].weeksToUnlock == weeksToLockFor + 1 == 2
            // if user locks for > 1 week, activeLockData[0].weeksToUnlock == weeksToLockFor
            assertEq(activeLockData[0].weeksToUnlock, relockFor == 1 ? 2 : relockFor);
        }
    }

    // returns a valid penalty start time
    function _getPenaltyStartTime(uint256 rand) internal view returns(uint256 startTime) {
        startTime = bound(rand, block.timestamp + 1, block.timestamp + 13 weeks - 1);
    }

    function test_setAllowPenaltyWithdrawAfter(uint256 startTime) public {
        // bound inputs
        startTime = _getPenaltyStartTime(startTime);

        vm.prank(users.owner);
        assertTrue(tokenLocker.setAllowPenaltyWithdrawAfter(startTime));

        assertEq(tokenLocker.allowPenaltyWithdrawAfter(), startTime);
    }

    function test_setAllowPenaltyWithdraw_onlyDeployer() external {
        vm.expectRevert("!deploymentManager");
        tokenLocker.setAllowPenaltyWithdrawAfter(0);
    }

    function test_setAllowPenaltyWithdraw_onlyOnce(uint256 startTime) external {
        // bound inputs
        startTime = _getPenaltyStartTime(startTime);

        // once works
        test_setAllowPenaltyWithdrawAfter(startTime);

        // twice fails
        vm.expectRevert("Already set");
        vm.prank(users.owner);
        tokenLocker.setAllowPenaltyWithdrawAfter(startTime);
    }

    function test_setAllowPenaltyWithdraw_invalidStartTime(uint256 startTime) external {
        // too early fails
        startTime = bound(startTime, 0, block.timestamp);

        vm.expectRevert("Invalid timestamp");
        vm.prank(users.owner);
        tokenLocker.setAllowPenaltyWithdrawAfter(startTime);

        // too late fails
        startTime = bound(startTime, block.timestamp + 13 weeks, type(uint128).max);

        vm.expectRevert("Invalid timestamp");
        vm.prank(users.owner);
        tokenLocker.setAllowPenaltyWithdrawAfter(startTime);
    }

    function test_setPenaltyWithdrawalsEnabled(uint256 startTime, bool status) public {
        // first set the start time
        test_setAllowPenaltyWithdrawAfter(startTime);

        // warp past it
        vm.warp(tokenLocker.allowPenaltyWithdrawAfter() + 1);

        // then toggle the enabled flag
        vm.prank(users.owner);
        tokenLocker.setPenaltyWithdrawalsEnabled(status);

        assertEq(tokenLocker.penaltyWithdrawalsEnabled(), status);
    }
    
    function test_setPenaltyWithdrawalsEnabled_onlyOwner() external {
        vm.expectRevert("Only owner");
        tokenLocker.setPenaltyWithdrawalsEnabled(true);
    }

    function test_setPenaltyWithdrawalsEnabled_beforeStartTime(uint256 startTime, bool status) external {
        // first set the start time
        test_setAllowPenaltyWithdrawAfter(startTime);

        // then immediately attempt setting the flag
        vm.expectRevert("Not yet!");
        vm.prank(users.owner);
        tokenLocker.setPenaltyWithdrawalsEnabled(status);
    }

    function test_withdrawWithPenalty_notEnabled() external {
        vm.expectRevert("Penalty withdrawals are disabled");
        tokenLocker.withdrawWithPenalty(0);
    }

    function test_withdrawWithPenalty_failOnZero() external {
        // first enable penalty withdrawals
        test_setPenaltyWithdrawalsEnabled(0, true);

        // fail when attempting zero input
        vm.expectRevert("Must withdraw a positive amount");
        vm.prank(users.user1);
        tokenLocker.withdrawWithPenalty(0);

        // fail when attempting zero input
        vm.expectRevert("Must withdraw a positive amount");
        vm.prank(users.user1);
        tokenLocker.withdrawWithPenalty(type(uint256).max);
    }

    function test_withdrawWithPenalty(uint256 amountToLock, uint256 weeksToLockFor) external {
        // first enable penalty withdrawals
        test_setPenaltyWithdrawalsEnabled(0, true);

        // save user initial balance
        uint256 userPreTokenBalance = babelToken.balanceOf(users.user1);

        // perform the lock
        (uint256 lockedAmount, uint256 weeksLockedFor) = test_lock(amountToLock, weeksToLockFor);

        uint256 week = tokenLocker.getWeek();

        // verify user has received weight in the current week
        uint256 accountWeightPreWithdraw = tokenLocker.getAccountWeightAt(users.user1, week);
        assertTrue(accountWeightPreWithdraw != 0);

        // verify total weight for current week all belongs to user
        assertEq(tokenLocker.getTotalWeight(), accountWeightPreWithdraw);

        // perform the withdraw with penalty
        vm.prank(users.user1);
        tokenLocker.withdrawWithPenalty(type(uint256).max);

        // calculate expected penalty
        uint256 penaltyOnAmount = (lockedAmount * INIT_LOCK_TO_TOKEN_RATIO * weeksLockedFor) / tokenLocker.MAX_LOCK_WEEKS();

        // verify feeReceiver receives expected penalty
        assertEq(babelToken.balanceOf(address(babelCore.feeReceiver())), penaltyOnAmount);

        // verify user has received their tokens minus the penalty
        assertEq(babelToken.balanceOf(users.user1), userPreTokenBalance - penaltyOnAmount);

        // verify account's weight was reset
        assertEq(tokenLocker.getAccountWeightAt(users.user1, week), 0);

        // verify total weight was reset
        assertEq(tokenLocker.getTotalWeight(), 0);
    }
}
