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
}