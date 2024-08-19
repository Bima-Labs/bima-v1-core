// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, DebtToken} from "../TestSetup.sol";

contract DebtTokenTest is TestSetup {

    function test_flashLoanFee() external {
        // entire supply initially available to borrow
        assertEq(debtToken.maxFlashLoan(address(debtToken)), type(uint256).max);

        // expected fee for borrowing 1e18
        uint256 borrowAmount = 1e18;
        uint256 expectedFee  = borrowAmount * debtToken.FLASH_LOAN_FEE() / 10000;

        // fee should be > 0
        assertTrue(expectedFee > 0);

        // fee should be exactly equal
        assertEq(debtToken.flashFee(address(debtToken), borrowAmount), expectedFee);

        // attempt to exploit rounding down to zero precision loss
        // to get free flash loans by borrowing in small amounts - since
        // DebtToken::flashLoan allows re-entrancy, the function could be re-entered
        // multiple times to borrow larger amounts at zero fee
        borrowAmount = 1111;
        vm.expectRevert("ERC20FlashMint: amount too small");
        debtToken.flashFee(address(debtToken), borrowAmount);

    }
}