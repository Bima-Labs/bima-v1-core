// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ISystemStart} from "../interfaces/ISystemStart.sol";
import {IBimaCore} from "../interfaces/IBimaCore.sol";

/**
    @title Bima System Start Time
    @dev Provides a unified `startTime` and `getWeek`, used for emissions.
 */
contract SystemStart is ISystemStart {
    uint256 immutable startTime;

    constructor(address bimaCore) {
        startTime = IBimaCore(bimaCore).startTime();
    }

    function getWeek() public view returns (uint256 week) {
        week = (block.timestamp - startTime) / 1 weeks;
    }
}
