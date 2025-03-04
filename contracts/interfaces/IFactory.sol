// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBimaOwnable} from "./IBimaOwnable.sol";
import {IDebtToken} from "./IDebtToken.sol";
import {ILiquidationManager} from "./ILiquidationManager.sol";
import {IBorrowerOperations} from "./IBorrowerOperations.sol";
import {IStabilityPool} from "./IStabilityPool.sol";

interface IFactory is IBimaOwnable {
    // commented values are suggested default parameters
    struct DeploymentParams {
        uint256 minuteDecayFactor; // 999037758833783000  (half life of 12 hours)
        uint256 redemptionFeeFloor; // 1e18 / 1000 * 5  (0.5%)
        uint256 maxRedemptionFee; // 1e18  (100%)
        uint256 borrowingFeeFloor; // 1e18 / 1000 * 5  (0.5%)
        uint256 maxBorrowingFee; // 1e18 / 100 * 5  (5%)
        uint256 interestRateInBps; // 100 (1%)
        uint256 maxDebt;
        uint256 MCR; // 12 * 1e17  (120%)
    }

    event NewDeployment(address collateral, address priceFeed, address troveManager, address sortedTroves);
    event ImplementationContractsChanged(address newTroveManagerImpl, address newSortedTrovesImpl);

    function deployNewInstance(
        address collateral,
        address priceFeed,
        address customTroveManagerImpl,
        address customSortedTrovesImpl,
        DeploymentParams calldata params
    ) external;

    function setImplementations(address _troveManagerImpl, address _sortedTrovesImpl) external;

    function borrowerOperations() external view returns (IBorrowerOperations);

    function debtToken() external view returns (IDebtToken);

    function liquidationManager() external view returns (ILiquidationManager);

    function sortedTrovesImpl() external view returns (address);

    function stabilityPool() external view returns (IStabilityPool);

    function troveManagerCount() external view returns (uint256);

    function troveManagerImpl() external view returns (address);

    function troveManagers(uint256) external view returns (address);
}
