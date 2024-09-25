// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup} from "../TestSetup.sol";

contract BabelCoreTest is TestSetup {

    function test_setPaused_guardianCanPauseNotUnpause() external {
        vm.prank(users.guardian);
        babelCore.setPaused(true);

        assertTrue(babelCore.paused());

        vm.expectRevert("Unauthorized");
        vm.prank(users.guardian);
        babelCore.setPaused(false);
    }

    function test_setPaused_ownerCanPauseUnpause() external {
        vm.prank(users.owner);
        babelCore.setPaused(true);

        assertTrue(babelCore.paused());

        vm.prank(users.owner);
        babelCore.setPaused(false);

        assertFalse(babelCore.paused());
    }

    function test_setPaused_failNormalUser() external {
        vm.expectRevert("Unauthorized");
        vm.prank(users.user1);
        babelCore.setPaused(true);

        vm.expectRevert("Unauthorized");
        vm.prank(users.user1);
        babelCore.setPaused(false);
    }

    function test_setFeeReceiver_failsNotOwner() external {
        vm.expectRevert("Only owner");
        babelCore.setFeeReceiver(address(0));
    }

    function test_setFeeReceiver() external {
        vm.prank(users.owner);
        babelCore.setFeeReceiver(address(0));
        assertEq(babelCore.feeReceiver(), address(0));
    }

    function test_setPriceFeed_failsNotOwner() external {
        vm.expectRevert("Only owner");
        babelCore.setPriceFeed(address(0));
    }

    function test_setPriceFeed() external {
        vm.prank(users.owner);
        babelCore.setPriceFeed(address(0));
        assertEq(babelCore.priceFeed(), address(0));
    }

    function test_setGuardian_failsNotOwner() external {
        vm.expectRevert("Only owner");
        babelCore.setGuardian(address(0));
    }

    function test_setGuardian() external {
        vm.prank(users.owner);
        babelCore.setGuardian(address(0));
        assertEq(babelCore.guardian(), address(0));
    }

    function test_commitTransferOwnership_failsNotOwner() external {
        vm.expectRevert("Only owner");
        babelCore.commitTransferOwnership(address(0));
    }

    function test_commitTransferOwnership() public returns(address newPendingOwner) {
        newPendingOwner = address(0x9876);
        vm.prank(users.owner);
        babelCore.commitTransferOwnership(newPendingOwner);

        assertEq(babelCore.pendingOwner(), newPendingOwner);
        assertEq(babelCore.ownershipTransferDeadline(), block.timestamp + babelCore.OWNERSHIP_TRANSFER_DELAY());
    }

    function test_acceptTransferOwnership_failsNotNewPendingOwner() external {
        address newPendingOwner = test_commitTransferOwnership();

        vm.expectRevert("Only new owner");
        babelCore.acceptTransferOwnership();
    }

    function test_acceptTransferOwnership_failsTransferDeadlineNotElapsed() external {
        address newPendingOwner = test_commitTransferOwnership();

        vm.expectRevert("Deadline not passed");
        vm.prank(newPendingOwner);
        babelCore.acceptTransferOwnership();
    }

    function test_acceptTransferOwnership() external {
        address newPendingOwner = test_commitTransferOwnership();

        vm.warp(babelCore.ownershipTransferDeadline());

        vm.prank(newPendingOwner);
        babelCore.acceptTransferOwnership();

        assertEq(babelCore.owner(), newPendingOwner);
        assertEq(babelCore.pendingOwner(), address(0));
        assertEq(babelCore.ownershipTransferDeadline(), 0);
    }

    function test_revokeTransferOwnership_failsNotOwner() external {
        vm.expectRevert("Only owner");
        babelCore.revokeTransferOwnership();
    }

    function test_revokeTransferOwnership() external {
        address newPendingOwner = test_commitTransferOwnership();

        vm.prank(users.owner);
        babelCore.revokeTransferOwnership();

        assertEq(babelCore.owner(), users.owner);
        assertEq(babelCore.pendingOwner(), address(0));
        assertEq(babelCore.ownershipTransferDeadline(), 0);
    }
}
