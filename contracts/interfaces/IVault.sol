// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBimaOwnable} from "./IBimaOwnable.sol";
import {ISystemStart} from "./ISystemStart.sol";
import {IBoostCalculator} from "./IBoostCalculator.sol";
import {IBoostDelegate} from "./IBoostDelegate.sol";
import {ITokenLocker} from "./ITokenLocker.sol";
import {IIncentiveVoting} from "./IIncentiveVoting.sol";
import {IBimaToken} from "./IBimaToken.sol";
import {IEmissionSchedule} from "./IEmissionSchedule.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewards {
    function vaultClaimReward(address claimant, address receiver) external returns (uint256);

    function claimableReward(address account) external view returns (uint256);
}

interface IBimaVault is IBimaOwnable, ISystemStart {
    struct InitialAllowance {
        address receiver;
        uint256 amount;
    }

    event BoostCalculatorSet(address boostCalculator);
    event BoostDelegationSet(address indexed boostDelegate, bool isEnabled, uint256 feePct, address callback);
    event EmissionScheduleSet(address emissionScheduler);
    event IncreasedAllocation(address indexed receiver, uint256 increasedAmount);
    event NewReceiverRegistered(address receiver, uint256 id);
    event ReceiverIsActiveStatusModified(uint256 indexed id, bool isActive);
    event UnallocatedSupplyIncreased(uint256 increasedAmount, uint256 unallocatedTotal);
    event UnallocatedSupplyReduced(uint256 reducedAmount, uint256 unallocatedTotal);

    function allocateNewEmissions(uint256 id) external returns (uint256);

    function batchClaimRewards(
        address receiver,
        address boostDelegate,
        IRewards[] calldata rewardContracts,
        uint256 maxFeePct
    ) external returns (bool);

    function increaseUnallocatedSupply(uint256 amount) external returns (bool);

    function registerReceiver(address receiver, uint256 count) external returns (bool);

    function setBoostCalculator(IBoostCalculator _boostCalculator) external returns (bool);

    function setBoostDelegationParams(bool isEnabled, uint16 feePct, address callback) external returns (bool);

    function setEmissionSchedule(IEmissionSchedule _emissionSchedule) external returns (bool);

    function setInitialParameters(
        IEmissionSchedule _emissionSchedule,
        IBoostCalculator _boostCalculator,
        uint256 totalSupply,
        uint64 initialLockWeeks,
        uint128[] calldata _fixedInitialAmounts,
        InitialAllowance[] calldata initialAllowances
    ) external;

    function setReceiverIsActive(uint256 id, bool isActive) external returns (bool);

    function transferAllocatedTokens(address claimant, address receiver, uint256 amount) external returns (bool);

    function transferTokens(IERC20 token, address receiver, uint256 amount) external returns (bool);

    function allocated(address) external view returns (uint256);

    function boostCalculator() external view returns (IBoostCalculator);

    function boostDelegation(address) external view returns (bool isEnabled, uint16 feePct, IBoostDelegate callback);

    function claimableRewardAfterBoost(
        address account,
        address receiver,
        address boostDelegate,
        IRewards rewardContract
    ) external view returns (uint256 adjustedAmount, uint256 feeToDelegate);

    function emissionSchedule() external view returns (IEmissionSchedule);

    function getClaimableWithBoost(address claimant) external view returns (uint256 maxBoosted, uint256 boosted);

    function idToReceiver(uint256) external view returns (address account, bool isActive, uint16 updatedWeek);

    function isReceiverActive(uint256 id) external view returns (bool isActive);

    function isBoostDelegatedEnabled(address account) external view returns (bool isEnabled);

    function lockWeeks() external view returns (uint64);

    function locker() external view returns (ITokenLocker);

    function claimableBoostDelegationFees(address claimant) external view returns (uint256 amount);

    function bimaToken() external view returns (IBimaToken);

    function totalUpdateWeek() external view returns (uint64);

    function unallocatedTotal() external view returns (uint128);

    function voter() external view returns (IIncentiveVoting);

    function weeklyEmissions(uint256) external view returns (uint128);
}
