// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBimaCore} from "./IBimaCore.sol";
import {IIncentiveVoting} from "./IIncentiveVoting.sol";
import {IBimaVault} from "./IVault.sol";
import {IBimaOwnable} from "./IBimaOwnable.sol";
import {ISystemStart} from "./ISystemStart.sol";

interface IEmissionSchedule is IBimaOwnable, ISystemStart {
    event LockParametersSet(uint256 lockWeeks, uint256 lockDecayWeeks);
    event WeeklyPctScheduleSet(uint64[2][] schedule);

    function getReceiverWeeklyEmissions(
        uint256 id,
        uint256 week,
        uint256 totalWeeklyEmissions
    ) external returns (uint256);

    function getTotalWeeklyEmissions(
        uint256 week,
        uint256 unallocatedTotal
    ) external returns (uint256 amount, uint64 lock);

    function setLockParameters(uint64 _lockWeeks, uint64 _lockDecayWeeks) external returns (bool);

    function setWeeklyPctSchedule(uint64[2][] calldata _schedule) external returns (bool);

    function MAX_LOCK_WEEKS() external view returns (uint256);

    function getWeeklyPctSchedule() external view returns (uint64[2][] memory);

    function lockDecayWeeks() external view returns (uint64);

    function lockWeeks() external view returns (uint64);

    function vault() external view returns (IBimaVault);

    function voter() external view returns (IIncentiveVoting);

    function weeklyPct() external view returns (uint64);
}
