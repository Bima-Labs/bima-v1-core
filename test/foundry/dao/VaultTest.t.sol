// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IBabelVault, BabelVault, IIncentiveVoting, ITokenLocker} from "../TestSetup.sol";
import {IEmissionReceiver} from "../../../contracts/dao/Vault.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract MockEmissionReceiver is IEmissionReceiver {
    bool public notifyRegisteredIdCalled;
    uint256[] public lastAssignedIds;

    function notifyRegisteredId(uint256[] calldata assignedIds) external returns (bool success) {
        notifyRegisteredIdCalled = true;
        lastAssignedIds = assignedIds;
        success = true;
    }

    /**
     * @notice Asserts that notifyRegisteredId was called with the expected number of assigned IDs
     * @dev Added this for testing purposes
     * @param expectedCount The expected number of assigned IDs
     */
    function assertNotifyRegisteredIdCalled(uint256 expectedCount) external view {
        require(notifyRegisteredIdCalled, "notifyRegisteredId was not called");
        require(lastAssignedIds.length == expectedCount, "Unexpected number of assigned IDs");
    }
}


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
        uint16 currentWeek = SafeCast.toUint16(babelVault.getWeek());

        // Have owner register receiver
        vm.prank(users.owner);
        assertTrue(babelVault.registerReceiver(address(mockEmissionReceiver), count));

        // start at 1 because 0 is always stability pool
        for (uint256 i = 1; i <= count; i++) {
            (address registeredReceiver, bool isActive, uint16 updatedWeek) = babelVault.idToReceiver(i);
            assertEq(registeredReceiver, address(mockEmissionReceiver));
            assertTrue(isActive);
            assertEq(updatedWeek, currentWeek);

            assertEq(incentiveVoting.receiverUpdatedWeek(i), currentWeek);
        }

        // Verify IncentiveVoting state
        assertEq(incentiveVoting.receiverCount(), count + 1); // +1 because of the initial StabilityPool receiver

        // Verify MockEmissionReceiver state
        mockEmissionReceiver.assertNotifyRegisteredIdCalled(count);
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
        vm.prank(users.owner);
        assertTrue(babelVault.registerReceiver(receiver, 1));

        // warp time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        // cache state prior to allocateNewEmissions
        uint256 RECEIVER_ID = 1;
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
        // but no tokens were not actually allocated to receivers since there was no
        // voting weight
    }
}