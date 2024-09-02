// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IBabelVault, BabelVault, IIncentiveVoting, ITokenLocker, IEmissionReceiver, MockEmissionReceiver, SafeCast} from "../TestSetup.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VaultTest is TestSetup {

    uint256 constant internal MAX_COUNT = 10;

    MockEmissionReceiver internal mockEmissionReceiver;
    
    function setUp() public virtual override {
        super.setUp();

        mockEmissionReceiver = new MockEmissionReceiver();
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
        _vaultRegisterReceiver(address(mockEmissionReceiver), count);
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

        // owner registers receiver
        address receiver = address(mockEmissionReceiver);

        // helper registers receivers and performs all necessary checks
        uint256 RECEIVER_ID = _vaultRegisterReceiver(receiver, 1);

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // cache state prior to allocateNewEmissions
        uint16 systemWeek = SafeCast.toUint16(babelVault.getWeek());
        
        // entire supply still not allocated
        uint256 initialUnallocated = babelVault.unallocatedTotal();
        assertEq(initialUnallocated, INIT_BAB_TKN_TOTAL_SUPPLY);

        // receiver calls allocateNewEmissions
        vm.prank(receiver);
        uint256 allocated = babelVault.allocateNewEmissions(RECEIVER_ID);

        // verify BabelVault::totalUpdateWeek current system week
        assertEq(babelVault.totalUpdateWeek(), systemWeek);

        // verify unallocated supply reduced by weekly emission percent
        uint256 firstWeekEmissions = INIT_BAB_TKN_TOTAL_SUPPLY*INIT_ES_WEEKLY_PCT/MAX_PCT;
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
        uint256 firstWeekEmissions = initialUnallocated*INIT_ES_WEEKLY_PCT/MAX_PCT;
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
    }

    function test_allocateNewEmissions_twoReceiversWithVotingWeight() public {
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
        uint256 firstWeekEmissions = initialUnallocated*INIT_ES_WEEKLY_PCT/MAX_PCT;
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
    }


}