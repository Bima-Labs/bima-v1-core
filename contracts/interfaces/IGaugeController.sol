// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IGaugeController {
    function vote_for_gauge_weights(address gauge, uint256 weight) external;

    function gauge_types(address gauge) external view returns (int128);
}
