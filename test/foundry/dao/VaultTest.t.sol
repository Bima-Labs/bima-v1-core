// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IBimaVault, BimaVault, EmissionSchedule, IIncentiveVoting, ITokenLocker, IEmissionReceiver, IEmissionSchedule, IBoostCalculator, IRewards, MockEmissionReceiver, MockBoostDelegate, SafeCast} from "../TestSetup.sol";

// dependencies
import {BIMA_100_PCT} from "../../../contracts/dependencies/Constants.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VaultTest is TestSetup {
    uint256 internal constant MAX_COUNT = 10;

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
        assertEq(address(bimaVault.bimaToken()), address(bimaToken));
        assertEq(address(bimaVault.locker()), address(tokenLocker));
        assertEq(address(bimaVault.voter()), address(incentiveVoting));
        assertEq(bimaVault.deploymentManager(), users.owner);
        assertEq(bimaVault.lockToTokenRatio(), INIT_LOCK_TO_TOKEN_RATIO);

        // StabilityPool made receiver with ID 0
        (address account, bool isActive, uint16 updatedWeek) = bimaVault.idToReceiver(0);
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
        vm.assume(receiver != address(0) && receiver != address(bimaVault) && receiver != address(bimaToken));

        amount = bound(amount, 0, bimaToken.balanceOf(address(bimaVault)));

        // save previous state
        uint256 initialUnallocated = bimaVault.unallocatedTotal();
        uint256 initialBimaBalance = bimaToken.balanceOf(address(bimaVault));
        uint256 initialReceiverBalance = bimaToken.balanceOf(receiver);

        vm.prank(users.owner);
        assertTrue(bimaVault.transferTokens(IERC20(address(bimaToken)), receiver, amount));
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated - amount);
        assertEq(bimaToken.balanceOf(address(bimaVault)), initialBimaBalance - amount);
        assertEq(bimaToken.balanceOf(receiver), initialReceiverBalance + amount);

        // test with non-BimaToken
        IERC20 mockToken = new ERC20("Mock", "MCK");
        uint256 mockAmount = 1000 * 10 ** 18;
        deal(address(mockToken), address(bimaVault), mockAmount);

        uint256 initialMockBalance = mockToken.balanceOf(address(bimaVault));
        uint256 initialReceiverMockBalance = mockToken.balanceOf(receiver);

        vm.prank(users.owner);
        assertTrue(bimaVault.transferTokens(mockToken, receiver, mockAmount));

        assertEq(bimaVault.unallocatedTotal(), initialUnallocated - amount); // Unchanged
        assertEq(mockToken.balanceOf(address(bimaVault)), initialMockBalance - mockAmount);
        assertEq(mockToken.balanceOf(receiver), initialReceiverMockBalance + mockAmount);
    }

    function test_transferTokens_revert(address receiver, uint256 amount) external {
        // first need to fund vault with tokens
        test_setInitialParameters();

        // bound fuzz inputs
        vm.assume(receiver != address(0));
        amount = bound(amount, 0, bimaToken.balanceOf(address(bimaVault)));

        // Test revert on non-owner call
        vm.prank(users.user1);
        vm.expectRevert("Only owner");
        bimaVault.transferTokens(IERC20(address(bimaToken)), receiver, amount);

        // Test revert on self-transfer
        vm.prank(users.owner);
        vm.expectRevert("Self transfer denied");
        bimaVault.transferTokens(IERC20(address(bimaToken)), address(bimaVault), amount);

        // Test revert on insufficient balance
        uint256 excessiveAmount = bimaToken.balanceOf(address(bimaVault)) + 1;
        vm.prank(users.owner);
        vm.expectRevert();
        bimaVault.transferTokens(IERC20(address(bimaToken)), receiver, excessiveAmount);
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
        bimaVault.registerReceiver(address(1), 0);
    }

    function test_registerReceiver_revert_zeroAddress() external {
        vm.prank(users.owner);
        vm.expectRevert();
        bimaVault.registerReceiver(address(0), 1);
    }

    function test_registerReceiver_revert_bimaVault() external {
        vm.prank(users.owner);
        vm.expectRevert();
        bimaVault.registerReceiver(address(bimaVault), 1);
    }

    function test_registerReceiver_revert_nonOwner() external {
        vm.prank(users.user1);
        vm.expectRevert();
        bimaVault.registerReceiver(address(1), 1);
    }

    function test_claimBoostDelegationFees_failNothingToClaim() external {
        // first need to fund vault with tokens
        test_setInitialParameters();

        vm.expectRevert("Nothing to claim");
        vm.prank(users.user1);
        bimaVault.claimBoostDelegationFees(users.user1);
    }

    function test_allocateNewEmissions_unallocatedTokensDecreasedButZeroAllocated() external {
        // first need to fund vault with tokens
        test_setInitialParameters();

        // helper registers receivers and performs all necessary checks
        uint256 RECEIVER_ID = _vaultRegisterReceiver(mockEmissionReceiverAddr, 1);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // cache state prior to allocateNewEmissions
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());

        // entire supply still not allocated
        uint256 initialUnallocated = bimaVault.unallocatedTotal();
        assertEq(initialUnallocated, INIT_BAB_TKN_TOTAL_SUPPLY);

        // receiver calls allocateNewEmissions
        vm.prank(mockEmissionReceiverAddr);
        uint256 allocated = bimaVault.allocateNewEmissions(RECEIVER_ID);

        // verify BimaVault::totalUpdateWeek current system week
        assertEq(bimaVault.totalUpdateWeek(), systemWeek);

        // verify unallocated supply reduced by weekly emission percent
        uint256 firstWeekEmissions = (INIT_BAB_TKN_TOTAL_SUPPLY * INIT_ES_WEEKLY_PCT) / BIMA_100_PCT;
        assertTrue(firstWeekEmissions > 0);
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated - firstWeekEmissions);

        // verify emissions correctly set for current week
        assertEq(bimaVault.weeklyEmissions(systemWeek), firstWeekEmissions);

        // verify BimaVault::lockWeeks reduced correctly
        assertEq(bimaVault.lockWeeks(), INIT_ES_LOCK_WEEKS - INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver active and last processed week = system week
        (, bool isActive, uint16 updatedWeek) = bimaVault.idToReceiver(RECEIVER_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // however even though BimaVault::unallocatedTotal was reduced by the
        // first week emissions, nothing was allocated to the receiver
        assertEq(allocated, 0);

        // this is because EmissionSchedule::getReceiverWeeklyEmissions calls
        // IncentiveVoting::getReceiverVotePct which looks back 1 week, and receiver
        // had no voting weight and there was no total voting weight at all in that week
        assertEq(incentiveVoting.getTotalWeightAt(systemWeek - 1), 0);
        assertEq(incentiveVoting.getReceiverWeightAt(RECEIVER_ID, systemWeek - 1), 0);

        // tokens were effectively lost since the vault's unallocated supply decreased
        // but no tokens were actually allocated to receivers since there was no
        // voting weight in the first week
    }

    function test_transferAllocatedTokens_noPendingRewards_inBoostGraceWeeks_inVaultLockWeeks(
        uint256 transferAmount
    ) external {
        // first get some allocated tokens
        test_allocateNewEmissions_oneReceiverWithVotingWeight();

        uint256 allocatedBalancePre = bimaVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        transferAmount = bound(transferAmount, 0, allocatedBalancePre);

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 accountWeeklyEarnedPre = bimaVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek);
        uint128 unallocatedTotalPre = bimaVault.unallocatedTotal();
        assertEq(bimaVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // receiver has nothing locked prior to call
        (uint256 receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
        assertEq(receiverLockedBalance, 0);
        uint256 totalLockedWeightPre = tokenLocker.getTotalWeight();
        uint256 futureLockerTotalWeeklyUnlocksPre = tokenLocker.getTotalWeeklyUnlocks(
            systemWeek + bimaVault.lockWeeks()
        );
        uint256 futureLockerAccountWeeklyUnlocksPre = tokenLocker.getAccountWeeklyUnlocks(
            mockEmissionReceiverAddr,
            systemWeek + bimaVault.lockWeeks()
        );

        // then transfer allocated tokens
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(
            bimaVault.transferAllocatedTokens(mockEmissionReceiverAddr, mockEmissionReceiverAddr, transferAmount)
        );

        // verify allocated balance reduced by transfer amount
        assertEq(bimaVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - transferAmount);

        // verify account weekly earned increased by transferred amount
        assertEq(
            bimaVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek),
            accountWeeklyEarnedPre + transferAmount
        );

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(bimaVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward was correctly set to the "dust"
        // amount that was too small to lock
        uint256 lockedAmount = transferAmount / INIT_LOCK_TO_TOKEN_RATIO;
        assertEq(
            bimaVault.getStoredPendingReward(mockEmissionReceiverAddr),
            transferAmount - lockedAmount * INIT_LOCK_TO_TOKEN_RATIO
        );

        // verify lock has been correctly created
        if (lockedAmount > 0) {
            (receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
            assertEq(receiverLockedBalance, lockedAmount);

            // verify receiver has positive voting weight in the current week
            assertTrue(tokenLocker.getAccountWeight(mockEmissionReceiverAddr) > 0);

            // verify receiver has no voting weight for future weeks
            assertEq(tokenLocker.getAccountWeightAt(mockEmissionReceiverAddr, systemWeek + 1), 0);

            // verify total weight for current week increased by receiver weight
            assertEq(
                tokenLocker.getTotalWeight(),
                totalLockedWeightPre + tokenLocker.getAccountWeight(mockEmissionReceiverAddr)
            );

            // verify no total weight for future weeks
            assertEq(tokenLocker.getTotalWeightAt(systemWeek + 1), 0);

            // verify receiver active locks are correct
            (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount) = tokenLocker.getAccountActiveLocks(
                mockEmissionReceiverAddr,
                0
            );

            assertEq(activeLockData.length, 1);
            assertEq(frozenAmount, 0);
            assertEq(activeLockData[0].amount, lockedAmount);
            assertEq(activeLockData[0].weeksToUnlock, bimaVault.lockWeeks());

            // verify future total weekly unlocks updated for locked amount
            assertEq(
                tokenLocker.getTotalWeeklyUnlocks(systemWeek + bimaVault.lockWeeks()),
                futureLockerTotalWeeklyUnlocksPre + lockedAmount
            );

            // verify future account weekly unlocks updated for locked amount
            assertEq(
                tokenLocker.getAccountWeeklyUnlocks(mockEmissionReceiverAddr, systemWeek + bimaVault.lockWeeks()),
                futureLockerAccountWeeklyUnlocksPre + lockedAmount
            );
        }
    }

    // helper function
    function _allocateNewEmissionsAndWarp(uint256 weeksToWarp) internal {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY / 2, true);

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
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());

        // initial unallocated supply has not changed
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated);

        // receiver calls allocateNewEmissions
        vm.prank(receiver);
        bimaVault.allocateNewEmissions(RECEIVER_ID);

        // verify BimaVault::totalUpdateWeek current system week
        assertEq(bimaVault.totalUpdateWeek(), systemWeek);
    }

    function test_transferAllocatedTokens_noPendingRewards_inBoostGraceWeeks_outVaultLockWeeks(
        uint256 transferAmount
    ) external {
        // first get some allocated tokens and warp time to after the
        // vault's forced locking period expires
        _allocateNewEmissionsAndWarp(INIT_ES_LOCK_WEEKS);

        // verify vault's forced locking period has expired
        assertEq(bimaVault.lockWeeks(), 0);

        uint256 allocatedBalancePre = bimaVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        transferAmount = bound(transferAmount, 0, allocatedBalancePre);

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 accountWeeklyEarnedPre = bimaVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek);
        uint128 unallocatedTotalPre = bimaVault.unallocatedTotal();
        assertEq(bimaVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);
        uint256 vaultTokenBalancePre = bimaToken.balanceOf(address(bimaVault));
        uint256 receiverTokenBalancePre = bimaToken.balanceOf(mockEmissionReceiverAddr);

        // then transfer allocated tokens
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(
            bimaVault.transferAllocatedTokens(mockEmissionReceiverAddr, mockEmissionReceiverAddr, transferAmount)
        );

        // verify allocated balance reduced by transfer amount
        assertEq(bimaVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - transferAmount);

        // verify account weekly earned increased by transferred amount
        assertEq(
            bimaVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek),
            accountWeeklyEarnedPre + transferAmount
        );

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(bimaVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward remains zero as since the forced
        // lock period has expired, the tokens will be transferred instead
        assertEq(bimaVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // verify tokens have been sent from vault to receiver
        assertEq(bimaToken.balanceOf(address(bimaVault)), vaultTokenBalancePre - transferAmount);
        assertEq(bimaToken.balanceOf(mockEmissionReceiverAddr), receiverTokenBalancePre + transferAmount);
    }

    function test_batchClaimRewards_noBoostDelegate_inBoostGraceWeeks_inVaultLockWeeks(uint256 rewardAmount) external {
        // first get some allocated tokens
        test_allocateNewEmissions_oneReceiverWithVotingWeight();

        uint256 allocatedBalancePre = bimaVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        rewardAmount = bound(rewardAmount, 0, allocatedBalancePre);
        mockEmissionReceiver.setReward(rewardAmount);

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 accountWeeklyEarnedPre = bimaVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek);
        uint128 unallocatedTotalPre = bimaVault.unallocatedTotal();
        assertEq(bimaVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // receiver has nothing locked prior to call
        (uint256 receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
        assertEq(receiverLockedBalance, 0);
        uint256 totalLockedWeightPre = tokenLocker.getTotalWeight();
        uint256 futureLockerTotalWeeklyUnlocksPre = tokenLocker.getTotalWeeklyUnlocks(
            systemWeek + bimaVault.lockWeeks()
        );
        uint256 futureLockerAccountWeeklyUnlocksPre = tokenLocker.getAccountWeeklyUnlocks(
            mockEmissionReceiverAddr,
            systemWeek + bimaVault.lockWeeks()
        );

        {
            (uint256 adjustedAmount, uint256 feeToDelegate) = bimaVault.claimableRewardAfterBoost(
                mockEmissionReceiverAddr,
                mockEmissionReceiverAddr,
                address(0),
                mockEmissionReceiver
            );

            assertEq(adjustedAmount, rewardAmount);
            assertEq(feeToDelegate, 0);
        }
        {
            (uint256 maxBoosted, uint256 boosted) = bimaVault.getClaimableWithBoost(mockEmissionReceiverAddr);

            assertEq(maxBoosted, bimaVault.weeklyEmissions(systemWeek));
            assertEq(boosted, maxBoosted);
        }

        // batch claim rewards
        IRewards[] memory rewardContracts = new IRewards[](1);
        rewardContracts[0] = IRewards(mockEmissionReceiver);
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(bimaVault.batchClaimRewards(mockEmissionReceiverAddr, address(0), rewardContracts, 0));

        // verify allocated balance reduced by reward amount
        assertEq(bimaVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - rewardAmount);

        // verify account weekly earned increased by reward amount
        assertEq(
            bimaVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek),
            accountWeeklyEarnedPre + rewardAmount
        );

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(bimaVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward was correctly set to the "dust"
        // amount that was too small to lock
        uint256 lockedAmount = rewardAmount / INIT_LOCK_TO_TOKEN_RATIO;
        assertEq(
            bimaVault.getStoredPendingReward(mockEmissionReceiverAddr),
            rewardAmount - lockedAmount * INIT_LOCK_TO_TOKEN_RATIO
        );

        // verify lock has been correctly created
        if (lockedAmount > 0) {
            (receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
            assertEq(receiverLockedBalance, lockedAmount);

            // verify receiver has positive voting weight in the current week
            assertTrue(tokenLocker.getAccountWeight(mockEmissionReceiverAddr) > 0);

            // verify receiver has no voting weight for future weeks
            assertEq(tokenLocker.getAccountWeightAt(mockEmissionReceiverAddr, systemWeek + 1), 0);

            // verify total weight for current week increased by receiver weight
            assertEq(
                tokenLocker.getTotalWeight(),
                totalLockedWeightPre + tokenLocker.getAccountWeight(mockEmissionReceiverAddr)
            );

            // verify no total weight for future weeks
            assertEq(tokenLocker.getTotalWeightAt(systemWeek + 1), 0);

            // verify receiver active locks are correct
            (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount) = tokenLocker.getAccountActiveLocks(
                mockEmissionReceiverAddr,
                0
            );

            assertEq(activeLockData.length, 1);
            assertEq(frozenAmount, 0);
            assertEq(activeLockData[0].amount, lockedAmount);
            assertEq(activeLockData[0].weeksToUnlock, bimaVault.lockWeeks());

            // verify future total weekly unlocks updated for locked amount
            assertEq(
                tokenLocker.getTotalWeeklyUnlocks(systemWeek + bimaVault.lockWeeks()),
                futureLockerTotalWeeklyUnlocksPre + lockedAmount
            );

            // verify future account weekly unlocks updated for locked amount
            assertEq(
                tokenLocker.getAccountWeeklyUnlocks(mockEmissionReceiverAddr, systemWeek + bimaVault.lockWeeks()),
                futureLockerAccountWeeklyUnlocksPre + lockedAmount
            );
        }
    }

    function test_batchClaimRewards_noBoostDelegate_inBoostGraceWeeks_outVaultLockWeeks(uint256 rewardAmount) external {
        // first get some allocated tokens and warp time to after the
        // vault's forced locking period expires
        _allocateNewEmissionsAndWarp(INIT_ES_LOCK_WEEKS);

        // verify vault's forced locking period has expired
        assertEq(bimaVault.lockWeeks(), 0);

        uint256 allocatedBalancePre = bimaVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        rewardAmount = bound(rewardAmount, 0, allocatedBalancePre);
        mockEmissionReceiver.setReward(rewardAmount);

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 accountWeeklyEarnedPre = bimaVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek);
        uint128 unallocatedTotalPre = bimaVault.unallocatedTotal();
        assertEq(bimaVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);
        uint256 vaultTokenBalancePre = bimaToken.balanceOf(address(bimaVault));
        uint256 receiverTokenBalancePre = bimaToken.balanceOf(mockEmissionReceiverAddr);

        {
            (uint256 adjustedAmount, uint256 feeToDelegate) = bimaVault.claimableRewardAfterBoost(
                mockEmissionReceiverAddr,
                mockEmissionReceiverAddr,
                address(0),
                mockEmissionReceiver
            );

            assertEq(adjustedAmount, rewardAmount);
            assertEq(feeToDelegate, 0);
        }
        {
            (uint256 maxBoosted, uint256 boosted) = bimaVault.getClaimableWithBoost(mockEmissionReceiverAddr);

            assertEq(maxBoosted, bimaVault.weeklyEmissions(systemWeek));
            assertEq(boosted, maxBoosted);
        }

        // batch claim rewards
        IRewards[] memory rewardContracts = new IRewards[](1);
        rewardContracts[0] = IRewards(mockEmissionReceiver);
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(bimaVault.batchClaimRewards(mockEmissionReceiverAddr, address(0), rewardContracts, 0));

        // verify allocated balance reduced by reward amount
        assertEq(bimaVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - rewardAmount);

        // verify account weekly earned increased by reward amount
        assertEq(
            bimaVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek),
            accountWeeklyEarnedPre + rewardAmount
        );

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(bimaVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward remains zero as since the forced
        // lock period has expired, the tokens will be transferred instead
        assertEq(bimaVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // verify tokens have been sent from vault to receiver
        assertEq(bimaToken.balanceOf(address(bimaVault)), vaultTokenBalancePre - rewardAmount);
        assertEq(bimaToken.balanceOf(mockEmissionReceiverAddr), receiverTokenBalancePre + rewardAmount);
    }

    function test_batchClaimRewards_withBoostDelegate_inBoostGraceWeeks_inVaultLockWeeks(
        uint256 rewardAmount,
        uint16 maxFeePct
    ) external {
        // first get some allocated tokens
        test_allocateNewEmissions_oneReceiverWithVotingWeight();

        uint256 allocatedBalancePre = bimaVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        rewardAmount = bound(rewardAmount, 0, allocatedBalancePre);
        mockEmissionReceiver.setReward(rewardAmount);
        maxFeePct = SafeCast.toUint16(bound(maxFeePct, 0, BIMA_100_PCT));

        // setup boost delegate
        vm.prank(mockBoostDelegateAddr);
        assertTrue(bimaVault.setBoostDelegationParams(true, maxFeePct, mockBoostDelegateAddr));

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 delegateWeeklyEarnedPre = bimaVault.getAccountWeeklyEarned(mockBoostDelegateAddr, systemWeek);
        uint128 unallocatedTotalPre = bimaVault.unallocatedTotal();
        assertEq(bimaVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // receiver has nothing locked prior to call
        (uint256 receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
        assertEq(receiverLockedBalance, 0);
        uint256 totalLockedWeightPre = tokenLocker.getTotalWeight();
        uint256 futureLockerTotalWeeklyUnlocksPre = tokenLocker.getTotalWeeklyUnlocks(
            systemWeek + bimaVault.lockWeeks()
        );
        uint256 futureLockerAccountWeeklyUnlocksPre = tokenLocker.getAccountWeeklyUnlocks(
            mockEmissionReceiverAddr,
            systemWeek + bimaVault.lockWeeks()
        );

        // calculate expected fee
        expectedFeeAmount = (rewardAmount * maxFeePct) / BIMA_100_PCT;

        {
            (uint256 adjustedAmount, uint256 feeToDelegate) = bimaVault.claimableRewardAfterBoost(
                mockEmissionReceiverAddr,
                mockEmissionReceiverAddr,
                mockBoostDelegateAddr,
                mockEmissionReceiver
            );

            assertEq(adjustedAmount, rewardAmount);
            assertEq(feeToDelegate, expectedFeeAmount);
        }
        {
            (uint256 maxBoosted, uint256 boosted) = bimaVault.getClaimableWithBoost(mockEmissionReceiverAddr);

            assertEq(maxBoosted, bimaVault.weeklyEmissions(systemWeek));
            assertEq(boosted, maxBoosted);
        }

        // batch claim rewards
        IRewards[] memory rewardContracts = new IRewards[](1);
        rewardContracts[0] = IRewards(mockEmissionReceiver);
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(
            bimaVault.batchClaimRewards(mockEmissionReceiverAddr, mockBoostDelegateAddr, rewardContracts, maxFeePct)
        );

        // verify allocated balance reduced by reward amount
        assertEq(bimaVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - rewardAmount);

        // verify delegate has stored pending reward equal to fee
        assertEq(bimaVault.getStoredPendingReward(mockBoostDelegateAddr), expectedFeeAmount);

        // verify delegate weekly earned increased by reward amount
        assertEq(
            bimaVault.getAccountWeeklyEarned(mockBoostDelegateAddr, systemWeek),
            delegateWeeklyEarnedPre + rewardAmount
        );
        // verify account weekly earned was unchanged
        assertEq(bimaVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek), 0);

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(bimaVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward was correctly set to the "dust"
        // amount that was too small to lock
        uint256 lockedAmount = (rewardAmount - expectedFeeAmount) / INIT_LOCK_TO_TOKEN_RATIO;
        assertEq(
            bimaVault.getStoredPendingReward(mockEmissionReceiverAddr),
            rewardAmount - expectedFeeAmount - lockedAmount * INIT_LOCK_TO_TOKEN_RATIO
        );

        // verify lock has been correctly created
        if (lockedAmount > 0) {
            (receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockEmissionReceiverAddr);
            assertEq(receiverLockedBalance, lockedAmount);

            // verify receiver has positive voting weight in the current week
            assertTrue(tokenLocker.getAccountWeight(mockEmissionReceiverAddr) > 0);

            // verify receiver has no voting weight for future weeks
            assertEq(tokenLocker.getAccountWeightAt(mockEmissionReceiverAddr, systemWeek + 1), 0);

            // verify total weight for current week increased by receiver weight
            assertEq(
                tokenLocker.getTotalWeight(),
                totalLockedWeightPre + tokenLocker.getAccountWeight(mockEmissionReceiverAddr)
            );

            // verify no total weight for future weeks
            assertEq(tokenLocker.getTotalWeightAt(systemWeek + 1), 0);

            // verify receiver active locks are correct
            (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount) = tokenLocker.getAccountActiveLocks(
                mockEmissionReceiverAddr,
                0
            );

            assertEq(activeLockData.length, 1);
            assertEq(frozenAmount, 0);
            assertEq(activeLockData[0].amount, lockedAmount);
            assertEq(activeLockData[0].weeksToUnlock, bimaVault.lockWeeks());

            // verify future total weekly unlocks updated for locked amount
            assertEq(
                tokenLocker.getTotalWeeklyUnlocks(systemWeek + bimaVault.lockWeeks()),
                futureLockerTotalWeeklyUnlocksPre + lockedAmount
            );

            // verify future account weekly unlocks updated for locked amount
            assertEq(
                tokenLocker.getAccountWeeklyUnlocks(mockEmissionReceiverAddr, systemWeek + bimaVault.lockWeeks()),
                futureLockerAccountWeeklyUnlocksPre + lockedAmount
            );

            // claim fees for boost delegate if enough were accrued
            if (expectedFeeAmount >= INIT_LOCK_TO_TOKEN_RATIO) {
                // cache state before call
                (receiverLockedBalance, ) = tokenLocker.getAccountBalances(mockBoostDelegateAddr);
                assertEq(receiverLockedBalance, 0);
                totalLockedWeightPre = tokenLocker.getTotalWeight();
                futureLockerTotalWeeklyUnlocksPre = tokenLocker.getTotalWeeklyUnlocks(
                    systemWeek + bimaVault.lockWeeks()
                );
                futureLockerAccountWeeklyUnlocksPre = tokenLocker.getAccountWeeklyUnlocks(
                    mockBoostDelegateAddr,
                    systemWeek + bimaVault.lockWeeks()
                );

                lockedAmount = expectedFeeAmount / INIT_LOCK_TO_TOKEN_RATIO;

                assertEq(bimaVault.claimableBoostDelegationFees(mockBoostDelegateAddr), expectedFeeAmount);

                // perform the call
                vm.prank(mockBoostDelegateAddr);
                assertTrue(bimaVault.claimBoostDelegationFees(mockBoostDelegateAddr));

                // verify pending reward correctly updated
                assertEq(
                    bimaVault.getStoredPendingReward(mockBoostDelegateAddr),
                    expectedFeeAmount - lockedAmount * INIT_LOCK_TO_TOKEN_RATIO
                );

                // verify delegate has positive voting weight in the current week
                assertTrue(tokenLocker.getAccountWeight(mockBoostDelegateAddr) > 0);

                // verify delegate has no voting weight for future weeks
                assertEq(tokenLocker.getAccountWeightAt(mockBoostDelegateAddr, systemWeek + 1), 0);

                // verify total weight for current week increased by delegate weight
                assertEq(
                    tokenLocker.getTotalWeight(),
                    totalLockedWeightPre + tokenLocker.getAccountWeight(mockBoostDelegateAddr)
                );

                // verify no total weight for future weeks
                assertEq(tokenLocker.getTotalWeightAt(systemWeek + 1), 0);

                // verify delegate active locks are correct
                (activeLockData, frozenAmount) = tokenLocker.getAccountActiveLocks(mockBoostDelegateAddr, 0);

                assertEq(activeLockData.length, 1);
                assertEq(frozenAmount, 0);
                assertEq(activeLockData[0].amount, lockedAmount);
                assertEq(activeLockData[0].weeksToUnlock, bimaVault.lockWeeks());

                // verify future total weekly unlocks updated for locked amount
                assertEq(
                    tokenLocker.getTotalWeeklyUnlocks(systemWeek + bimaVault.lockWeeks()),
                    futureLockerTotalWeeklyUnlocksPre + lockedAmount
                );

                // verify future account weekly unlocks updated for locked amount
                assertEq(
                    tokenLocker.getAccountWeeklyUnlocks(mockBoostDelegateAddr, systemWeek + bimaVault.lockWeeks()),
                    futureLockerAccountWeeklyUnlocksPre + lockedAmount
                );
            }
        }
    }

    function test_batchClaimRewards_withBoostDelegate_inBoostGraceWeeks_outVaultLockWeeks(
        uint256 rewardAmount,
        uint16 maxFeePct
    ) external {
        // first get some allocated tokens and warp time to after the
        // vault's forced locking period expires
        _allocateNewEmissionsAndWarp(INIT_ES_LOCK_WEEKS);

        // verify vault's forced locking period has expired
        assertEq(bimaVault.lockWeeks(), 0);

        uint256 allocatedBalancePre = bimaVault.allocated(mockEmissionReceiverAddr);
        assertTrue(allocatedBalancePre > 0);

        // bound fuzz inputs
        rewardAmount = bound(rewardAmount, 0, allocatedBalancePre);
        mockEmissionReceiver.setReward(rewardAmount);
        maxFeePct = SafeCast.toUint16(bound(maxFeePct, 0, BIMA_100_PCT));

        // setup boost delegate
        vm.prank(mockBoostDelegateAddr);
        assertTrue(bimaVault.setBoostDelegationParams(true, maxFeePct, mockBoostDelegateAddr));
        assertTrue(bimaVault.isBoostDelegatedEnabled(mockBoostDelegateAddr));

        // cache state prior to call
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());
        // verify still inside boost grace weeks
        assertTrue(systemWeek < boostCalc.MAX_BOOST_GRACE_WEEKS());
        uint128 delegateWeeklyEarnedPre = bimaVault.getAccountWeeklyEarned(mockBoostDelegateAddr, systemWeek);
        uint128 unallocatedTotalPre = bimaVault.unallocatedTotal();
        assertEq(bimaVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);
        uint256 vaultTokenBalancePre = bimaToken.balanceOf(address(bimaVault));
        uint256 receiverTokenBalancePre = bimaToken.balanceOf(mockEmissionReceiverAddr);

        // calculate expected fee
        expectedFeeAmount = (rewardAmount * maxFeePct) / BIMA_100_PCT;

        {
            (uint256 adjustedAmount, uint256 feeToDelegate) = bimaVault.claimableRewardAfterBoost(
                mockEmissionReceiverAddr,
                mockEmissionReceiverAddr,
                mockBoostDelegateAddr,
                mockEmissionReceiver
            );

            assertEq(adjustedAmount, rewardAmount);
            assertEq(feeToDelegate, expectedFeeAmount);
        }
        {
            (uint256 maxBoosted, uint256 boosted) = bimaVault.getClaimableWithBoost(mockEmissionReceiverAddr);

            assertEq(maxBoosted, bimaVault.weeklyEmissions(systemWeek));
            assertEq(boosted, maxBoosted);
        }

        // batch claim rewards
        IRewards[] memory rewardContracts = new IRewards[](1);
        rewardContracts[0] = IRewards(mockEmissionReceiver);
        vm.prank(mockEmissionReceiverAddr);
        assertTrue(
            bimaVault.batchClaimRewards(mockEmissionReceiverAddr, mockBoostDelegateAddr, rewardContracts, maxFeePct)
        );

        // verify allocated balance reduced by reward amount
        assertEq(bimaVault.allocated(mockEmissionReceiverAddr), allocatedBalancePre - rewardAmount);

        // verify delegate has stored pending reward equal to fee
        assertEq(bimaVault.getStoredPendingReward(mockBoostDelegateAddr), expectedFeeAmount);

        // verify delegate weekly earned increased by reward amount
        assertEq(
            bimaVault.getAccountWeeklyEarned(mockBoostDelegateAddr, systemWeek),
            delegateWeeklyEarnedPre + rewardAmount
        );
        // verify account weekly earned was unchanged
        assertEq(bimaVault.getAccountWeeklyEarned(mockEmissionReceiverAddr, systemWeek), 0);

        // verify unallocated total remains the same as the transfer took
        // place inside the BoostCalculator's MAX_BOOST_GRACE_WEEKS
        assertEq(bimaVault.unallocatedTotal(), unallocatedTotalPre);

        // verify receiver's pending reward remains zero as since the forced
        // lock period has expired, the tokens will be transferred instead
        assertEq(bimaVault.getStoredPendingReward(mockEmissionReceiverAddr), 0);

        // verify tokens have been sent from vault to receiver, not including
        // the fee which was given as a stored pending reward to delegate
        assertEq(bimaToken.balanceOf(address(bimaVault)), vaultTokenBalancePre - (rewardAmount - expectedFeeAmount));
        assertEq(
            bimaToken.balanceOf(mockEmissionReceiverAddr),
            receiverTokenBalancePre + (rewardAmount - expectedFeeAmount)
        );

        // claim fees for boost delegate if enough were accrued
        if (expectedFeeAmount >= INIT_LOCK_TO_TOKEN_RATIO) {
            // cache state before call
            vaultTokenBalancePre = bimaToken.balanceOf(address(bimaVault));
            receiverTokenBalancePre = bimaToken.balanceOf(mockBoostDelegateAddr);

            assertEq(bimaVault.claimableBoostDelegationFees(mockBoostDelegateAddr), expectedFeeAmount);

            vm.prank(mockBoostDelegateAddr);
            assertTrue(bimaVault.claimBoostDelegationFees(mockBoostDelegateAddr));

            // very stored pending fees were reset
            assertEq(bimaVault.getStoredPendingReward(mockBoostDelegateAddr), 0);

            // // verify tokens have been sent from vault to receiver
            assertEq(bimaToken.balanceOf(address(bimaVault)), vaultTokenBalancePre - expectedFeeAmount);
            assertEq(bimaToken.balanceOf(mockBoostDelegateAddr), receiverTokenBalancePre + expectedFeeAmount);
        }

        // disable boost delegate
        vm.prank(mockBoostDelegateAddr);
        assertTrue(bimaVault.setBoostDelegationParams(false, maxFeePct, mockBoostDelegateAddr));
        assertFalse(bimaVault.isBoostDelegatedEnabled(mockBoostDelegateAddr));
    }

    function test_allocateNewEmissions_oneReceiverWithVotingWeight() public {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY / 2, true);

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
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());

        // one receiver as all the voting weight
        assertEq(incentiveVoting.getReceiverWeight(RECEIVER_ID), incentiveVoting.getTotalWeight());
        assertEq(incentiveVoting.getReceiverVotePct(RECEIVER_ID, systemWeek + 1), 1e18);

        // initial unallocated supply has not changed
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated);

        // receiver calls allocateNewEmissions
        vm.prank(receiver);
        uint256 allocated = bimaVault.allocateNewEmissions(RECEIVER_ID);

        // verify BimaVault::totalUpdateWeek current system week
        assertEq(bimaVault.totalUpdateWeek(), systemWeek);

        // verify unallocated supply reduced by weekly emission percent
        uint256 firstWeekEmissions = (initialUnallocated * INIT_ES_WEEKLY_PCT) / BIMA_100_PCT;
        assertTrue(firstWeekEmissions > 0);
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated - firstWeekEmissions);

        // verify emissions correctly set for current week
        assertEq(bimaVault.weeklyEmissions(systemWeek), firstWeekEmissions);

        // verify BimaVault::lockWeeks reduced correctly
        assertEq(bimaVault.lockWeeks(), INIT_ES_LOCK_WEEKS - INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver active and last processed week = system week
        (, bool isActive, uint16 updatedWeek) = bimaVault.idToReceiver(RECEIVER_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // verify receiver was allocated the first week's emissions
        assertEq(allocated, firstWeekEmissions);
        assertEq(bimaVault.allocated(receiver), firstWeekEmissions);

        // receiver calls allocateNewEmissions again
        vm.prank(receiver);
        uint256 allocated2 = bimaVault.allocateNewEmissions(RECEIVER_ID);

        // doesn't return any more since already been called for current system week
        assertEq(allocated2, 0);
        assertEq(bimaVault.allocated(receiver), firstWeekEmissions);

        // re-register account weight
        vm.prank(users.user1);
        incentiveVoting.registerAccountWeight(users.user1, 51);

        // verify votes preserved
        IIncentiveVoting.Vote[] memory votes2 = incentiveVoting.getAccountCurrentVotes(users.user1);
        assertEq(votes2.length, votes.length);
        assertEq(votes2[0].id, votes[0].id);
        assertEq(votes2[0].points, votes[0].points);

        // change vote weight
        votes[0].points /= 2;
        vm.prank(users.user1);

        // register weight and vote again
        incentiveVoting.registerAccountWeightAndVote(users.user1, 51, votes);

        // verify previous vote cleared and new vote saved
        votes2 = incentiveVoting.getAccountCurrentVotes(users.user1);
        assertEq(votes2.length, votes.length);
        assertEq(votes2[0].id, votes[0].id);
        assertEq(votes2[0].points, votes[0].points);

        // change vote weight back to original
        votes[0].points = incentiveVoting.MAX_POINTS();

        // vote with clear previous to delete old vote
        vm.prank(users.user1);
        incentiveVoting.vote(users.user1, votes, true);

        // verify new vote
        votes2 = incentiveVoting.getAccountCurrentVotes(users.user1);
        assertEq(votes2.length, votes.length);
        assertEq(votes2[0].id, votes[0].id);
        assertEq(votes2[0].points, votes[0].points);
    }

    function test_clearRegisteredWeight() external {
        test_allocateNewEmissions_oneReceiverWithVotingWeight();

        vm.prank(users.user1);
        incentiveVoting.clearRegisteredWeight(users.user1);

        IIncentiveVoting.Vote[] memory votes = incentiveVoting.getAccountCurrentVotes(users.user1);
        assertEq(votes.length, 0);
    }

    function test_allocateNewEmissions_oneDisabledReceiverWithVotingWeight() external {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY / 2, true);

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
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());

        // initial unallocated supply has not changed
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated);

        // disable emission receiver prior to calling allocateNewEmissions
        vm.prank(users.owner);
        bimaVault.setReceiverIsActive(RECEIVER_ID, false);

        // receiver calls allocateNewEmissions
        vm.prank(receiver);
        uint256 allocated = bimaVault.allocateNewEmissions(RECEIVER_ID);

        // verify BimaVault::totalUpdateWeek current system week
        assertEq(bimaVault.totalUpdateWeek(), systemWeek);

        // verify unallocated supply remained the same; this happens because
        // 1) BimaVault::_allocateTotalWeekly decreases total unallocated by
        //    the weekly emission amount
        // 2) BimaVault::allocateNewEmissions increases total unallocated by
        //    the amount disabled receivers would have received if enabled; in
        //    this case only 1 receiver so entire emissions get credited back
        //    to unallocated supply
        uint256 firstWeekEmissions = (initialUnallocated * INIT_ES_WEEKLY_PCT) / BIMA_100_PCT;
        assertTrue(firstWeekEmissions > 0);
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated);

        // verify emissions correctly set for current week
        assertEq(bimaVault.weeklyEmissions(systemWeek), firstWeekEmissions);

        // verify BimaVault::lockWeeks reduced correctly
        assertEq(bimaVault.lockWeeks(), INIT_ES_LOCK_WEEKS - INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver disabled and last processed week = system week
        (, bool isActive, uint16 updatedWeek) = bimaVault.idToReceiver(RECEIVER_ID);
        assertEq(isActive, false);
        assertEq(updatedWeek, systemWeek);

        // verify receiver was allocated zero as they were disabled
        assertEq(allocated, 0);
        assertEq(bimaVault.allocated(receiver), 0);
    }

    function test_allocateNewEmissions_twoReceiversWithEqualVotingWeight() external {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY / 2, true);

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
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());

        // initial unallocated supply has not changed
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated);

        // receiver calls allocateNewEmissions
        vm.prank(receiver);
        uint256 allocated = bimaVault.allocateNewEmissions(RECEIVER_ID);

        // verify BimaVault::totalUpdateWeek current system week
        assertEq(bimaVault.totalUpdateWeek(), systemWeek);

        // verify unallocated supply reduced by weekly emission percent
        uint256 firstWeekEmissions = (initialUnallocated * INIT_ES_WEEKLY_PCT) / BIMA_100_PCT;
        assertTrue(firstWeekEmissions > 0);
        uint256 remainingUnallocated = initialUnallocated - firstWeekEmissions;
        assertEq(bimaVault.unallocatedTotal(), remainingUnallocated);

        // verify emissions correctly set for current week
        assertEq(bimaVault.weeklyEmissions(systemWeek), firstWeekEmissions);

        // verify BimaVault::lockWeeks reduced correctly
        assertEq(bimaVault.lockWeeks(), INIT_ES_LOCK_WEEKS - INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver active and last processed week = system week
        (, bool isActive, uint16 updatedWeek) = bimaVault.idToReceiver(RECEIVER_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // verify receiver was allocated half of first week's emissions
        assertEq(allocated, firstWeekEmissions / 2);
        assertEq(bimaVault.allocated(receiver), firstWeekEmissions / 2);

        // receiver2 calls allocateNewEmissions
        vm.prank(receiver2);
        allocated = bimaVault.allocateNewEmissions(RECEIVER2_ID);

        // verify most things remain the same
        assertEq(bimaVault.totalUpdateWeek(), systemWeek);
        assertEq(bimaVault.unallocatedTotal(), remainingUnallocated);
        assertEq(bimaVault.weeklyEmissions(systemWeek), firstWeekEmissions);
        assertEq(bimaVault.lockWeeks(), INIT_ES_LOCK_WEEKS - INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver2 active and last processed week = system week
        (, isActive, updatedWeek) = bimaVault.idToReceiver(RECEIVER2_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // verify receiver2 was allocated half of first week's emissions
        assertEq(allocated, firstWeekEmissions / 2);
        assertEq(bimaVault.allocated(receiver2), firstWeekEmissions / 2);
    }

    function test_allocateNewEmissions_twoReceiversWithUnequalExtremeVotingWeight() external {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY / 2, true);

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
        votes[1].points = incentiveVoting.MAX_POINTS() - 1;

        vm.prank(users.user1);
        incentiveVoting.registerAccountWeightAndVote(users.user1, 52, votes);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // cache state prior to allocateNewEmissions
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());

        // initial unallocated supply has not changed
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated);

        // receiver calls allocateNewEmissions
        vm.prank(receiver);
        uint256 allocated = bimaVault.allocateNewEmissions(RECEIVER_ID);

        // verify BimaVault::totalUpdateWeek current system week
        assertEq(bimaVault.totalUpdateWeek(), systemWeek);

        // verify unallocated supply reduced by weekly emission percent
        uint256 firstWeekEmissions = (initialUnallocated * INIT_ES_WEEKLY_PCT) / BIMA_100_PCT;
        assertTrue(firstWeekEmissions > 0);
        uint256 remainingUnallocated = initialUnallocated - firstWeekEmissions;
        assertEq(bimaVault.unallocatedTotal(), remainingUnallocated);

        // verify emissions correctly set for current week
        assertEq(bimaVault.weeklyEmissions(systemWeek), firstWeekEmissions);

        // verify BimaVault::lockWeeks reduced correctly
        assertEq(bimaVault.lockWeeks(), INIT_ES_LOCK_WEEKS - INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver active and last processed week = system week
        (, bool isActive, uint16 updatedWeek) = bimaVault.idToReceiver(RECEIVER_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // receiver2 calls allocateNewEmissions
        vm.prank(receiver2);
        uint256 allocated2 = bimaVault.allocateNewEmissions(RECEIVER2_ID);

        // verify most things remain the same
        assertEq(bimaVault.totalUpdateWeek(), systemWeek);
        assertEq(bimaVault.unallocatedTotal(), remainingUnallocated);
        assertEq(bimaVault.weeklyEmissions(systemWeek), firstWeekEmissions);
        assertEq(bimaVault.lockWeeks(), INIT_ES_LOCK_WEEKS - INIT_ES_LOCK_DECAY_WEEKS);

        // verify receiver2 active and last processed week = system week
        (, isActive, updatedWeek) = bimaVault.idToReceiver(RECEIVER2_ID);
        assertEq(isActive, true);
        assertEq(updatedWeek, systemWeek);

        // due to rounding a small amount of tokens is lost as the recorded
        // weekly emission is greater than the actual amounts allocated
        // to the two receivers
        assertEq(firstWeekEmissions, 536870911875000000000000000);
        assertEq(allocated + allocated2, 536870911874999999999999999);

        assertEq(allocated, 53687000037499936332460);
        assertEq(bimaVault.allocated(receiver), 53687000037499936332460);
        assertEq(allocated2, 536817224874962500063667539);
        assertEq(bimaVault.allocated(receiver2), 536817224874962500063667539);
    }

    function test_unfreeze_fixForFailToRemoveActiveVotes() external {
        // setup vault giving user1 half supply to lock for voting power
        _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY / 2, true);

        // verify user1 has 1 unfrozen lock
        (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount) = tokenLocker.getAccountActiveLocks(
            users.user1,
            0
        );
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

        (uint256 frozenWeight, ITokenLocker.LockData[] memory lockData) = incentiveVoting.getAccountRegisteredLocks(
            users.user1
        );
        assertEq(frozenWeight, 0);
        assertEq(lockData.length, activeLockData.length);
        assertEq(activeLockData[0].amount, lockData[0].amount);
        assertEq(activeLockData[0].weeksToUnlock, lockData[0].weeksToUnlock);

        // verify user1 has 1 active vote using their unfrozen locked weight
        votes = incentiveVoting.getAccountCurrentVotes(users.user1);
        assertEq(votes.length, 1);
        assertEq(votes[0].id, RECEIVER_ID);
        assertEq(votes[0].points, incentiveVoting.MAX_POINTS());

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

    function test_freeze_vote_unfreeze(bool keepIncentivesVote) external {
        // setup vault giving user1 half supply to lock for voting power
        _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY / 2, true);

        // user1 freezes their lock
        vm.prank(users.user1);
        tokenLocker.freeze();

        // register receiver
        uint256 RECEIVER_ID = _vaultRegisterReceiver(address(mockEmissionReceiver), 1);

        // user1 votes for receiver using their frozen locked weight
        IIncentiveVoting.Vote[] memory votes = new IIncentiveVoting.Vote[](1);
        votes[0].id = RECEIVER_ID;
        votes[0].points = incentiveVoting.MAX_POINTS();

        vm.prank(users.user1);
        incentiveVoting.registerAccountWeightAndVote(users.user1, 52, votes);

        // verify user1 has 1 frozen lock
        (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount) = tokenLocker.getAccountActiveLocks(
            users.user1,
            0
        );
        assertEq(activeLockData.length, 0); // 0 active lock
        assertGt(frozenAmount, 0); // positive frozen amount

        // user1 unfreezes
        vm.prank(users.user1);
        tokenLocker.unfreeze(keepIncentivesVote);

        // refresh votes after unfreeze
        votes = incentiveVoting.getAccountCurrentVotes(users.user1);

        if (keepIncentivesVote) {
            assertEq(votes.length, 1);
            assertEq(votes[0].id, RECEIVER_ID);
            assertEq(votes[0].points, incentiveVoting.MAX_POINTS());
        } else {
            assertEq(votes.length, 0);
        }
    }

    function test_freeze_vote_removeVotes() external {
        // setup vault giving user1 half supply to lock for voting power
        _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY / 2, true);

        // user1 freezes their lock
        vm.prank(users.user1);
        tokenLocker.freeze();

        // register receiver
        uint256 RECEIVER_ID = _vaultRegisterReceiver(address(mockEmissionReceiver), 1);

        // user1 votes for receiver using their frozen locked weight
        IIncentiveVoting.Vote[] memory votes = new IIncentiveVoting.Vote[](1);
        votes[0].id = RECEIVER_ID;
        votes[0].points = incentiveVoting.MAX_POINTS();

        vm.prank(users.user1);
        incentiveVoting.registerAccountWeightAndVote(users.user1, 52, votes);

        // verify user1 has 1 frozen lock
        (ITokenLocker.LockData[] memory activeLockData, uint256 frozenAmount) = tokenLocker.getAccountActiveLocks(
            users.user1,
            0
        );
        assertEq(activeLockData.length, 0); // 0 active lock
        assertGt(frozenAmount, 0); // positive frozen amount

        // user1 clears their votes while still frozen
        vm.prank(users.user1);
        incentiveVoting.clearVote(users.user1);

        // refresh votes after clear
        votes = incentiveVoting.getAccountCurrentVotes(users.user1);
        assertEq(votes.length, 0);
    }

    function test_allocateNewEmissions_fixForTokensLostAfterDisablingReceiver()
        public
        returns (uint256 disabledReceiverId)
    {
        // setup vault giving user1 half supply to lock for voting power
        uint256 initialUnallocated = _vaultSetupAndLockTokens(INIT_BAB_TKN_TOTAL_SUPPLY / 2, true);

        // receiver to be disabled later
        address receiver1 = address(mockEmissionReceiver);
        uint256 RECEIVER_ID1 = _vaultRegisterReceiver(receiver1, 1);
        disabledReceiverId = RECEIVER_ID1;

        // ongoing receiver
        MockEmissionReceiver mockEmissionReceiver2 = new MockEmissionReceiver();
        address receiver2 = address(mockEmissionReceiver2);
        uint256 RECEIVER_ID2 = _vaultRegisterReceiver(receiver2, 1);

        // user votes for receiver1 to get emissions with 50% of their points
        IIncentiveVoting.Vote[] memory votes = new IIncentiveVoting.Vote[](1);
        votes[0].id = RECEIVER_ID1;
        votes[0].points = incentiveVoting.MAX_POINTS() / 2;
        vm.prank(users.user1);
        incentiveVoting.registerAccountWeightAndVote(users.user1, 52, votes);

        // user votes for receiver2 to get emissions with 50% of their points
        votes[0].id = RECEIVER_ID2;
        vm.prank(users.user1);
        incentiveVoting.vote(users.user1, votes, false);

        // verify only receiver can call allocateNewEmissions when active
        vm.expectRevert("Not receiver account");
        bimaVault.allocateNewEmissions(RECEIVER_ID1);

        // disable emission receiver 1 prior to calling allocateNewEmissions
        vm.prank(users.owner);
        bimaVault.setReceiverIsActive(RECEIVER_ID1, false);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // cache current system week
        uint16 systemWeek = SafeCast.toUint16(bimaVault.getWeek());

        // initial unallocated supply has not changed
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated);

        // receiver2 calls allocateNewEmissions
        vm.prank(receiver2);
        uint256 allocatedToEachReceiver = bimaVault.allocateNewEmissions(RECEIVER_ID2);

        // verify BimaVault::totalUpdateWeek is current system week
        assertEq(bimaVault.totalUpdateWeek(), systemWeek);

        // verify receiver1 and receiver2 have the same allocated amounts
        uint256 firstWeekEmissions = (initialUnallocated * INIT_ES_WEEKLY_PCT) / BIMA_100_PCT;
        assertTrue(firstWeekEmissions > 0);
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated - firstWeekEmissions);
        assertEq(firstWeekEmissions, allocatedToEachReceiver * 2);

        // if receiver1 doesn't call allocateNewEmissions the tokens they would
        // have received would never be allocated. Only if receiver1 calls allocateNewEmissions
        // do the tokens move into BimaVault::unallocatedTotal
        //
        // the fix allows anyone to call `allocateNewEmissions` for disabled receivers
        // to trigger the tokens the disabled receiver would have received to be
        // credit to BimaVault::unallocatedTotal
        bimaVault.allocateNewEmissions(RECEIVER_ID1);
        assertEq(bimaVault.unallocatedTotal(), initialUnallocated - firstWeekEmissions + allocatedToEachReceiver);
    }

    function test_allocateNewEmissions_failVoteForDisabledReceiver() public {
        // perform the previous test to set everything up
        uint256 disabledReceiverId = test_allocateNewEmissions_fixForTokensLostAfterDisablingReceiver();

        // users can remove their votes for disabled receivers
        vm.prank(users.user1);
        incentiveVoting.clearVote(users.user1);

        // attempting to vote for disabled receiver1 fails
        IIncentiveVoting.Vote[] memory votes = new IIncentiveVoting.Vote[](1);
        votes[0].id = disabledReceiverId;
        votes[0].points = incentiveVoting.MAX_POINTS() / 2;
        vm.expectRevert("Can't vote for disabled receivers - clearVote first");
        vm.prank(users.user1);
        incentiveVoting.vote(users.user1, votes, false);
    }

    function test_setEmissionSchedule_failNotOwner() external {
        vm.expectRevert("Only owner");
        bimaVault.setEmissionSchedule(IEmissionSchedule(address(0)));
    }

    function test_setEmissionSchedule() external {
        uint64[2][] memory scheduledWeeklyPct;
        EmissionSchedule newEmissionSchedule = new EmissionSchedule(
            address(bimaCore),
            incentiveVoting,
            bimaVault,
            INIT_ES_LOCK_WEEKS,
            INIT_ES_LOCK_DECAY_WEEKS,
            INIT_ES_WEEKLY_PCT,
            scheduledWeeklyPct
        );

        // fast forward time to trigger additional processing
        // inside _allocateTotalWeekly
        vm.warp(block.timestamp + 4 weeks);

        vm.prank(users.owner);
        assertTrue(bimaVault.setEmissionSchedule(newEmissionSchedule));

        assertEq(address(bimaVault.emissionSchedule()), address(newEmissionSchedule));
    }

    function test_setBoostCalculator_failNotOwner() external {
        vm.expectRevert("Only owner");
        bimaVault.setBoostCalculator(IBoostCalculator(address(0)));
    }

    function test_setBoostCalculator() external {
        vm.prank(users.owner);
        assertTrue(bimaVault.setBoostCalculator(IBoostCalculator(address(0x123456))));
        assertEq(address(bimaVault.boostCalculator()), address(0x123456));
    }

    function test_increaseUnallocatedSupply(uint256 amount) external {
        uint256 user1Supply = INIT_BAB_TKN_TOTAL_SUPPLY / 2;

        // setup vault giving user1 half supply but no locking
        _vaultSetupAndLockTokens(user1Supply, false);

        // bound fuzz inputs
        amount = bound(amount, 0, user1Supply);

        vm.prank(users.user1);
        bimaToken.approve(address(bimaVault), amount);

        // save previous state
        uint256 initialUnallocated = bimaVault.unallocatedTotal();
        uint256 initialBimaBalance = bimaToken.balanceOf(address(bimaVault));
        uint256 initialUserBalance = bimaToken.balanceOf(users.user1);

        vm.prank(users.user1);
        assertTrue(bimaVault.increaseUnallocatedSupply(amount));

        assertEq(bimaVault.unallocatedTotal(), initialUnallocated + amount);
        assertEq(bimaToken.balanceOf(address(bimaVault)), initialBimaBalance + amount);
        assertEq(bimaToken.balanceOf(users.user1), initialUserBalance - amount);
    }
}
