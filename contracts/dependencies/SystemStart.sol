// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISystemStart} from "../interfaces/ISystemStart.sol";
import {IBabelCore} from "../interfaces/IBabelCore.sol";

/**
    @title Babel System Start Time
    @dev Provides a unified `startTime` and `getWeek`, used for emissions.
 */
contract SystemStart is ISystemStart {
    uint256 immutable startTime;

    constructor(address babelCore) {
        startTime = IBabelCore(babelCore).startTime();
    }

    function getWeek() public view returns (uint256 week) {
        week = (block.timestamp - startTime) / 1 weeks;
    }
}
