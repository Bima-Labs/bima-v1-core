// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IBabelVault, BabelVault, IIncentiveVoting, ITokenLocker} from "../TestSetup.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockEmissionReceiver {
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

    function test_transferTokens(address receiver, uint256 amount) public {
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

    function test_transferTokens_revert(address receiver, uint256 amount) public {
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

    /* todo - failing with out of gas
    function test_registerReceiver(address receiver, uint256 count, uint256 weeksToAdd) public {
        // bound fuzz inputs
        vm.assume(receiver != address(0) && receiver != address(babelVault));
        vm.assume(uint160(receiver) > 9); // Exclude precompile addresses (0x1 to 0x9)
        count = bound(count, 1, MAX_COUNT); // Limit count to avoid excessive gas usage or memory issues
        weeksToAdd = bound(weeksToAdd, 0, type(uint64).max - 1);
        vm.assume(weeksToAdd <= type(uint64).max - 1);

        // Set up week
        vm.warp(block.timestamp + weeksToAdd * 1 weeks);
        uint256 currentWeek = babelVault.getWeek();

        // Mock the IEmissionReceiver interface
        MockEmissionReceiver mockReceiver = new MockEmissionReceiver();
        vm.etch(receiver, address(mockReceiver).code);

        // Have owner register receiver
        vm.prank(users.owner);
        assertTrue(babelVault.registerReceiver(receiver, count));

        for (uint256 i = 1; i <= count; i++) {
            (address registeredReceiver, bool isActive) = babelVault.idToReceiver(i);
            assertEq(registeredReceiver, receiver);
            assertTrue(isActive);
            assertEq(babelVault.receiverUpdatedWeek(i), uint16(currentWeek));
        }

        // Verify IncentiveVoting state
        assertEq(incentiveVoting.receiverCount(), count + 1); // +1 because of the initial StabilityPool receiver

        // Verify MockEmissionReceiver state
        MockEmissionReceiver(receiver).assertNotifyRegisteredIdCalled(count);
    }
    */

    function test_registerReceiver_zeroCount() public {
        vm.prank(users.owner);
        vm.expectRevert();
        babelVault.registerReceiver(address(1), 0);
    }

    function test_registerReceiver_revert_zeroAddress() public {
        vm.prank(users.owner);
        vm.expectRevert();
        babelVault.registerReceiver(address(0), 1);
    }

    function test_registerReceiver_revert_babelVault() public {
        vm.prank(users.owner);
        vm.expectRevert();
        babelVault.registerReceiver(address(babelVault), 1);
    }

    function test_registerReceiver_revert_nonOwner() public {
        vm.prank(users.user1);
        vm.expectRevert();
        babelVault.registerReceiver(address(1), 1);
    }

    /* todo
    function test_allocateNewEmissions(address receiver, uint256 count, uint256 weeksToAdd) public {
        // bound fuzz inputs
        vm.assume(receiver != address(0) && receiver != address(babelVault));
        vm.assume(uint160(receiver) > 9); // Exclude precompile addresses (0x1 to 0x9)
        count = bound(count, 1, 100); // Limit count to avoid excessive gas usage or memory issues
        weeksToAdd = bound(weeksToAdd, 0, type(uint64).max - 1);
        vm.assume(weeksToAdd <= type(uint64).max - 1);

        // Set up week
        vm.warp(block.timestamp + weeksToAdd * 1 weeks);

        // Mock the IEmissionReceiver interface
        MockEmissionReceiver mockReceiver = new MockEmissionReceiver();
        vm.etch(receiver, address(mockReceiver).code);

        // Have owner register receiver
        vm.prank(users.owner);
        assertTrue(babelVault.registerReceiver(receiver, count));

        // Simulate time passing some more
        vm.warp(block.timestamp + weeksToAdd * 1 weeks);

        uint256 initialUnallocated = babelVault.unallocatedTotal();

        // Call allocateNewEmissions
        uint256 id = 1;
        vm.prank(receiver);
        uint256 allocated = babelVault.allocateNewEmissions(id);

        // Calculate expected unallocated total
        uint256 expectedUnallocated = initialUnallocated;
        (, bool isActive) = babelVault.idToReceiver(id);
        if (!isActive) {
            // If receiver is inactive, unallocated total should remain the same as after _allocateTotalWeekly
            expectedUnallocated = babelVault.unallocatedTotal();
        }

        // Assertions
        assertEq(babelVault.unallocatedTotal(), expectedUnallocated, "Unallocated total not updated correctly");
        assertEq(allocated, 0, "Incorrect amount allocated");
        assertEq(babelVault.allocated(receiver), 0, "Allocated amount should be 0 for inactive receiver");
        //assertEq(babelVault.receiverUpdatedWeek(id), babelVault.getWeek(), "Receiver week not updated correctly");
    }
    */
}