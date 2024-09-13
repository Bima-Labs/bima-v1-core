// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IBabelVault, BabelVault, IIncentiveVoting, ITokenLocker, IEmissionReceiver, IRewards, MockEmissionReceiver, MockBoostDelegate, SafeCast} from "../TestSetup.sol";

// dependencies
import {BIMA_100_PCT} from "../../../contracts/dependencies/Constants.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VaultTest is TestSetup {

    uint256 constant internal MAX_COUNT = 10;

    MockBoostDelegate internal mockBoostDelegate;
    MockEmissionReceiver internal mockEmissionReceiver;

    address mockBoostDelegateAddr;
    address mockEmissionReceiverAddr;

    // get around "stack too deep" errors
    uint256 expectedFeeAmount;

    function setUp() public virtual override {
        super.setUp();

        mockBoostDelegate = new MockBoostDelegate();
        mockEmissionReceiver = new MockEmissionReceiver();

        mockBoostDelegateAddr = address(mockBoostDelegate);
        mockEmissionReceiverAddr = address(mockEmissionReceiver);

        expectedFeeAmount = 0;
    }

    function test_constructor() external view {
        // addresses correctly set
        assertEq(address(babelVault.babelToken()), address(babelToken));
        assertEq(address(babelVault.locker()), address(tokenLocker));
        assertEq(address(babelVault.voter()), address(incentiveVoting));
        assertEq(babelVault.deploymentManager(), users.owner);
        assertEq(babelVault.lockToTokenRatio(), INIT_LOCK_TO_TOKEN_RATIO);

        // StabilityPool made receiver with ID 0
        (address account, bool isActive, uint16 updatedWeek) = babelVault.idToReceiver(0);        
        assertEq(account, address(stabilityPool));
        assertEq(isActive, true);
        assertEq(updatedWeek, 0);

        // IncentiveVoting receiver count was increased by 1
        assertEq(incentiveVoting.receiverCount(), 1);
    }

    function test_setInitialParameters() public {
        _vaultSetDefaultInitialParameters();
    }

    function test_transferTokens(address receiver, uint256 amount) external {
        // first need to fund vault with tokens
        test_setInitialParameters();

        // bound fuzz inputs
        vm.assume(receiver != address(0) &&
                  receiver != address(babelVault) &&
                  receiver != address(babelToken));

        amount = bound(amount, 0, babelToken.balanceOf(address(babelVault)));

        // save previous state
        uint256 initialUnallocated = babelVault.unallocatedTotal();
        uint256 initialBabelBalance = babelToken.balanceOf(address(babelVault));
        uint256 initialReceiverBalance = babelToken.balanceOf(receiver);

        vm.prank(users.owner);
        assertTrue(babelVault.transferTokens(IERC20(address(babelToken)), receiver, amount));
        assertEq(babelVault.unallocatedTotal(), initialUnallocated - amount);
        assertEq(babelToken.balanceOf(address(babelVault)), initialBabelBalance - amount);
        assertEq(babelToken.balanceOf(receiver), initialReceiverBalance + amount);

        // test with non-BabelToken
        IERC20 mockToken = new ERC20("Mock", "MCK");
        uint256 mockAmount = 1000 * 10 ** 18;
        deal(address(mockToken), address(babelVault), mockAmount);

        uint256 initialMockBalance = mockToken.balanceOf(address(babelVault));
        uint256 initialReceiverMockBalance = mockToken.balanceOf(receiver);

        vm.prank(users.owner);
        assertTrue(babelVault.transferTokens(mockToken, receiver, mockAmount));

        assertEq(babelVault.unallocatedTotal(), initialUnallocated - amount); // Unchanged
        assertEq(mockToken.balanceOf(address(babelVault)), initialMockBalance - mockAmount);
        assertEq(mockToken.balanceOf(receiver), initialReceiverMockBalance + mockAmount);
    }

    function test_transferTokens_revert(address receiver, uint256 amount) external {
        // first need to fund vault with tokens
        test_setInitialParameters();

        // bound fuzz inputs
        vm.assume(receiver != address(0));
        amount = bound(amount, 0, babelToken.balanceOf(address(babelVault)));

        // Test revert on non-owner call
        vm.prank(users.user1);
        vm.expectRevert("Only owner");
        babelVault.transferTokens(IERC20(address(babelToken)), receiver, amount);

        // Test revert on self-transfer
        vm.prank(users.owner);
        vm.expectRevert("Self transfer denied");
        babelVault.transferTokens(IERC20(address(babelToken)), address(babelVault), amount);

        // Test revert on insufficient balance
        uint256 excessiveAmount = babelToken.balanceOf(address(babelVault)) + 1;
        vm.prank(users.owner);
        vm.expectRevert();
        babelVault.transferTokens(IERC20(address(babelToken)), receiver, excessiveAmount);
    }

    function test_registerReceiver(uint256 count, uint256 weeksToAdd) external {
        // bound fuzz inputs
        count = bound(count, 1, MAX_COUNT); // Limit count to avoid excessive gas usage or memory issues
        weeksToAdd = bound(weeksToAdd, 0, MAX_COUNT);

        // Set up week
        vm.warp(block.timestamp + weeksToAdd * 1 weeks);

        // helper registers receivers and performs all necessary checks
        _vaultRegisterReceiver(mockEmissionReceiverAddr, count);
    }

    function test_registerReceiver_zeroCount() external {
        vm.prank(users.owner);
        vm.expectRevert();
        babelVault.registerReceiver(address(1), 0);
    }

    function test_registerReceiver_revert_zeroAddress() external {
        vm.prank(users.owner);
        vm.expectRevert();
        babelVault.registerReceiver(address(0), 1);
    }

    function test_registerReceiver_revert_babelVault() external {
        vm.prank(users.owner);
        vm.expectRevert();
        babelVault.registerReceiver(address(babelVault), 1);
    }

    function test_registerReceiver_revert_nonOwner() external {
        vm.prank(users.user1);
        vm.expectRevert();
        babelVault.registerReceiver(address(1), 1);
    }

    function test_claimBoostDelegationFees_failNothingToClaim() external {
        // first need to fund vault with tokens
        test_setInitialParameters();

        vm.expectRevert("Nothing to claim");
        vm.prank(users.user1);
        babelVault.claimBoostDelegationFees(users.user1);
    }

    function test_allocateNewEmissions_unallocatedTokensDecreasedButZeroAllocated() external {
        // first need to fund vault with tokens
        test_setInitialParameters();

        // helper registers receivers and performs all necessary checks
        uint256 RECEIVER_ID = _vaultRegisterReceiver(mockEmissionReceiverAddr, 1);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // cache state prior to allocateNewEmissions
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        
        // entire supply still not allocated
        uint256 initialUnallocated = babelVault.unallocatedTotal();
        assertEq(initialUnallocated, INIT_BAB_TKN_TOTAL_SUPPLY);

        // receiver calls allocateNewEmissions
        vm.prank(mockEmissionReceiverAddr);
        uint256 allocated = babelVault.allocateNewEmissions(RECEIVER_ID);

        // verify BabelVault::totalUpdateWeek current system week
        assertEq(babelVault.totalUpdateWeek(), systemWeek);

        // verify unallocated supply reduced by weekly emission percent
        uint256 firstWeekEmissions = INIT_BAB_TKN_TOTAL_SUPPLY*INIT_ES_WEEKLY_PCT/BIMA_100_PCT;
        assertTrue(firstWeekEmissions > 0);
        assertEq(babelVault.unallocatedTotal(), initialUnallocated - firstWeekEmissions);

        // verify emissions correctly set for current week
        assertEq(babelVault.weeklyEmissions(systemWeek), firstWeekEmissions);

        // verify BabelVault::lockWeeks reduced correctly
        assertEq(babelVault.lockWeeks(), INIT_ES_LOCK_WEEKS-INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver active and last processed week = system week
        (, bool isActive, uint16 updatedWeek) = babelVault.idToReceiver(RECEIVER_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // however even though BabelVault::unallocatedTotal was reduced by the
        // first week emissions, nothing was allocated to the receiver
        assertEq(allocated, 0);

        // this is because EmissionSchedule::getReceiverWeeklyEmissions calls
        // IncentiveVoting::getReceiverVotePct which looks back 1 week, and receiver
        // had no voting weight and there was no total voting weight at all in that week
        assertEq(incentiveVoting.getTotalWeightAt(systemWeek-1), 0);
        assertEq(incentiveVoting.getReceiverWeightAt(RECEIVER_ID, systemWeek-1), 0);

        // tokens were effectively lost since the vault's unallocated supply decreased
        // but no tokens were actually allocated to receivers since there was no
        // voting weight
    }

    function test_transferAllocatedTokens_noPendingRewards_inBoostGraceWeeks_inVaultLockWeeks(uint256 transferAmount) external {
        // first get some allocated tokens
        test_allocateNewEmissions_oneReceiverWithVotingWeight();

        uint256 allocatedBalancePre = babelVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        transferAmount = bound(transferAmount, 0, allocatedBalancePre);

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 accountWeeklyEarnedPre = babelVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek);
        uint128 unallocatedTotalPre = babelVault.unallocatedTotal();
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // receiver has nothing locked prior to call
        (uint256 receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
        assertEq(receiverLockedBalance, 0);
        uint256 totalLockedWeightPre = tokenLocker.getTotalWeight();
        uint256 futureLockerTotalWeeklyUnlocksPre = tokenLocker.getTotalWeeklyUnlocks(systemWeek+babelVault.lockWeeks());
        uint256 futureLockerAccountWeeklyUnlocksPre = tokenLocker.getAccountWeeklyUnlocks(mockEmissionReceiverAddr, systemWeek+babelVault.lockWeeks());

        // then transfer allocated tokens
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(babelVault.transferAllocatedTokens(mockEmissionReceiverAddr, mockEmissionReceiverAddr, transferAmount));

        // verify allocated balance reduced by transfer amount
        assertEq(babelVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - transferAmount);

        // verify account weekly earned increased by transferred amount
        assertEq(babelVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek),
                 accountWeeklyEarnedPre + transferAmount);

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(babelVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward was correctly set to the "dust"
        // amount that was too small to lock
        uint256 lockedAmount = transferAmount / INIT_LOCK_TO_TOKEN_RATIO;
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr),
                 transferAmount - lockedAmount * INIT_LOCK_TO_TOKEN_RATIO);

        // verify lock has been correctly created
        if(lockedAmount > 0) {
            (receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
            assertEq(receiverLockedBalance, lockedAmount);

            // verify receiver has positive voting weight in the current week
            assertTrue(tokenLocker.getAccountWeight(mockEmissionReceiverAddr) > 0);

            // verify receiver has no voting weight for future weeks
            assertEq(tokenLocker.getAccountWeightAt(mockEmissionReceiverAddr, systemWeek+1), 0);

            // verify total weight for current week increased by receiver weight
            assertEq(tokenLocker.getTotalWeight(), totalLockedWeightPre + tokenLocker.getAccountWeight(mockEmissionReceiverAddr));

            // verify no total weight for future weeks
            assertEq(tokenLocker.getTotalWeightAt(systemWeek+1), 0);

            // verify receiver active locks are correct
            (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount)
                = tokenLocker.getAccountActiveLocks(mockEmissionReceiverAddr, 0);

            assertEq(activeLockData.length, 1);
            assertEq(frozenAmount, 0);
            assertEq(activeLockData[0].amount, lockedAmount);
            assertEq(activeLockData[0].weeksToUnlock, babelVault.lockWeeks());

            // verify future total weekly unlocks updated for locked amount
            assertEq(tokenLocker.getTotalWeeklyUnlocks(systemWeek+babelVault.lockWeeks()),
                    futureLockerTotalWeeklyUnlocksPre + lockedAmount);

            // verify future account weekly unlocks updated for locked amount
            assertEq(tokenLocker.getAccountWeeklyUnlocks(mockEmissionReceiverAddr, systemWeek+babelVault.lockWeeks()),
                    futureLockerAccountWeeklyUnlocksPre + lockedAmount);
        }
    }

    // helper function
    function _allocateNewEmissionsAndWarp(uint256 weeksToWarp) internal {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY/2);

        // helper registers receivers and performs all necessary checks
        address receiver = address(mockEmissionReceiver);
        uint256 RECEIVER_ID = _vaultRegisterReceiver(receiver, 1);

        // user votes for receiver to get emissions
        IIncentiveVoting.Vote[] memory votes = new IIncentiveVoting.Vote[](1);
        votes[0].id = RECEIVER_ID;
        votes[0].points = incentiveVoting.MAX_POINTS();
        
        vm.prank(users.user1);
        incentiveVoting.registerAccountWeightAndVote(users.user1, 52, votes);

        // warp time by input
        vm.warp(block.timestamp + 1 weeks * weeksToWarp);

        // cache state prior to allocateNewEmissions
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        
        // initial unallocated supply has not changed
        assertEq(babelVault.unallocatedTotal(), initialUnallocated);

        // receiver calls allocateNewEmissions
        vm.prank(receiver);
        babelVault.allocateNewEmissions(RECEIVER_ID);

        // verify BabelVault::totalUpdateWeek current system week
        assertEq(babelVault.totalUpdateWeek(), systemWeek);
    }

    function test_transferAllocatedTokens_noPendingRewards_inBoostGraceWeeks_outVaultLockWeeks(uint256 transferAmount) external {
        // first get some allocated tokens and warp time to after the
        // vault's forced locking period expires
        _allocateNewEmissionsAndWarp(INIT_ES_LOCK_WEEKS);

        // verify vault's forced locking period has expired
        assertEq(babelVault.lockWeeks(), 0);

        uint256 allocatedBalancePre = babelVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        transferAmount = bound(transferAmount, 0, allocatedBalancePre);

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 accountWeeklyEarnedPre = babelVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek);
        uint128 unallocatedTotalPre = babelVault.unallocatedTotal();
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);
        uint256 vaultTokenBalancePre = babelToken.balanceOf(address(babelVault));
        uint256 receiverTokenBalancePre = babelToken.balanceOf(mockEmissionReceiverAddr);

        // then transfer allocated tokens
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(babelVault.transferAllocatedTokens(mockEmissionReceiverAddr, mockEmissionReceiverAddr, transferAmount));

        // verify allocated balance reduced by transfer amount
        assertEq(babelVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - transferAmount);

        // verify account weekly earned increased by transferred amount
        assertEq(babelVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek),
                 accountWeeklyEarnedPre + transferAmount);

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(babelVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward remains zero as since the forced
        // lock period has expired, the tokens will be transferred instead
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // verify tokens have been sent from vault to receiver
        assertEq(babelToken.balanceOf(address(babelVault)), vaultTokenBalancePre - transferAmount);
        assertEq(babelToken.balanceOf(mockEmissionReceiverAddr), receiverTokenBalancePre + transferAmount);
    }

    function test_batchClaimRewards_noBoostDelegate_inBoostGraceWeeks_inVaultLockWeeks(uint256 rewardAmount) external {
        // first get some allocated tokens
        test_allocateNewEmissions_oneReceiverWithVotingWeight();

        uint256 allocatedBalancePre = babelVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        rewardAmount = bound(rewardAmount, 0, allocatedBalancePre);
        mockEmissionReceiver.setReward(rewardAmount);

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 accountWeeklyEarnedPre = babelVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek);
        uint128 unallocatedTotalPre = babelVault.unallocatedTotal();
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // receiver has nothing locked prior to call
        (uint256 receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
        assertEq(receiverLockedBalance, 0);
        uint256 totalLockedWeightPre = tokenLocker.getTotalWeight();
        uint256 futureLockerTotalWeeklyUnlocksPre = tokenLocker.getTotalWeeklyUnlocks(systemWeek+babelVault.lockWeeks());
        uint256 futureLockerAccountWeeklyUnlocksPre = tokenLocker.getAccountWeeklyUnlocks(mockEmissionReceiverAddr, systemWeek+babelVault.lockWeeks());

        // batch claim rewards
        IRewards[] memory rewardContracts = new IRewards[](1);
        rewardContracts[0] = IRewards(mockEmissionReceiver);
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(babelVault.batchClaimRewards(mockEmissionReceiverAddr, address(0), rewardContracts, 0));

        // verify allocated balance reduced by reward amount
        assertEq(babelVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - rewardAmount);

        // verify account weekly earned increased by reward amount
        assertEq(babelVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek),
                 accountWeeklyEarnedPre + rewardAmount);

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(babelVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward was correctly set to the "dust"
        // amount that was too small to lock
        uint256 lockedAmount = rewardAmount / INIT_LOCK_TO_TOKEN_RATIO;
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr),
                 rewardAmount - lockedAmount * INIT_LOCK_TO_TOKEN_RATIO);

        // verify lock has been correctly created
        if(lockedAmount > 0) {
            (receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
            assertEq(receiverLockedBalance, lockedAmount);

            // verify receiver has positive voting weight in the current week
            assertTrue(tokenLocker.getAccountWeight(mockEmissionReceiverAddr) > 0);

            // verify receiver has no voting weight for future weeks
            assertEq(tokenLocker.getAccountWeightAt(mockEmissionReceiverAddr, systemWeek+1), 0);

            // verify total weight for current week increased by receiver weight
            assertEq(tokenLocker.getTotalWeight(), totalLockedWeightPre + tokenLocker.getAccountWeight(mockEmissionReceiverAddr));

            // verify no total weight for future weeks
            assertEq(tokenLocker.getTotalWeightAt(systemWeek+1), 0);

            // verify receiver active locks are correct
            (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount)
                = tokenLocker.getAccountActiveLocks(mockEmissionReceiverAddr, 0);

            assertEq(activeLockData.length, 1);
            assertEq(frozenAmount, 0);
            assertEq(activeLockData[0].amount, lockedAmount);
            assertEq(activeLockData[0].weeksToUnlock, babelVault.lockWeeks());

            // verify future total weekly unlocks updated for locked amount
            assertEq(tokenLocker.getTotalWeeklyUnlocks(systemWeek+babelVault.lockWeeks()),
                    futureLockerTotalWeeklyUnlocksPre + lockedAmount);

            // verify future account weekly unlocks updated for locked amount
            assertEq(tokenLocker.getAccountWeeklyUnlocks(mockEmissionReceiverAddr, systemWeek+babelVault.lockWeeks()),
                    futureLockerAccountWeeklyUnlocksPre + lockedAmount);
        }
    }

    function test_batchClaimRewards_noBoostDelegate_inBoostGraceWeeks_outVaultLockWeeks(uint256 rewardAmount) external {
        // first get some allocated tokens and warp time to after the
        // vault's forced locking period expires
        _allocateNewEmissionsAndWarp(INIT_ES_LOCK_WEEKS);

        // verify vault's forced locking period has expired
        assertEq(babelVault.lockWeeks(), 0);

        uint256 allocatedBalancePre = babelVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        rewardAmount = bound(rewardAmount, 0, allocatedBalancePre);
        mockEmissionReceiver.setReward(rewardAmount);

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 accountWeeklyEarnedPre = babelVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek);
        uint128 unallocatedTotalPre = babelVault.unallocatedTotal();
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);
        uint256 vaultTokenBalancePre = babelToken.balanceOf(address(babelVault));
        uint256 receiverTokenBalancePre = babelToken.balanceOf(mockEmissionReceiverAddr);

        // batch claim rewards
        IRewards[] memory rewardContracts = new IRewards[](1);
        rewardContracts[0] = IRewards(mockEmissionReceiver);
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(babelVault.batchClaimRewards(mockEmissionReceiverAddr, address(0), rewardContracts, 0));

        // verify allocated balance reduced by reward amount
        assertEq(babelVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - rewardAmount);

        // verify account weekly earned increased by reward amount
        assertEq(babelVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek),
                 accountWeeklyEarnedPre + rewardAmount);

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(babelVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward remains zero as since the forced
        // lock period has expired, the tokens will be transferred instead
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // verify tokens have been sent from vault to receiver
        assertEq(babelToken.balanceOf(address(babelVault)), vaultTokenBalancePre - rewardAmount);
        assertEq(babelToken.balanceOf(mockEmissionReceiverAddr), receiverTokenBalancePre + rewardAmount);
    }

    function test_batchClaimRewards_withBoostDelegate_inBoostGraceWeeks_inVaultLockWeeks(
        uint256 rewardAmount, uint16 maxFeePct) external {
        // first get some allocated tokens
        test_allocateNewEmissions_oneReceiverWithVotingWeight();

        uint256 allocatedBalancePre = babelVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        rewardAmount = bound(rewardAmount, 0, allocatedBalancePre);
        mockEmissionReceiver.setReward(rewardAmount);
        maxFeePct = SafeCast.toUint16(bound(maxFeePct, 0, BIMA_100_PCT));

        // setup boost delegate
        vm.prank(mockBoostDelegateAddr);
        assertTrue(babelVault.setBoostDelegationParams(true, maxFeePct, mockBoostDelegateAddr));

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 delegateWeeklyEarnedPre = babelVault.getAccountWeeklyEarned(mockBoostDelegateAddr, systemWeek);
        uint128 unallocatedTotalPre = babelVault.unallocatedTotal();
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // receiver has nothing locked prior to call
        (uint256 receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
        assertEq(receiverLockedBalance, 0);
        uint256 totalLockedWeightPre = tokenLocker.getTotalWeight();
        uint256 futureLockerTotalWeeklyUnlocksPre = tokenLocker.getTotalWeeklyUnlocks(systemWeek+babelVault.lockWeeks());
        uint256 futureLockerAccountWeeklyUnlocksPre = tokenLocker.getAccountWeeklyUnlocks(mockEmissionReceiverAddr, systemWeek+babelVault.lockWeeks());

        // batch claim rewards
        IRewards[] memory rewardContracts = new IRewards[](1);
        rewardContracts[0] = IRewards(mockEmissionReceiver);
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(babelVault.batchClaimRewards(mockEmissionReceiverAddr, mockBoostDelegateAddr, rewardContracts, maxFeePct));

        // verify allocated balance reduced by reward amount
        assertEq(babelVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - rewardAmount);

        // calculate expected fee
        expectedFeeAmount = rewardAmount * maxFeePct / BIMA_100_PCT;

        // verify delegate has stored pending reward equal to fee
        assertEq(babelVault.getStoredPendingReward(mockBoostDelegateAddr), expectedFeeAmount);

        // verify delegate weekly earned increased by reward amount
        assertEq(babelVault.getAccountWeeklyEarned(mockBoostDelegateAddr, systemWeek),
                 delegateWeeklyEarnedPre + rewardAmount);
        // verify account weekly earned was unchanged
        assertEq(babelVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek), 0);

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(babelVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward was correctly set to the "dust"
        // amount that was too small to lock
        uint256 lockedAmount = (rewardAmount - expectedFeeAmount) / INIT_LOCK_TO_TOKEN_RATIO;
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr),
                 rewardAmount - expectedFeeAmount - lockedAmount * INIT_LOCK_TO_TOKEN_RATIO);

        // verify lock has been correctly created
        if(lockedAmount > 0) {
            (receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
            assertEq(receiverLockedBalance, lockedAmount);

            // verify receiver has positive voting weight in the current week
            assertTrue(tokenLocker.getAccountWeight(mockEmissionReceiverAddr) > 0);

            // verify receiver has no voting weight for future weeks
            assertEq(tokenLocker.getAccountWeightAt(mockEmissionReceiverAddr, systemWeek+1), 0);

            // verify total weight for current week increased by receiver weight
            assertEq(tokenLocker.getTotalWeight(), totalLockedWeightPre + tokenLocker.getAccountWeight(mockEmissionReceiverAddr));

            // verify no total weight for future weeks
            assertEq(tokenLocker.getTotalWeightAt(systemWeek+1), 0);

            // verify receiver active locks are correct
            (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount)
                = tokenLocker.getAccountActiveLocks(mockEmissionReceiverAddr, 0);

            assertEq(activeLockData.length, 1);
            assertEq(frozenAmount, 0);
            assertEq(activeLockData[0].amount, lockedAmount);
            assertEq(activeLockData[0].weeksToUnlock, babelVault.lockWeeks());

            // verify future total weekly unlocks updated for locked amount
            assertEq(tokenLocker.getTotalWeeklyUnlocks(systemWeek+babelVault.lockWeeks()),
                    futureLockerTotalWeeklyUnlocksPre + lockedAmount);

            // verify future account weekly unlocks updated for locked amount
            assertEq(tokenLocker.getAccountWeeklyUnlocks(mockEmissionReceiverAddr, systemWeek+babelVault.lockWeeks()),
                    futureLockerAccountWeeklyUnlocksPre + lockedAmount);

            // claim fees for boost delegate if enough were accrued
            if(expectedFeeAmount >= INIT_LOCK_TO_TOKEN_RATIO) {
                // cache state before call
                (receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockBoostDelegateAddr);
                assertEq(receiverLockedBalance, 0);
                totalLockedWeightPre = tokenLocker.getTotalWeight();
                futureLockerTotalWeeklyUnlocksPre = tokenLocker.getTotalWeeklyUnlocks(systemWeek+babelVault.lockWeeks());
                futureLockerAccountWeeklyUnlocksPre = tokenLocker.getAccountWeeklyUnlocks(mockBoostDelegateAddr, systemWeek+babelVault.lockWeeks());

                lockedAmount = expectedFeeAmount / INIT_LOCK_TO_TOKEN_RATIO;

                // perform the call
                vm.prank(mockBoostDelegateAddr);
                assertTrue(babelVault.claimBoostDelegationFees(mockBoostDelegateAddr));

                // verify pending reward correctly updated
                assertEq(babelVault.getStoredPendingReward(mockBoostDelegateAddr),
                         expectedFeeAmount - lockedAmount * INIT_LOCK_TO_TOKEN_RATIO);

                // verify delegate has positive voting weight in the current week
                assertTrue(tokenLocker.getAccountWeight(mockBoostDelegateAddr) > 0);

                // verify delegate has no voting weight for future weeks
                assertEq(tokenLocker.getAccountWeightAt(mockBoostDelegateAddr, systemWeek+1), 0);

                // verify total weight for current week increased by delegate weight
                assertEq(tokenLocker.getTotalWeight(), totalLockedWeightPre + tokenLocker.getAccountWeight(mockBoostDelegateAddr));

                // verify no total weight for future weeks
                assertEq(tokenLocker.getTotalWeightAt(systemWeek+1), 0);

                // verify delegate active locks are correct
                (activeLockData, frozenAmount)
                    = tokenLocker.getAccountActiveLocks(mockBoostDelegateAddr, 0);

                assertEq(activeLockData.length, 1);
                assertEq(frozenAmount, 0);
                assertEq(activeLockData[0].amount, lockedAmount);
                assertEq(activeLockData[0].weeksToUnlock, babelVault.lockWeeks());

                // verify future total weekly unlocks updated for locked amount
                assertEq(tokenLocker.getTotalWeeklyUnlocks(systemWeek+babelVault.lockWeeks()),
                        futureLockerTotalWeeklyUnlocksPre + lockedAmount);

                // verify future account weekly unlocks updated for locked amount
                assertEq(tokenLocker.getAccountWeeklyUnlocks(mockBoostDelegateAddr, systemWeek+babelVault.lockWeeks()),
                        futureLockerAccountWeeklyUnlocksPre + lockedAmount);
            }
        }
    }

    function test_batchClaimRewards_withBoostDelegate_inBoostGraceWeeks_outVaultLockWeeks(
        uint256 rewardAmount, uint16 maxFeePct) external {
        // first get some allocated tokens and warp time to after the
        // vault's forced locking period expires
        _allocateNewEmissionsAndWarp(INIT_ES_LOCK_WEEKS);

        // verify vault's forced locking period has expired
        assertEq(babelVault.lockWeeks(), 0);

        uint256 allocatedBalancePre = babelVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        rewardAmount = bound(rewardAmount, 0, allocatedBalancePre);
        mockEmissionReceiver.setReward(rewardAmount);
        maxFeePct = SafeCast.toUint16(bound(maxFeePct, 0, BIMA_100_PCT));

        // setup boost delegate
        vm.prank(mockBoostDelegateAddr);
        assertTrue(babelVault.setBoostDelegationParams(true, maxFeePct, mockBoostDelegateAddr));

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 delegateWeeklyEarnedPre = babelVault.getAccountWeeklyEarned(mockBoostDelegateAddr, systemWeek);
        uint128 unallocatedTotalPre = babelVault.unallocatedTotal();
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);
        uint256 vaultTokenBalancePre = babelToken.balanceOf(address(babelVault));
        uint256 receiverTokenBalancePre = babelToken.balanceOf(mockEmissionReceiverAddr);

        // batch claim rewards
        IRewards[] memory rewardContracts = new IRewards[](1);
        rewardContracts[0] = IRewards(mockEmissionReceiver);
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(babelVault.batchClaimRewards(mockEmissionReceiverAddr, mockBoostDelegateAddr, rewardContracts, maxFeePct));

        // verify allocated balance reduced by reward amount
        assertEq(babelVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - rewardAmount);

        // calculate expected fee
        expectedFeeAmount = rewardAmount * maxFeePct / BIMA_100_PCT;

        // verify delegate has stored pending reward equal to fee
        assertEq(babelVault.getStoredPendingReward(mockBoostDelegateAddr), expectedFeeAmount);

        // verify delegate weekly earned increased by reward amount
        assertEq(babelVault.getAccountWeeklyEarned(mockBoostDelegateAddr, systemWeek),
                 delegateWeeklyEarnedPre + rewardAmount);
        // verify account weekly earned was unchanged
        assertEq(babelVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek), 0);

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(babelVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward remains zero as since the forced
        // lock period has expired, the tokens will be transferred instead
        assertEq(babelVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // verify tokens have been sent from vault to receiver, not including
        // the fee which was given as a stored pending reward to delegate
        assertEq(babelToken.balanceOf(address(babelVault)), vaultTokenBalancePre - (rewardAmount - expectedFeeAmount));
        assertEq(babelToken.balanceOf(mockEmissionReceiverAddr), receiverTokenBalancePre + (rewardAmount - expectedFeeAmount));

        // claim fees for boost delegate if enough were accrued
        if(expectedFeeAmount >= INIT_LOCK_TO_TOKEN_RATIO) {
            // cache state before call
            vaultTokenBalancePre = babelToken.balanceOf(address(babelVault));
            receiverTokenBalancePre = babelToken.balanceOf(mockBoostDelegateAddr);

            vm.prank(mockBoostDelegateAddr);
            assertTrue(babelVault.claimBoostDelegationFees(mockBoostDelegateAddr));

            // very stored pending fees were reset 
            assertEq(babelVault.getStoredPendingReward(mockBoostDelegateAddr), 0);

            // // verify tokens have been sent from vault to receiver
            assertEq(babelToken.balanceOf(address(babelVault)), vaultTokenBalancePre - expectedFeeAmount);
            assertEq(babelToken.balanceOf(mockBoostDelegateAddr), receiverTokenBalancePre + expectedFeeAmount);
        }
    }

    function test_allocateNewEmissions_oneReceiverWithVotingWeight() public {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY/2);

        // helper registers receivers and performs all necessary checks
        address receiver = address(mockEmissionReceiver);
        uint256 RECEIVER_ID = _vaultRegisterReceiver(receiver, 1);

        // user votes for receiver to get emissions
        IIncentiveVoting.Vote[] memory votes = new IIncentiveVoting.Vote[](1);
        votes[0].id = RECEIVER_ID;
        votes[0].points = incentiveVoting.MAX_POINTS();
        
        vm.prank(users.user1);
        incentiveVoting.registerAccountWeightAndVote(users.user1, 52, votes);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // cache state prior to allocateNewEmissions
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        
        // initial unallocated supply has not changed
        assertEq(babelVault.unallocatedTotal(), initialUnallocated);

        // receiver calls allocateNewEmissions
        vm.prank(receiver);
        uint256 allocated = babelVault.allocateNewEmissions(RECEIVER_ID);

        // verify BabelVault::totalUpdateWeek current system week
        assertEq(babelVault.totalUpdateWeek(), systemWeek);

        // verify unallocated supply reduced by weekly emission percent
        uint256 firstWeekEmissions = initialUnallocated*INIT_ES_WEEKLY_PCT/BIMA_100_PCT;
        assertTrue(firstWeekEmissions > 0);
        assertEq(babelVault.unallocatedTotal(), initialUnallocated - firstWeekEmissions);

        // verify emissions correctly set for current week
        assertEq(babelVault.weeklyEmissions(systemWeek), firstWeekEmissions);

        // verify BabelVault::lockWeeks reduced correctly
        assertEq(babelVault.lockWeeks(), INIT_ES_LOCK_WEEKS-INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver active and last processed week = system week
        (, bool isActive, uint16 updatedWeek) = babelVault.idToReceiver(RECEIVER_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // verify receiver was allocated the first week's emissions   
        assertEq(allocated, firstWeekEmissions);
        assertEq(babelVault.allocated(receiver), firstWeekEmissions);

        // receiver calls allocateNewEmissions again
        vm.prank(receiver);
        uint256 allocated2 = babelVault.allocateNewEmissions(RECEIVER_ID);

        // doesn't return any more since already been called for current system week
        assertEq(allocated2, 0);
        assertEq(babelVault.allocated(receiver), firstWeekEmissions);
    }

    function test_allocateNewEmissions_oneDisabledReceiverWithVotingWeight() external {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY/2);

        // helper registers receivers and performs all necessary checks
        address receiver = address(mockEmissionReceiver);
        uint256 RECEIVER_ID = _vaultRegisterReceiver(receiver, 1);

        // user votes for receiver to get emissions
        IIncentiveVoting.Vote[] memory votes = new IIncentiveVoting.Vote[](1);
        votes[0].id = RECEIVER_ID;
        votes[0].points = incentiveVoting.MAX_POINTS();
        
        vm.prank(users.user1);
        incentiveVoting.registerAccountWeightAndVote(users.user1, 52, votes);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // cache state prior to allocateNewEmissions
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        
        // initial unallocated supply has not changed
        assertEq(babelVault.unallocatedTotal(), initialUnallocated);

        // disable emission receiver prior to calling allocateNewEmissions
        vm.prank(users.owner);
        babelVault.setReceiverIsActive(RECEIVER_ID, false);

        // receiver calls allocateNewEmissions
        vm.prank(receiver);
        uint256 allocated = babelVault.allocateNewEmissions(RECEIVER_ID);

        // verify BabelVault::totalUpdateWeek current system week
        assertEq(babelVault.totalUpdateWeek(), systemWeek);

        // verify unallocated supply remained the same; this happens because
        // 1) BabelVault::_allocateTotalWeekly decreases total unallocated by
        //    the weekly emission amount
        // 2) BabelVault::allocateNewEmissions increases total unallocated by
        //    the amount disabled receivers would have received if enabled; in
        //    this case only 1 receiver so entire emissions get credited back
        //    to unallocated supply
        uint256 firstWeekEmissions = initialUnallocated*INIT_ES_WEEKLY_PCT/BIMA_100_PCT;
        assertTrue(firstWeekEmissions > 0);
        assertEq(babelVault.unallocatedTotal(), initialUnallocated);

        // verify emissions correctly set for current week
        assertEq(babelVault.weeklyEmissions(systemWeek), firstWeekEmissions);

        // verify BabelVault::lockWeeks reduced correctly
        assertEq(babelVault.lockWeeks(), INIT_ES_LOCK_WEEKS-INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver disabled and last processed week = system week
        (, bool isActive, uint16 updatedWeek) = babelVault.idToReceiver(RECEIVER_ID);
        assertEq(isActive, false);
        assertEq(updatedWeek, systemWeek);

        // verify receiver was allocated zero as they were disabled
        assertEq(allocated, 0);
        assertEq(babelVault.allocated(receiver), 0);
    }

    function test_allocateNewEmissions_twoReceiversWithEqualVotingWeight() external {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY/2);

        // helper registers receivers and performs all necessary checks
        address receiver = address(mockEmissionReceiver);
        uint256 RECEIVER_ID = _vaultRegisterReceiver(receiver, 1);

        // owner registers second emissions receiver
        MockEmissionReceiver mockEmissionReceiver2 = new MockEmissionReceiver();
        address receiver2 = address(mockEmissionReceiver2);
        uint256 RECEIVER2_ID = _vaultRegisterReceiver(receiver2, 1);

        // user votes equally for both receivers to get emissions
        IIncentiveVoting.Vote[] memory votes = new IIncentiveVoting.Vote[](2);
        votes[0].id = RECEIVER_ID;
        votes[0].points = incentiveVoting.MAX_POINTS() / 2;
        votes[1].id = RECEIVER2_ID;
        votes[1].points = incentiveVoting.MAX_POINTS() / 2;
        
        vm.prank(users.user1);
        incentiveVoting.registerAccountWeightAndVote(users.user1, 52, votes);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // cache state prior to allocateNewEmissions
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        
        // initial unallocated supply has not changed
        assertEq(babelVault.unallocatedTotal(), initialUnallocated);

        // receiver calls allocateNewEmissions
        vm.prank(receiver);
        uint256 allocated = babelVault.allocateNewEmissions(RECEIVER_ID);

        // verify BabelVault::totalUpdateWeek current system week
        assertEq(babelVault.totalUpdateWeek(), systemWeek);

        // verify unallocated supply reduced by weekly emission percent
        uint256 firstWeekEmissions = initialUnallocated*INIT_ES_WEEKLY_PCT/BIMA_100_PCT;
        assertTrue(firstWeekEmissions > 0);
        uint256 remainingUnallocated = initialUnallocated - firstWeekEmissions;
        assertEq(babelVault.unallocatedTotal(), remainingUnallocated);

        // verify emissions correctly set for current week
        assertEq(babelVault.weeklyEmissions(systemWeek), firstWeekEmissions);

        // verify BabelVault::lockWeeks reduced correctly
        assertEq(babelVault.lockWeeks(), INIT_ES_LOCK_WEEKS-INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver active and last processed week = system week
        (, bool isActive, uint16 updatedWeek) = babelVault.idToReceiver(RECEIVER_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // verify receiver was allocated half of first week's emissions   
        assertEq(allocated, firstWeekEmissions/2);
        assertEq(babelVault.allocated(receiver), firstWeekEmissions/2);

        // receiver2 calls allocateNewEmissions
        vm.prank(receiver2);
        allocated = babelVault.allocateNewEmissions(RECEIVER2_ID);
        
        // verify most things remain the same
        assertEq(babelVault.totalUpdateWeek(), systemWeek);
        assertEq(babelVault.unallocatedTotal(), remainingUnallocated);
        assertEq(babelVault.weeklyEmissions(systemWeek), firstWeekEmissions);
        assertEq(babelVault.lockWeeks(), INIT_ES_LOCK_WEEKS-INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver2 active and last processed week = system week
        (, isActive, updatedWeek) = babelVault.idToReceiver(RECEIVER2_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // verify receiver2 was allocated half of first week's emissions   
        assertEq(allocated, firstWeekEmissions/2);
        assertEq(babelVault.allocated(receiver2), firstWeekEmissions/2);
    }

    function test_allocateNewEmissions_twoReceiversWithUnequalExtremeVotingWeight() external {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY/2);

        // helper registers receivers and performs all necessary checks
        address receiver = address(mockEmissionReceiver);
        uint256 RECEIVER_ID = _vaultRegisterReceiver(receiver, 1);

        // owner registers second emissions receiver
        MockEmissionReceiver mockEmissionReceiver2 = new MockEmissionReceiver();
        address receiver2 = address(mockEmissionReceiver2);
        uint256 RECEIVER2_ID = _vaultRegisterReceiver(receiver2, 1);

        // user votes for both receivers to get emissions but with
        // extreme voting weights (1 and Max-1)
        IIncentiveVoting.Vote[] memory votes = new IIncentiveVoting.Vote[](2);
        votes[0].id = RECEIVER_ID;
        votes[0].points = 1;
        votes[1].id = RECEIVER2_ID;
        votes[1].points = incentiveVoting.MAX_POINTS()-1;
        
        vm.prank(users.user1);
        incentiveVoting.registerAccountWeightAndVote(users.user1, 52, votes);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // cache state prior to allocateNewEmissions
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        
        // initial unallocated supply has not changed
        assertEq(babelVault.unallocatedTotal(), initialUnallocated);

        // receiver calls allocateNewEmissions
        vm.prank(receiver);
        uint256 allocated = babelVault.allocateNewEmissions(RECEIVER_ID);

        // verify BabelVault::totalUpdateWeek current system week
        assertEq(babelVault.totalUpdateWeek(), systemWeek);

        // verify unallocated supply reduced by weekly emission percent
        uint256 firstWeekEmissions = initialUnallocated*INIT_ES_WEEKLY_PCT/BIMA_100_PCT;
        assertTrue(firstWeekEmissions > 0);
        uint256 remainingUnallocated = initialUnallocated - firstWeekEmissions;
        assertEq(babelVault.unallocatedTotal(), remainingUnallocated);

        // verify emissions correctly set for current week
        assertEq(babelVault.weeklyEmissions(systemWeek), firstWeekEmissions);

        // verify BabelVault::lockWeeks reduced correctly
        assertEq(babelVault.lockWeeks(), INIT_ES_LOCK_WEEKS-INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver active and last processed week = system week
        (, bool isActive, uint16 updatedWeek) = babelVault.idToReceiver(RECEIVER_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // receiver2 calls allocateNewEmissions
        vm.prank(receiver2);
        uint256 allocated2 = babelVault.allocateNewEmissions(RECEIVER2_ID);
        
        // verify most things remain the same
        assertEq(babelVault.totalUpdateWeek(), systemWeek);
        assertEq(babelVault.unallocatedTotal(), remainingUnallocated);
        assertEq(babelVault.weeklyEmissions(systemWeek), firstWeekEmissions);
        assertEq(babelVault.lockWeeks(), INIT_ES_LOCK_WEEKS-INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver2 active and last processed week = system week
        (, isActive, updatedWeek) = babelVault.idToReceiver(RECEIVER2_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // due to rounding a small amount of tokens is lost as the recorded
        // weekly emission is greater than the actual amounts allocated
        // to the two receivers
        assertEq(firstWeekEmissions,     536870911875000000000000000);
        assertEq(allocated + allocated2, 536870911874999999999999999);

        assertEq(allocated,  53687000037499936332460);
        assertEq(babelVault.allocated(receiver), 53687000037499936332460);
        assertEq(allocated2, 536817224874962500063667539);
        assertEq(babelVault.allocated(receiver2), 536817224874962500063667539);
    }
    
    function test_unfreeze_fixForFailToRemoveActiveVotes() external {
        // setup vault giving user1 half supply to lock for voting power
        _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY/2);

        // verify user1 has 1 unfrozen lock
        (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount)
            = tokenLocker.getAccountActiveLocks(users.user1, 0);
        assertEq(activeLockData.length, 1); // 1 active lock
        assertEq(frozenAmount, 0); // 0 frozen amount
        assertEq(activeLockData[0].amount, 2147483647);
        assertEq(activeLockData[0].weeksToUnlock, 52);

        // register receiver
        uint256 RECEIVER_ID = _vaultRegisterReceiver(address(mockEmissionReceiver), 1);

        // user1 votes for receiver using their unfrozen locked weight
        IIncentiveVoting.Vote[] memory votes = new IIncentiveVoting.Vote[](1);
        votes[0].id = RECEIVER_ID;
        votes[0].points = incentiveVoting.MAX_POINTS();
        
        vm.prank(users.user1);
        incentiveVoting.registerAccountWeightAndVote(users.user1, 52, votes);

        // verify user1 has 1 active vote using their unfrozen locked weight
        votes = incentiveVoting.getAccountCurrentVotes(users.user1);
        assertEq(votes.length, 1);
        assertEq(votes[0].id, RECEIVER_ID);
        assertEq(votes[0].points, 10_000);

        // user1 freezes their lock
        vm.prank(users.user1);
        tokenLocker.freeze();

        // verify user1 has 1 frozen lock
        (activeLockData, frozenAmount) = tokenLocker.getAccountActiveLocks(users.user1, 0);
        assertEq(activeLockData.length, 0); // 0 active lock
        assertGt(frozenAmount, 0); // positive frozen amount

        // user1 unfreezes without keeping their past votes
        vm.prank(users.user1);
        tokenLocker.unfreeze(false); // keepIncentivesVote = false

        // user1 had their active vote cleared
        votes = incentiveVoting.getAccountCurrentVotes(users.user1);
        assertEq(votes.length, 0);
    }

}