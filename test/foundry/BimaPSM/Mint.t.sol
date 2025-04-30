// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {PSMTestSetup} from "./PSMTestSetup.t.sol";
import {IBimaPSM} from "../../../../contracts/interfaces/IBimaPSM.sol";

contract MintTest is PSMTestSetup {
    event Mint(
        address indexed from,
        address indexed to,
        uint256 underlyingAmount,
        uint256 usbdAmount,
        uint256 timestamp
    );

    function testFuzz_mint(address _to, uint256 _underlyingAmount) external {
        vm.assume(_to != address(0) && _to != address(debtToken) && _to != address(psm));
        _underlyingAmount = bound(_underlyingAmount, 0, psm.usbdToUnderlying(psm.getUsbdLiquidity()));
        underlying.mint(user1, _underlyingAmount);

        vm.startPrank(user1);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity);
        assertEq(debtToken.balanceOf(user1), 0);
        assertEq(debtToken.balanceOf(_to), 0);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity);
        assertEq(underlying.balanceOf(user1), _underlyingAmount);
        if (_to == user1) assertEq(underlying.balanceOf(_to), _underlyingAmount);
        if (_to != user1) assertEq(underlying.balanceOf(_to), 0);

        uint256 mintedUsbdAmount = _underlyingAmount * 10 ** (18 - underlyingDecimals);

        underlying.approve(address(psm), _underlyingAmount);

        vm.expectEmit(true, true, false, true);
        emit Mint(user1, _to, _underlyingAmount, mintedUsbdAmount, block.timestamp);
        psm.mint(_to, _underlyingAmount);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity - mintedUsbdAmount);
        assertEq(debtToken.balanceOf(_to), mintedUsbdAmount);
        if (_to == user1) assertEq(debtToken.balanceOf(user1), mintedUsbdAmount);
        if (_to != user1) assertEq(debtToken.balanceOf(user1), 0);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity + _underlyingAmount);
        assertEq(underlying.balanceOf(user1), 0);
        assertEq(underlying.balanceOf(_to), 0);
    }

    function testFuzz_mint_notEnoughLiquidity(address _to, uint8 _delta) external {
        vm.assume(_to != address(0) && _to != address(debtToken) && _to != address(psm));
        vm.assume(_delta > 0);

        uint256 underlyingAmount = psm.usbdToUnderlying(psm.getUsbdLiquidity()) + _delta;

        underlying.mint(user1, underlyingAmount);

        vm.startPrank(user1);

        underlying.approve(address(psm), underlyingAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IBimaPSM.NotEnoughLiquidity.selector,
                address(debtToken),
                psm.getUsbdLiquidity(),
                underlyingAmount * 10 ** (18 - underlyingDecimals)
            )
        );
        psm.mint(_to, underlyingAmount);
    }

    function test_mint() external {
        uint256 underlyingAmount = 20_000 * 10 ** (18 - underlyingDecimals);
        underlying.mint(user1, underlyingAmount);

        vm.startPrank(user1);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity);
        assertEq(debtToken.balanceOf(user1), 0);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity);
        assertEq(underlying.balanceOf(user1), underlyingAmount);

        uint256 mintedUsbdAmount = underlyingAmount * 10 ** (18 - underlyingDecimals);

        underlying.approve(address(psm), underlyingAmount);

        vm.expectEmit(true, true, false, true);
        emit Mint(user1, user1, underlyingAmount, mintedUsbdAmount, block.timestamp);
        psm.mint(user1, underlyingAmount);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity - mintedUsbdAmount);
        assertEq(debtToken.balanceOf(user1), mintedUsbdAmount);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity + underlyingAmount);
        assertEq(underlying.balanceOf(user1), 0);
    }

    function test_mint_zero() external {
        uint256 initialUnderlyingAmount = 1_000 * 10 ** (18 - underlyingDecimals);
        underlying.mint(user1, initialUnderlyingAmount);

        vm.startPrank(user1);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity);
        assertEq(debtToken.balanceOf(user1), 0);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity);
        assertEq(underlying.balanceOf(user1), initialUnderlyingAmount);

        underlying.approve(address(psm), 0);

        psm.mint(user1, 0);

        assertEq(debtToken.balanceOf(address(psm)), initialUsbdLiquidity);
        assertEq(debtToken.balanceOf(user1), 0);
        assertEq(underlying.balanceOf(address(psm)), initialUnderlyingLiquidity);
        assertEq(underlying.balanceOf(user1), initialUnderlyingAmount);
    }
}
