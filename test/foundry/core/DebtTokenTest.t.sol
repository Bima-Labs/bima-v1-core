// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, DebtToken} from "../TestSetup.sol";

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract DebtTokenTest is IERC3156FlashBorrower, TestSetup {

    function test_flashLoanFee() external {
        // entire supply initially available to borrow
        assertEq(debtToken.maxFlashLoan(), type(uint256).max);

        // expected fee for borrowing 1e18
        uint256 borrowAmount = 1e18;
        uint256 expectedFee  = borrowAmount * debtToken.FLASH_LOAN_FEE() / 10000;

        // fee should be > 0
        assertTrue(expectedFee > 0);

        // fee should be exactly equal
        assertEq(debtToken.flashFee(borrowAmount), expectedFee);

        // attempt to exploit rounding down to zero precision loss
        // to get free flash loans by borrowing in small amounts - since
        // DebtToken::flashLoan allows re-entrancy, the function could be re-entered
        // multiple times to borrow larger amounts at zero fee
        borrowAmount = 1111;
        vm.expectRevert("ERC20FlashMint: amount too small");
        debtToken.flashFee(borrowAmount);
    }

    function test_flashLoan(uint256 amount) external {
        amount = bound(amount, 1e18, 1_000_000_000_000e18);

        debtToken.flashLoan(this, amount, bytes(""));
    }

    function onFlashLoan(
        address /*initiator*/,
        address /*token*/,
        uint256 amount,
        uint256 fee,
        bytes calldata /*data*/
    ) external returns (bytes32 returnVal) {
        returnVal = keccak256("ERC3156FlashBorrower.onFlashLoan");

        // mint ourselves the fee
        vm.prank(address(borrowerOps));
        debtToken.mint(address(this), fee);

        // approve debt token contract to take amount + fee
        debtToken.approve(address(debtToken), amount+fee);
    }
}