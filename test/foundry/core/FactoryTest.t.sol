// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup} from "../TestSetup.sol";

contract FactoryTest is TestSetup {
    function test_setImplementations_failNotOwner() external {
        vm.expectRevert("Only owner");
        factory.setImplementations(address(0), address(0));
    }

    function test_setImplementations() external {
        vm.prank(users.owner);
        factory.setImplementations(address(0x1234), address(0x2345));

        assertEq(factory.troveManagerImpl(), address(0x1234));
        assertEq(factory.sortedTrovesImpl(), address(0x2345));
    }
}