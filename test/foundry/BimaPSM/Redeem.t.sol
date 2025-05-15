// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {PSMTestSetup} from "./PSMTestSetup.t.sol";
import {IBimaPSM} from "../../../../contracts/interfaces/IBimaPSM.sol";

contract RedeemTest is PSMTestSetup {
    event Redeem(
        address indexed from,
        address indexed to,
        uint256 underlyingAmount,
        uint256 usbdAmount,
        uint256 timestamp
    );

    function testFuzz_redeem(address _to, uint256 _underlyingAmount) external {
        vm.assume(_to != address(0) && _to != address(debtToken) && _to != address(psm));
        _underlyingAmount = bound(_underlyingAmount, 0, psm.getUnderlyingLiquidity());

        uint256 usbdAmount = _underlyingAmount * 10 ** (18 - underlyingDecimals);

        vm.prank(users.owner);
        debtToken.authorizedMint(user1, usbdAmount);

        vm.startPrank(user1);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity);
        assertEq(debtToken.balanceOf(user1), usbdAmount);
        if (_to == user1) assertEq(debtToken.balanceOf(_to), usbdAmount);
        if (_to != user1) assertEq(debtToken.balanceOf(_to), 0);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity);
        assertEq(underlying.balanceOf(user1), 0);
        assertEq(underlying.balanceOf(_to), 0);

        debtToken.approve(address(psm), usbdAmount);

        vm.expectEmit(true, true, false, true);
        emit Redeem(user1, _to, _underlyingAmount, usbdAmount, block.timestamp);
        psm.redeem(_to, _underlyingAmount);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity + usbdAmount);
        assertEq(debtToken.balanceOf(user1), 0);
        assertEq(debtToken.balanceOf(_to), 0);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity - _underlyingAmount);
        assertEq(underlying.balanceOf(_to), _underlyingAmount);
        if (_to == user1) assertEq(underlying.balanceOf(user1), _underlyingAmount);
        if (_to != user1) assertEq(underlying.balanceOf(user1), 0);
    }

    function testFuzz_redeem_notEnoughLiquidity(address _to, uint8 _delta) external {
        vm.assume(_to != address(0) && _to != address(debtToken) && _to != address(psm));
        vm.assume(_delta > 0);

        uint256 underlyingAmount = psm.getUnderlyingLiquidity() + _delta;

        uint256 usbdAmount = underlyingAmount * 10 ** (18 - underlyingDecimals);

        vm.prank(users.owner);
        debtToken.authorizedMint(user1, usbdAmount);

        vm.startPrank(user1);

        debtToken.approve(address(psm), usbdAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IBimaPSM.NotEnoughLiquidity.selector,
                address(underlying),
                psm.getUnderlyingLiquidity(),
                underlyingAmount
            )
        );
        psm.redeem(_to, underlyingAmount);
    }

    function test_redeem() external {
        uint256 usbdAmount = 10_000e18;

        vm.prank(users.owner);
        debtToken.authorizedMint(user1, usbdAmount);

        vm.startPrank(user1);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity);
        assertEq(debtToken.balanceOf(user1), usbdAmount);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity);
        assertEq(underlying.balanceOf(user1), 0);

        uint256 underlyingAmount = usbdAmount / 10 ** (18 - underlyingDecimals);

        debtToken.approve(address(psm), usbdAmount);

        vm.expectEmit(true, true, false, true);
        emit Redeem(user1, user1, underlyingAmount, usbdAmount, block.timestamp);
        psm.redeem(user1, underlyingAmount);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity + usbdAmount);
        assertEq(debtToken.balanceOf(user1), 0);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity - underlyingAmount);
        assertEq(underlying.balanceOf(user1), underlyingAmount);
    }

    function test_redeem_zero() external {
        uint256 initialUsbdAmount = 1_000e18;
        vm.prank(users.owner);
        debtToken.authorizedMint(user1, initialUsbdAmount);

        vm.startPrank(user1);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity);
        assertEq(debtToken.balanceOf(user1), initialUsbdAmount);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity);
        assertEq(underlying.balanceOf(user1), 0);

        debtToken.approve(address(psm), 0);

        psm.redeem(user1, 0);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity);
        assertEq(debtToken.balanceOf(user1), initialUsbdAmount);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity);
        assertEq(underlying.balanceOf(user1), 0);
    }
}
