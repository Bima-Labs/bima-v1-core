// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IBimaBase {
    function CCR() external returns (uint256);

    function DEBT_GAS_COMPENSATION() external returns (uint256);

    function PERCENT_DIVISOR() external returns (uint256);
}
