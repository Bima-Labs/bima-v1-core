// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBabelCore} from "../interfaces/IBabelCore.sol";
import {IBabelOwnable} from "../interfaces/IEmissionSchedule.sol";

/**
    @title Babel Ownable
    @notice Contracts inheriting `BabelOwnable` have the same owner as `BabelCore`.
            The ownership cannot be independently modified or renounced.
 */
contract BabelOwnable is IBabelOwnable {
    IBabelCore public immutable BABEL_CORE;

    constructor(address _babelCore) {
        BABEL_CORE = IBabelCore(_babelCore);
    }

    modifier onlyOwner() {
        require(msg.sender == BABEL_CORE.owner(), "Only owner");
        _;
    }

    function owner() public view returns (address) {
        return BABEL_CORE.owner();
    }

    function guardian() public view returns (address) {
        return BABEL_CORE.guardian();
    }
}
