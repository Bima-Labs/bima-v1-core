// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {TestSetUpPSM} from "./TestSetUpPSM.sol";
import {console} from "forge-std/console.sol";
import {BimaPSM} from "../../../../contracts/BimaPSM.sol";
import {IBimaPSM} from "../../../../contracts/interfaces/IBimaPSM.sol";

contract Redeem is TestSetUpPSM {
    uint256 initialUSBD_to_User;

    function setUp() public virtual override {
        super.setUp();

        // minting initial amount so that USER have USBD and PSM have mUSDT
        vm.startPrank(USER);
        mockUnderlyingToken.approve(address(psm), initalMintToUser);
        psm.mint(USER, initalMintToUser);
        initialUSBD_to_User = psm.underlyingToUsbd(initalMintToUser);
        vm.stopPrank();
    }

    function testFuzz_Redeem(uint256 _underlyingAmount) public {
        _underlyingAmount = bound(_underlyingAmount, 1, initalMintToUser);

        uint256 usbdAmount = psm.underlyingToUsbd(_underlyingAmount);
        // redeem
        vm.startPrank(USER);
        debtToken.approve(address(psm), usbdAmount);
        vm.expectEmit(true, true, false, true);
        emit Redeem(USER, USER, _underlyingAmount, usbdAmount, block.timestamp);
        psm.redeem(USER, _underlyingAmount);
        vm.stopPrank();

        uint256 psmUsbd = debtToken.balanceOf(address(psm));
        uint256 psmMusdt = mockUnderlyingToken.balanceOf(address(psm));

        uint256 userUsbd = debtToken.balanceOf(USER);
        uint256 userMusdt = mockUnderlyingToken.balanceOf(USER);

        assertEq(psmUsbd, initialLiquidity - initialUSBD_to_User + usbdAmount);
        assertEq(psmMusdt, initalMintToUser - _underlyingAmount);
        assertEq(userUsbd, initialUSBD_to_User - usbdAmount);
        assertEq(userMusdt, _underlyingAmount);
    }

    function testFuzz_Redeem_Revert_NotEnoughLiquidty(uint256 amount) external {
        /**
         * In setUp(), miniting initial amount of USBD to USER so user will have
         * initial USBD and PSM will have mUSDT , so setting amount greater than
         * initial amount of mint amount
         */
        amount = bound(amount, initalMintToUser + 10e10, type(uint128).max);
        uint256 usbdAmount = psm.underlyingToUsbd(amount);

        // owner is minting initial amount of USBD to user
        vm.startPrank(users.owner);
        debtToken.authorizedMint(USER, usbdAmount);
        vm.stopPrank();

        vm.startPrank(USER);
        debtToken.approve(address(psm), usbdAmount);
        console.log("USBD Amount approved", usbdAmount);
        console.log("underlying amount   ", amount);

        uint256 underlyingTokenBalanceOfPSM = mockUnderlyingToken.balanceOf(address(psm));
        vm.expectRevert(
            abi.encodeWithSelector(
                IBimaPSM.NotEnoughLiquidty.selector,
                address(mockUnderlyingToken),
                underlyingTokenBalanceOfPSM,
                amount
            )
        );
        psm.redeem(USER, amount);
        vm.stopPrank();
    }
}
