// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// represents 100% in BIMA used in denominator when
// calculating amounts based on a percentage
uint256 constant BIMA_100_PCT = 10_000;

// BIMA's default decimal precision
uint256 constant BIMA_DECIMAL_PRECISION = 1e18;