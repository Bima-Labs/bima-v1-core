// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ISystemStart} from "./ISystemStart.sol";
import {IDelegatedOps} from "./IDelegatedOps.sol";
import {ITokenLocker} from "./ITokenLocker.sol";

interface IIncentiveVoting is ISystemStart, IDelegatedOps {
    struct Vote {
        uint256 id;
        uint256 points;
    }

    event AccountWeightRegistered(
        address indexed account,
        uint256 indexed week,
        uint256 frozenBalance,
        ITokenLocker.LockData[] registeredLockData
    );
    event ClearedVotes(address indexed account, uint256 indexed week);
    event NewVotes(address indexed account, uint256 indexed week, Vote[] newVotes, uint256 totalPointsUsed);

    function clearRegisteredWeight(address account) external returns (bool);

    function clearVote(address account) external;

    function getReceiverVoteInputs(uint256 id, uint256 week) external returns (uint256, uint256);

    function getReceiverWeightWrite(uint256 idx) external returns (uint256);

    function getTotalWeightWrite() external returns (uint256);

    function registerAccountWeight(address account, uint256 minWeeks) external;

    function registerAccountWeightAndVote(address account, uint256 minWeeks, Vote[] calldata votes) external;

    function registerNewReceiver() external returns (uint256);

    function unfreeze(address account, bool keepVote) external returns (bool);

    function vote(address account, Vote[] calldata votes, bool clearPrevious) external;

    function MAX_LOCK_WEEKS() external view returns (uint256);

    function MAX_POINTS() external view returns (uint256);

    function getAccountCurrentVotes(address account) external view returns (Vote[] memory votes);

    function getAccountRegisteredLocks(
        address account
    ) external view returns (uint256 frozenWeight, ITokenLocker.LockData[] memory lockData);

    function getReceiverWeight(uint256 idx) external view returns (uint256);

    function getReceiverWeightAt(uint256 idx, uint256 week) external view returns (uint256);

    function getTotalWeight() external view returns (uint256);

    function getTotalWeightAt(uint256 week) external view returns (uint256);

    function receiverCount() external view returns (uint256);

    function receiverDecayRate(uint256) external view returns (uint32);

    function receiverUpdatedWeek(uint256) external view returns (uint16);

    function receiverWeeklyUnlocks(uint256, uint256) external view returns (uint32);

    function tokenLocker() external view returns (ITokenLocker);

    function totalDecayRate() external view returns (uint32);

    function totalUpdatedWeek() external view returns (uint16);

    function totalWeeklyUnlocks(uint256) external view returns (uint32);

    function vault() external view returns (address);
}
