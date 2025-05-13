// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {PSMTestSetup} from "./PSMTestSetup.t.sol";

contract ViewFunctionsTest is PSMTestSetup {
    function test_underlyingToUsbd(uint256 _underlyingAmount) public view {
        _underlyingAmount = bound(_underlyingAmount, 0, TRILLION_UNDERLYING);

        assertEq(psm.underlyingToUsbd(_underlyingAmount), _underlyingAmount * 10 ** (18 - underlyingDecimals));
    }

    function test_usbdToUnderlying(uint256 _usbdAmount) public view {
        assertEq(psm.usbdToUnderlying(_usbdAmount), _usbdAmount / 10 ** (18 - underlyingDecimals));
    }

    function test_getUsbdLiquidity(uint256 _extraUsbdAmount) public {
        _extraUsbdAmount = bound(_extraUsbdAmount, 0, initialUsbdLiquidity);

        assertEq(psm.getUsbdLiquidity(), debtToken.balanceOf(address(psm)));

        vm.prank(users.owner);
        debtToken.authorizedMint(address(psm), _extraUsbdAmount);

        assertEq(psm.getUsbdLiquidity(), debtToken.balanceOf(address(psm)));
    }

    function test_getUnderlyingLiquidity(uint256 _extraUnderlyingAmount) public {
        _extraUnderlyingAmount = bound(_extraUnderlyingAmount, 0, initialUnderlyingLiquidity);

        assertEq(psm.getUnderlyingLiquidity(), underlying.balanceOf(address(psm)));

        vm.prank(users.owner);
        underlying.mint(address(psm), _extraUnderlyingAmount);

        assertEq(psm.getUnderlyingLiquidity(), underlying.balanceOf(address(psm)));
    }
}
