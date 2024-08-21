// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IBabelVault, ITokenLocker} from "../TestSetup.sol";

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

        // verify we are in the first week
        assertEq(tokenLocker.getWeek(), 0);
    }

    function test_lock(uint256 amountToLock, uint256 weeksToLockFor) public {
        // save user initial balance
        uint256 userInitialBalance = babelToken.balanceOf(users.user1);
        assertEq(userInitialBalance, INIT_BAB_TKN_TOTAL_SUPPLY);

        // bound fuzz inputs
        amountToLock = bound(amountToLock, 1, userInitialBalance);
        weeksToLockFor = bound(weeksToLockFor, 1, tokenLocker.MAX_LOCK_WEEKS());

        // verify user has no voting weight
        assertEq(tokenLocker.getAccountWeight(users.user1), 0);

        // lock up random amount for random weeks
        vm.prank(users.user1);
        tokenLocker.lock(users.user1, amountToLock, weeksToLockFor);

        // verify locked amount is correct
        (uint256 locked, uint256 unlocked) = tokenLocker.getAccountBalances(users.user1);
        assertEq(locked, amountToLock);
        assertEq(unlocked, 0);
        assertEq(babelToken.balanceOf(users.user1), userInitialBalance - amountToLock);

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
        assertEq(activeLockData[0].amount, amountToLock);

        // this behavior is weird and not sure if it is correct;
        // if user locks for   1 week, activeLockData[0].weeksToUnlock == weeksToLockFor + 1 == 2
        // if user locks for > 1 week, activeLockData[0].weeksToUnlock == weeksToLockFor
        assertEq(activeLockData[0].weeksToUnlock, weeksToLockFor == 1 ? 2 : weeksToLockFor);
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
}