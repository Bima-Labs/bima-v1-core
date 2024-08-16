// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {BabelOwnable} from "../../dependencies/BabelOwnable.sol";

interface IConvexDepositToken {
    function initialize(uint256 pid) external;
}

/**
    @notice Babel Convex Factory
    @title Deploys clones of `ConvexDepositToken` as directed by the Babel DAO
 */
contract ConvexFactory is BabelOwnable {
    using Clones for address;

    address public depositTokenImpl;

    event NewDeployment(uint256 pid, address depositToken);

    constructor(address _babelCore, address _depositTokenImpl) BabelOwnable(_babelCore) {
        depositTokenImpl = _depositTokenImpl;
    }

    /**
        @dev After calling this function, the owner should also call `Vault.registerReceiver`
             to enable BABEL emissions on the newly deployed `ConvexDepositToken`
     */
    function deployNewInstance(uint256 pid) external onlyOwner {
        address depositToken = depositTokenImpl.cloneDeterministic(bytes32(pid));

        IConvexDepositToken(depositToken).initialize(pid);

        emit NewDeployment(pid, depositToken);
    }

    function getDepositToken(uint256 pid) external view returns (address) {
        return Clones.predictDeterministicAddress(depositTokenImpl, bytes32(pid));
    }
}
