// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBimaOwnable} from "./IBimaOwnable.sol";
import {ISystemStart} from "./ISystemStart.sol";
import {IDebtToken} from "./IDebtToken.sol";
import {IBimaVault} from "./IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStabilityPool is IBimaOwnable, ISystemStart {
    event CollateralGainWithdrawn(address indexed _depositor, uint256[] _collateralGains);
    event CollateralOverwritten(IERC20 oldCollateral, IERC20 newCollateral);
    event DepositSnapshotUpdated(address indexed _depositor, uint256 _P, uint256 _G);
    event EpochUpdated(uint128 _currentEpoch);
    event G_Updated(uint256 _G, uint128 _epoch, uint128 _scale);
    event P_Updated(uint256 _P);
    event RewardClaimed(address indexed account, address indexed recipient, uint256 claimed);
    event S_Updated(uint256 idx, uint256 _S, uint128 _epoch, uint128 _scale);
    event ScaleUpdated(uint128 _currentScale);
    event StabilityPoolDebtBalanceUpdated(uint256 _newBalance);
    event UserDepositChanged(address indexed _depositor, uint256 _newDeposit);

    function claimCollateralGains(address recipient, uint256[] calldata collateralIndexes) external;

    function claimReward(address recipient) external returns (uint256 amount);

    function enableCollateral(IERC20 _collateral) external;

    function offset(IERC20 collateral, uint256 _debtToOffset, uint256 _collToAdd) external;

    function provideToSP(uint256 _amount) external;

    function startCollateralSunset(IERC20 collateral) external;

    function vaultClaimReward(address claimant, address) external returns (uint256 amount);

    function withdrawFromSP(uint256 _amount) external;

    function P() external view returns (uint256);

    function SUNSET_DURATION() external view returns (uint128);

    function accountDeposits(address) external view returns (uint128 amount, uint128 timestamp);

    function claimableReward(address _depositor) external view returns (uint256);

    function collateralGainsByDepositor(address depositor, IERC20 token) external view returns (uint256 gains);

    function collateralTokens(uint256) external view returns (IERC20);

    function currentEpoch() external view returns (uint128);

    function currentScale() external view returns (uint128);

    function debtToken() external view returns (IDebtToken);

    function depositSnapshots(address) external view returns (uint256 P, uint256 G, uint128 scale, uint128 epoch);

    function depositSums(address, IERC20) external view returns (uint256);

    function SP_EMISSION_ID() external view returns (uint256);

    function epochToScaleToG(uint128, uint128) external view returns (uint256);

    function epochToScaleToSums(uint128, uint128, IERC20) external view returns (uint256);

    function factory() external view returns (address);

    function getCompoundedDebtDeposit(address _depositor) external view returns (uint256);

    function getDepositorCollateralGain(address _depositor) external view returns (uint256[] memory collateralGains);

    function getTotalDebtTokenDeposits() external view returns (uint256);

    function indexByCollateral(IERC20 collateral) external view returns (uint256 index);

    function lastCollateralError_Offset(uint256) external view returns (uint256);

    function lastDebtLossError_Offset() external view returns (uint256);

    function lastBimaError() external view returns (uint256);

    function lastUpdate() external view returns (uint32);

    function liquidationManager() external view returns (address);

    function periodFinish() external view returns (uint32);

    function rewardRate() external view returns (uint128);

    function vault() external view returns (IBimaVault);
}
