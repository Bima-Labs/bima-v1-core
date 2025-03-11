// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBimaCore} from "../interfaces/IBimaCore.sol";
import {IBimaOwnable} from "../interfaces/IEmissionSchedule.sol";

/**
    @title Bima Ownable
    @notice Contracts inheriting `BimaOwnable` have the same owner as `BimaCore`.
            The ownership cannot be independently modified or renounced.
 */
contract BimaOwnable is IBimaOwnable {
    IBimaCore public immutable BIMA_CORE;

    constructor(address _bimaCore) {
        BIMA_CORE = IBimaCore(_bimaCore);
    }

    modifier onlyOwner() {
        require(msg.sender == BIMA_CORE.owner(), "Only owner");
        _;
    }

    function owner() public view returns (address result) {
        result = BIMA_CORE.owner();
    }

    function guardian() public view returns (address result) {
        result = BIMA_CORE.guardian();
    }
}
