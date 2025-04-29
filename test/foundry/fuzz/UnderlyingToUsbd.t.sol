// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {TestSetUpPSM} from "./TestSetUpPSM.sol";
import {console} from "forge-std/console.sol";

contract UnderlyingToUsbd is TestSetUpPSM {
    function setUp() public virtual override {
        super.setUp();
    }

    function testFuzz_UnderlyingToUsbd(uint256 amount) external view {
        console.log("Decimal of token ", mockUnderlyingToken.decimals());
        amount = bound(amount, 0, type(uint256).max / 10 ** 10);
        uint256 expected = amount * (10 **  (18 - customTokenDecimal));
        uint256 actual = psm.underlyingToUsbd(amount);
        assertEq(actual, expected);
    }
}
