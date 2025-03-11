// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {BimaOwnable} from "../../dependencies/BimaOwnable.sol";

interface IConvexDepositToken {
    function initialize(uint256 pid) external;
}

/**
    @notice Bima Convex Factory
    @title Deploys clones of `ConvexDepositToken` as directed by the Bima DAO
 */
contract ConvexFactory is BimaOwnable {
    using Clones for address;

    address public depositTokenImpl;

    event NewDeployment(uint256 pid, address depositToken);

    constructor(address _bimaCore, address _depositTokenImpl) BimaOwnable(_bimaCore) {
        depositTokenImpl = _depositTokenImpl;
    }

    /**
        @dev After calling this function, the owner should also call `Vault.registerReceiver`
             to enable BIMA emissions on the newly deployed `ConvexDepositToken`
     */
    function deployNewInstance(uint256 pid) external onlyOwner {
        address depositToken = depositTokenImpl.cloneDeterministic(bytes32(pid));

        IConvexDepositToken(depositToken).initialize(pid);

        emit NewDeployment(pid, depositToken);
    }

    function getDepositToken(uint256 pid) external view returns (address addr) {
        addr = Clones.predictDeterministicAddress(depositTokenImpl, bytes32(pid));
    }
}
