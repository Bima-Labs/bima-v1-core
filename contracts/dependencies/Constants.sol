// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// represents 100% in BIMA used in denominator when
// calculating amounts based on a percentage
uint256 constant BIMA_100_PCT = 10_000;

// BIMA's default decimal precision
uint256 constant BIMA_DECIMAL_PRECISION = 1e18;

// BIMA's default scale factor
uint256 constant BIMA_SCALE_FACTOR = 1e9;

// BIMA's default reward duration
uint256 constant BIMA_REWARD_DURATION = 1 weeks;

// collateral tokens required decimals
uint8 constant BIMA_COLLATERAL_DECIMALS = 18;
