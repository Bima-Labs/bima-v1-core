// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBimaBase} from "./IBimaBase.sol";
import {IStabilityPool} from "../interfaces/IStabilityPool.sol";
import {IBorrowerOperations} from "../interfaces/IBorrowerOperations.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";

interface ILiquidationManager is IBimaBase {
    function batchLiquidateTroves(ITroveManager troveManager, address[] calldata _troveArray) external;

    function enableTroveManager(ITroveManager _troveManager) external;

    function liquidate(ITroveManager troveManager, address borrower) external;

    function liquidateTroves(ITroveManager troveManager, uint256 maxTrovesToLiquidate, uint256 maxICR) external;

    function borrowerOperations() external view returns (IBorrowerOperations);

    function factory() external view returns (address);

    function stabilityPool() external view returns (IStabilityPool);
}
