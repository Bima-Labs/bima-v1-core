// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup} from "../TestSetup.sol";

contract BimaCoreTest is TestSetup {
    function test_setPaused_guardianCanPauseNotUnpause() external {
        vm.prank(users.guardian);
        bimaCore.setPaused(true);

        assertTrue(bimaCore.paused());

        vm.expectRevert("Unauthorized");
        vm.prank(users.guardian);
        bimaCore.setPaused(false);
    }

    function test_setPaused_ownerCanPauseUnpause() external {
        vm.prank(users.owner);
        bimaCore.setPaused(true);

        assertTrue(bimaCore.paused());

        vm.prank(users.owner);
        bimaCore.setPaused(false);

        assertFalse(bimaCore.paused());
    }

    function test_setPaused_failNormalUser() external {
        vm.expectRevert("Unauthorized");
        vm.prank(users.user1);
        bimaCore.setPaused(true);

        vm.expectRevert("Unauthorized");
        vm.prank(users.user1);
        bimaCore.setPaused(false);
    }

    function test_setFeeReceiver_failsNotOwner() external {
        vm.expectRevert("Only owner");
        bimaCore.setFeeReceiver(address(0));
    }

    function test_setFeeReceiver() external {
        vm.prank(users.owner);
        bimaCore.setFeeReceiver(address(0));
        assertEq(bimaCore.feeReceiver(), address(0));
    }

    function test_setPriceFeed_failsNotOwner() external {
        vm.expectRevert("Only owner");
        bimaCore.setPriceFeed(address(0));
    }

    function test_setPriceFeed() external {
        vm.prank(users.owner);
        bimaCore.setPriceFeed(address(0));
        assertEq(bimaCore.priceFeed(), address(0));
    }

    function test_setGuardian_failsNotOwner() external {
        vm.expectRevert("Only owner");
        bimaCore.setGuardian(address(0));
    }

    function test_setGuardian() external {
        vm.prank(users.owner);
        bimaCore.setGuardian(address(0));
        assertEq(bimaCore.guardian(), address(0));
    }

    function test_commitTransferOwnership_failsNotOwner() external {
        vm.expectRevert("Only owner");
        bimaCore.commitTransferOwnership(address(0));
    }

    function test_commitTransferOwnership() public returns (address newPendingOwner) {
        newPendingOwner = address(0x9876);
        vm.prank(users.owner);
        bimaCore.commitTransferOwnership(newPendingOwner);

        assertEq(bimaCore.pendingOwner(), newPendingOwner);
        assertEq(bimaCore.ownershipTransferDeadline(), block.timestamp + bimaCore.OWNERSHIP_TRANSFER_DELAY());
    }

    function test_acceptTransferOwnership_failsNotNewPendingOwner() external {
        test_commitTransferOwnership();

        vm.expectRevert("Only new owner");
        bimaCore.acceptTransferOwnership();
    }

    function test_acceptTransferOwnership_failsTransferDeadlineNotElapsed() external {
        address newPendingOwner = test_commitTransferOwnership();

        vm.expectRevert("Deadline not passed");
        vm.prank(newPendingOwner);
        bimaCore.acceptTransferOwnership();
    }

    function test_acceptTransferOwnership() external {
        address newPendingOwner = test_commitTransferOwnership();

        vm.warp(bimaCore.ownershipTransferDeadline());

        vm.prank(newPendingOwner);
        bimaCore.acceptTransferOwnership();

        assertEq(bimaCore.owner(), newPendingOwner);
        assertEq(bimaCore.pendingOwner(), address(0));
        assertEq(bimaCore.ownershipTransferDeadline(), 0);
    }

    function test_revokeTransferOwnership_failsNotOwner() external {
        vm.expectRevert("Only owner");
        bimaCore.revokeTransferOwnership();
    }

    function test_revokeTransferOwnership() external {
        test_commitTransferOwnership();

        vm.prank(users.owner);
        bimaCore.revokeTransferOwnership();

        assertEq(bimaCore.owner(), users.owner);
        assertEq(bimaCore.pendingOwner(), address(0));
        assertEq(bimaCore.ownershipTransferDeadline(), 0);
    }
}
