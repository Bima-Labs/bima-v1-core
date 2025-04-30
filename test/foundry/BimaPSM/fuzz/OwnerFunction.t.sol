// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {TestSetUpPSM} from "./TestSetUpPSM.sol";
import {console} from "forge-std/console.sol";

contract OwnerFunction is TestSetUpPSM {
    function setUp() public virtual override {
        super.setUp();
    }

    function testFuzz_RemoveLiquidity(uint256 amount) external  {
        amount = bound(amount,1,initialLiquidity);
        vm.startPrank(users.owner);
        psm.removeLiquidity(amount);
        uint256 usbdLeft = debtToken.balanceOf(address(psm));
        vm.stopPrank();

        assertEq(usbdLeft,initialLiquidity-amount);
    }

    function testFuzz_RemoveLiquidity_NonOwner(address user, uint256 amount) external  {
        vm.assume(user != users.owner);
        amount = bound(amount,1,initialLiquidity);
        vm.expectRevert();
        psm.removeLiquidity(amount);
    }

}
