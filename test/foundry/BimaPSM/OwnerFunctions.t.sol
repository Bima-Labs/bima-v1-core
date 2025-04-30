// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {PSMTestSetup} from "./PSMTestSetup.t.sol";

contract OwnerFunctionsTest is PSMTestSetup {
    function test_removeLiquidity(uint256 _amount) public {
        _amount = bound(_amount, 0, psm.getUsbdLiquidity());

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity);
        assertEq(debtToken.balanceOf(users.owner), 0);

        vm.prank(users.owner);
        psm.removeLiquidity(_amount);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity - _amount);
        assertEq(debtToken.balanceOf(users.owner), _amount);
    }

    function test_removeLiquidity_unauthorized(address _user, uint256 _amount) public {
        vm.assume(_user != users.owner);

        vm.prank(_user);
        vm.expectRevert("Only owner");
        psm.removeLiquidity(_amount);
    }
}
