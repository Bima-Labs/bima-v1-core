// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {BimaOwnable} from "../../dependencies/BimaOwnable.sol";
import {ICurveProxy} from "../../interfaces/ICurveProxy.sol";

interface ICurveDepositToken {
    function initialize(address _gauge) external;
}

/**
    @notice Bima Curve Factory
    @title Deploys clones of `CurveDepositToken` as directed by the Bima DAO
 */
contract CurveFactory is BimaOwnable {
    using Clones for address;

    ICurveProxy public immutable curveProxy;
    address public immutable depositTokenImpl;

    event NewDeployment(address gauge, address depositToken);

    constructor(address _bimaCore, ICurveProxy _curveProxy, address _depositTokenImpl) BimaOwnable(_bimaCore) {
        curveProxy = _curveProxy;
        depositTokenImpl = _depositTokenImpl;
    }

    /**
        @dev After calling this function, the owner should also call `Vault.registerReceiver`
             to enable BIMA emissions on the newly deployed `CurveDepositToken`
     */
    function deployNewInstance(address gauge) external onlyOwner {
        address depositToken = depositTokenImpl.cloneDeterministic(bytes32(bytes20(gauge)));

        ICurveDepositToken(depositToken).initialize(gauge);
        curveProxy.setPerGaugeApproval(depositToken, gauge);

        emit NewDeployment(gauge, depositToken);
    }

    function getDepositToken(address gauge) external view returns (address addr) {
        addr = Clones.predictDeterministicAddress(depositTokenImpl, bytes32(bytes20(gauge)));
    }
}
