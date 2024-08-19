// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBabelCore} from "./IBabelCore.sol";

interface IBabelOwnable {
    function BABEL_CORE() external view returns (IBabelCore);

    function owner() external view returns (address);

    function guardian() external view returns (address);
}