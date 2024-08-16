// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBabelBase {
    function DECIMAL_PRECISION() external returns(uint256);

    function CCR() external returns(uint256);

    function DEBT_GAS_COMPENSATION() external returns(uint256);

    function PERCENT_DIVISOR() external returns(uint256);
}