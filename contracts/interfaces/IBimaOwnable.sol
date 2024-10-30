// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBimaCore} from "./IBimaCore.sol";

interface IBimaOwnable {
    function BIMA_CORE() external view returns (IBimaCore);

    function owner() external view returns (address);

    function guardian() external view returns (address);
}
