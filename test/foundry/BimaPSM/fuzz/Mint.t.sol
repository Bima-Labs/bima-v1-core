// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {TestSetUpPSM} from "./TestSetUpPSM.sol";
import {console} from "forge-std/console.sol";
import {BimaPSM} from "../../../../contracts/BimaPSM.sol";
import {IBimaPSM} from "../../../../contracts/interfaces/IBimaPSM.sol";

contract Mint is TestSetUpPSM {
    function setUp() public virtual override {
        super.setUp();
    }

    function testFuzz_Mint(uint256 underlyingtDepositAmount) public {
        underlyingtDepositAmount = bound(underlyingtDepositAmount, 1, initalMintToUser);
        console.log("Initial mint amount:", initalMintToUser);

        console.log("Underlying Deposit Amount", underlyingtDepositAmount);
        console.log("Underlying Amount user have ", mockUnderlyingToken.balanceOf(USER));

        vm.startPrank(USER);
        // approving  mUSDT
        mockUnderlyingToken.approve(address(psm), underlyingtDepositAmount);

        uint256 usbdAmount = psm.underlyingToUsbd(underlyingtDepositAmount);
        vm.expectEmit(true, true, false, true);
        emit Mint(USER, USER, underlyingtDepositAmount, usbdAmount, block.timestamp);
        psm.mint(USER, underlyingtDepositAmount);

        vm.stopPrank();

        uint256 psmUsbd = debtToken.balanceOf(address(psm));
        uint256 psmMusdt = mockUnderlyingToken.balanceOf(address(psm));

        uint256 userUsbd = debtToken.balanceOf(USER);
        uint256 userMusdt = mockUnderlyingToken.balanceOf(USER);

        assertEq(psmUsbd, initialLiquidity - usbdAmount);
        assertEq(psmMusdt, underlyingtDepositAmount);
        assertEq(userUsbd, usbdAmount);
        assertEq(userMusdt, initalMintToUser - underlyingtDepositAmount);
    }

    // mint fails when there is no liquidity

    function testFuzz_Mint_Revert_NotEnoughLiquidty(uint256 amount) external {
        // remove liquidity
        _removeAllLiquidity();
        amount = bound(amount, 1, initalMintToUser);
        vm.startPrank(USER);
        // approving  mUSDT
        mockUnderlyingToken.approve(address(psm), amount);
        uint256 usbdBalanceOfPSM = debtToken.balanceOf(address(psm));

        vm.expectRevert(
            abi.encodeWithSelector(IBimaPSM.NotEnoughLiquidty.selector, address(debtToken), usbdBalanceOfPSM, amount)
        );
        psm.mint(USER, amount);
        vm.stopPrank();
    }

    function _removeAllLiquidity() internal {
        vm.startPrank(users.owner);
        psm.removeLiquidity(debtToken.balanceOf(address(psm)));
        vm.stopPrank();
        vm.stopPrank();
    }
}
