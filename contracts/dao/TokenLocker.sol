// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BimaOwnable} from "../dependencies/BimaOwnable.sol";
import {SystemStart} from "../dependencies/SystemStart.sol";
import {ITokenLocker, IBimaToken, IBimaCore, IIncentiveVoting} from "../interfaces/ITokenLocker.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
    @title Bima Token Locker
    @notice BIMA tokens can be locked in this contract to receive "lock weight",
            which is used within `AdminVoting` and `IncentiveVoting` to vote on
            core protocol operations.
 */
contract TokenLocker is ITokenLocker, BimaOwnable, SystemStart {
    // The maximum number of weeks that tokens may be locked for. Also determines the maximum
    // number of active locks that a single account may open. Weight is calculated as:
    // `[balance] * [weeks to unlock]`. Weights are stored as `uint40` and balances as `uint32`,
    // so the max lock weeks cannot be greater than 256 or the system could break due to overflow.
    uint256 public constant MAX_LOCK_WEEKS = 52;

    // Multiplier applied during token deposits and withdrawals. A balance within this
    // contract corresponds to a deposit of `balance * lockToTokenRatio` tokens. Balances
    // in this contract are stored as `uint32`, so the invariant:
    //
    // `lockToken.totalSupply() <= type(uint32).max * lockToTokenRatio`
    //
    // cannot be violated or the system could break due to overflow.
    uint256 public immutable lockToTokenRatio;

    IBimaToken public immutable lockToken;
    IIncentiveVoting public immutable incentiveVoter;
    IBimaCore public immutable bimaCore;
    address public immutable deploymentManager;

    struct AccountData {
        // Currently locked balance. Each week the lock weight decays by this amount.
        uint32 locked;
        // Currently unlocked balance (from expired locks, can be withdrawn)
        uint32 unlocked;
        // Currently "frozen" balance. A frozen balance is equivalent to a `MAX_LOCK_WEEKS` lock,
        // where the lock weight does not decay weekly. An account may have a locked balance or a
        // frozen balance, never both at the same time.
        uint32 frozen;
        // Current week within `accountWeeklyUnlocks`. Lock durations decay as this value increases.
        uint16 week;
        // Array of bitfields, where each bit represents 1 week. A bit is set to true when the
        // account has a non-zero token balance unlocking in that week, and so a non-zero value
        // at the same index in `accountWeeklyUnlocks`. We use this bitarray to reduce gas costs
        // when iterating over the weekly unlocks.
        uint256[256] updateWeeks;
    }

    // Rate at which the total lock weight decreases each week. The total decay rate may not
    // be equal to the total number of locked tokens, as it does not include frozen accounts.
    uint32 public totalDecayRate;
    // Current week within `totalWeeklyWeights` and `totalWeeklyUnlocks`. When up-to-date
    // this value is always equal to `getWeek()`
    uint16 public totalUpdatedWeek;

    bool public penaltyWithdrawalsEnabled;
    uint256 public allowPenaltyWithdrawAfter;

    // week -> total lock weight
    uint40[65535] totalWeeklyWeights;
    // week -> tokens to unlock in this week
    uint32[65535] totalWeeklyUnlocks;

    // account -> week -> lock weight
    mapping(address account => uint40[65535] weeklyWeight) accountWeeklyWeights;

    // account -> week -> token balance unlocking this week
    mapping(address account => uint32[65535] weeklyUnlock) accountWeeklyUnlocks;

    // account -> primary account data structure
    mapping(address account => AccountData accountData) accountLockData;

    constructor(
        address _bimaCore,
        IBimaToken _token,
        IIncentiveVoting _voter,
        address _manager,
        uint256 _lockToTokenRatio
    ) SystemStart(_bimaCore) BimaOwnable(_bimaCore) {
        lockToken = _token;
        incentiveVoter = _voter;
        bimaCore = IBimaCore(_bimaCore);
        deploymentManager = _manager;

        lockToTokenRatio = _lockToTokenRatio;
    }

    modifier notFrozen(address account) {
        require(accountLockData[account].frozen == 0, "Lock is frozen");
        _;
    }

    function setAllowPenaltyWithdrawAfter(uint256 _timestamp) external returns (bool success) {
        // only deployment manager can set penalty withdraw start time
        require(msg.sender == deploymentManager, "!deploymentManager");

        // penalty withdraw start time can only be set once
        require(allowPenaltyWithdrawAfter == 0, "Already set");

        // start time must be greate than now and less than 13 weeks in the future
        require(_timestamp > block.timestamp && _timestamp < block.timestamp + 13 weeks, "Invalid timestamp");

        // update storage
        allowPenaltyWithdrawAfter = _timestamp;

        emit SetAllowPenaltyWithdrawAfter(_timestamp);
        success = true;
    }

    /**
        @notice Allow or disallow early-exit of locks by paying a penalty
     */
    function setPenaltyWithdrawalsEnabled(bool _enabled) external onlyOwner returns (bool success) {
        // revert if start time has not been set or if the
        // start time is in the future (too early)
        uint256 start = allowPenaltyWithdrawAfter;
        require(start != 0 && block.timestamp > start, "Not yet!");

        // update storage
        penaltyWithdrawalsEnabled = _enabled;

        emit SetPenaltyWithdrawalsEnabled(_enabled);
        success = true;
    }

    /**
        @notice Get the balances currently held in this contract for an account
        @return locked balance which is currently locked or frozen
        @return unlocked expired lock balance which may be withdrawn
     */
    function getAccountBalances(address account) external view returns (uint256 locked, uint256 unlocked) {
        // get storage reference to account data
        AccountData storage accountData = accountLockData[account];

        // cache account frozen balance
        uint256 frozen = accountData.frozen;

        // output account unlocked balance
        unlocked = accountData.unlocked;

        // return locked=frozen if there are frozen tokens
        if (frozen > 0) {
            return (frozen, unlocked);
        }

        // otherwise output locked balance
        locked = accountData.locked;

        // if account has tokens locked
        if (locked > 0) {
            // get storage reference to account's weekly unlocks
            uint32[65535] storage weeklyUnlocks = accountWeeklyUnlocks[account];

            // cache week when account last did a _weeklyWeightWrite
            uint256 accountWeek = accountData.week;

            // get current system week
            uint256 systemWeek = getWeek();

            uint256 bitfield = accountData.updateWeeks[accountWeek / 256] >> (accountWeek % 256);

            // if the last account week is smaller than current system week, iterate
            // forward adjusting locked & unlocked amounts for unlocks
            while (accountWeek < systemWeek) {
                accountWeek++;
                if (accountWeek % 256 == 0) {
                    bitfield = accountData.updateWeeks[accountWeek / 256];
                } else {
                    bitfield = bitfield >> 1;
                }
                if (bitfield & uint256(1) == 1) {
                    uint256 u = weeklyUnlocks[accountWeek];

                    locked -= u;
                    unlocked += u;

                    if (locked == 0) break;
                }
            }
        }
    }

    /**
        @notice Get account balances without any processing
     */
    function getAccountBalancesRaw(
        address account
    ) external view returns (uint32 locked, uint32 unlocked, uint32 frozen) {
        (locked, unlocked, frozen) = (
            accountLockData[account].locked,
            accountLockData[account].unlocked,
            accountLockData[account].frozen
        );
    }

    /**
        @notice Get total unlocks for given week
     */
    function getTotalWeeklyUnlocks(uint256 week) public view returns (uint256 unlocks) {
        unlocks = totalWeeklyUnlocks[week];
    }

    /**
        @notice Get account unlocks for given week
     */
    function getAccountWeeklyUnlocks(address account, uint256 week) public view returns (uint256 unlocks) {
        unlocks = accountWeeklyUnlocks[account][week];
    }

    /**
        @notice Get the current lock weight for an account
     */
    function getAccountWeight(address account) external view returns (uint256 weight) {
        weight = getAccountWeightAt(account, getWeek());
    }

    /**
        @notice Get the lock weight for an account in a given week
     */
    function getAccountWeightAt(address account, uint256 week) public view returns (uint256 weight) {
        // no weight for future weeks
        if (week > getWeek()) return 0;

        // get storage references
        uint32[65535] storage weeklyUnlocks = accountWeeklyUnlocks[account];
        uint40[65535] storage weeklyWeights = accountWeeklyWeights[account];
        AccountData storage accountData = accountLockData[account];

        // cache week when account last did a _weeklyWeightWrite
        uint256 accountWeek = accountData.week;

        // if input week is equal or smaller to when account last did
        // a weekly write, then just return the weight from that past week
        if (accountWeek >= week) return weeklyWeights[week];

        // otherwise the request is for a future week that the account hasn't
        // done a weekly write for
        uint256 locked = accountData.locked;
        weight = weeklyWeights[accountWeek];

        // if account has nothing locked or is frozen, return the weight
        // from the account's last weekly write
        if (locked == 0 || accountData.frozen > 0) {
            return weight;
        }

        // otherwise iterate forward and adjust weight for unlocks
        uint256 bitfield = accountData.updateWeeks[accountWeek / 256] >> (accountWeek % 256);
        while (accountWeek < week) {
            accountWeek++;
            weight -= locked;
            if (accountWeek % 256 == 0) {
                bitfield = accountData.updateWeeks[accountWeek / 256];
            } else {
                bitfield = bitfield >> 1;
            }
            if (bitfield & uint256(1) == 1) {
                uint256 amount = weeklyUnlocks[accountWeek];
                locked -= amount;
                if (locked == 0) break;
            }
        }
    }

    /**
        @notice Get data on an accounts's active token locks and frozen balance
        @param account Address to query data for
        @return lockData dynamic array of [weeks until expiration, balance of lock]
        @return frozenAmount total frozen balance
     */
    function getAccountActiveLocks(
        address account,
        uint256 minWeeks
    ) external view returns (LockData[] memory lockData, uint256 frozenAmount) {
        // get storage reference to account lock data
        AccountData storage accountData = accountLockData[account];

        // output account's frozen amount
        frozenAmount = accountData.frozen;

        // if nothing frozen then account has active locks to get data for
        if (frozenAmount == 0) {
            // minimum lock time is 1 week
            if (minWeeks == 0) minWeeks = 1;

            // get storage reference to account weekly unlocks
            uint32[65535] storage unlocks = accountWeeklyUnlocks[account];

            // get current system week
            uint256 systemWeek = getWeek();

            // calculate minimum lock week to start searching from
            uint256 currentWeek = systemWeek + minWeeks;

            // max lock weeks ahead from current week to search until
            uint256 maxLockWeek = systemWeek + MAX_LOCK_WEEKS;

            // calculate how many weeks to output data for
            uint256[] memory unlockWeeks = new uint256[](MAX_LOCK_WEEKS);
            uint256 bitfield = accountData.updateWeeks[currentWeek / 256] >> (currentWeek % 256);

            uint256 length;
            while (currentWeek <= maxLockWeek) {
                if (bitfield & uint256(1) == 1) {
                    unlockWeeks[length] = currentWeek;
                    length++;
                }

                currentWeek++;
                if (currentWeek % 256 == 0) {
                    bitfield = accountData.updateWeeks[currentWeek / 256];
                } else {
                    bitfield = bitfield >> 1;
                }
            }

            // allocate output array for calculated week amount
            lockData = new LockData[](length);

            uint256 x = length;
            // increment i, decrement x so LockData is ordered from longest to shortest duration
            for (uint256 i; x != 0; i++) {
                x--;
                uint256 idx = unlockWeeks[x];
                lockData[i] = LockData({weeksToUnlock: idx - systemWeek, amount: unlocks[idx]});
            }
        }
    }

    /**
        @notice Get withdrawal and penalty amounts when withdrawing locked tokens
        @param account Account that will withdraw locked tokens
        @param amountToWithdraw Desired withdrawal amount, divided by `lockToTokenRatio`
        @return amountWithdrawn Actual amount withdrawn. If `amountToWithdraw` exceeds the
                                max possible withdrawal, the return value is the max
                                amount received after paying the penalty.
        @return penaltyAmountPaid The amount paid in penalty to perform this withdrawal
     */
    function getWithdrawWithPenaltyAmounts(
        address account,
        uint256 amountToWithdraw
    ) external view returns (uint256 amountWithdrawn, uint256 penaltyAmountPaid) {
        // get storage reference to user's account
        AccountData storage accountData = accountLockData[account];

        // scale up both amount to withdraw and unlocked amount by lockToTokenRatio
        if (amountToWithdraw != type(uint256).max) amountToWithdraw *= lockToTokenRatio;
        uint256 unlocked = accountData.unlocked * lockToTokenRatio;

        // if user has enough unlocked to cover the withdraw, then there is no penalty
        if (unlocked >= amountToWithdraw) {
            return (amountToWithdraw, 0);
        }

        // if execution reaches here user doesn't have enough unlocked to
        // cover the amount they want to withdraw
        uint256 remaining = amountToWithdraw - unlocked;

        uint256 accountWeek = accountData.week;
        uint256 systemWeek = getWeek();
        uint256 offset = systemWeek - accountWeek;
        uint256 bitfield = accountData.updateWeeks[accountWeek / 256];

        // `weeksToUnlock < MAX_LOCK_WEEKS` stops iteration prior to the final week
        for (uint256 weeksToUnlock = 1; weeksToUnlock < MAX_LOCK_WEEKS; weeksToUnlock++) {
            accountWeek++;

            if (accountWeek % 256 == 0) {
                bitfield = accountData.updateWeeks[accountWeek / 256];
            }

            if ((bitfield >> (accountWeek % 256)) & uint256(1) == 1) {
                // get amount locked for given week scaled up by lockToTokenRatio
                uint256 lockAmount = accountWeeklyUnlocks[account][accountWeek] * lockToTokenRatio;

                uint256 penaltyOnAmount;
                if (accountWeek > systemWeek) {
                    // only apply the penalty if the lock has not expired
                    penaltyOnAmount = (lockAmount * (weeksToUnlock - offset)) / MAX_LOCK_WEEKS;
                }

                // if after deducting the penalty from the locked amount the result is
                // greater than the remaining amount the user wishes to withdraw
                if (lockAmount - penaltyOnAmount > remaining) {
                    // then recalculate the penalty using only the portion of the lock
                    // amount that will be withdrawn
                    penaltyOnAmount =
                        (remaining * MAX_LOCK_WEEKS) /
                        (MAX_LOCK_WEEKS - (weeksToUnlock - offset)) -
                        remaining;

                    // add any dust to the penalty amount
                    uint256 dust = ((penaltyOnAmount + remaining) % lockToTokenRatio);
                    if (dust > 0) penaltyOnAmount += lockToTokenRatio - dust;

                    // update memory total penalty
                    penaltyAmountPaid += penaltyOnAmount;

                    // nothing remaining to be withdrawn
                    remaining = 0;
                }
                // otherwise use entire locked amount to service the withdrawal
                else {
                    // update memory total penalty
                    penaltyAmountPaid += penaltyOnAmount;

                    // adjust remaining amount by net amount withdraw after penalty incurred
                    remaining -= lockAmount - penaltyOnAmount;
                }

                // exit loop if amount to be withdrawn satisfied
                if (remaining == 0) {
                    break;
                }
            }
        }

        // output actual withdrawn amount
        amountWithdrawn = amountToWithdraw - remaining;
    }

    /**
        @notice Get the current total lock weight
     */
    function getTotalWeight() external view returns (uint256 weight) {
        weight = getTotalWeightAt(getWeek());
    }

    /**
        @notice Get the total lock weight for a given week
     */
    function getTotalWeightAt(uint256 week) public view returns (uint256 weight) {
        // future weeks have no weight yet
        uint256 systemWeek = getWeek();
        if (week > systemWeek) return 0;

        // if weekly write has already occurred for the input week
        // then just return the weight already calculated
        uint32 updatedWeek = totalUpdatedWeek;
        if (week <= updatedWeek) return totalWeeklyWeights[week];

        // cache decay rate
        uint32 rate = totalDecayRate;

        // cache weight from last updated week
        weight = totalWeeklyWeights[updatedWeek];

        // if no decay return weight from last calculated week
        // second condition here seems strange and likely to never trigger
        if (rate == 0 || updatedWeek >= systemWeek) {
            return weight;
        }

        // weekly write hasn't occurred for passed week(s)
        // so iterate through until the input week adjusting
        // the output weight for the decay rate and the decay
        // rate for the weekly unlocks
        while (updatedWeek < week) {
            updatedWeek++;
            weight -= rate;
            rate -= totalWeeklyUnlocks[updatedWeek];
        }
    }

    /**
        @notice Get the current lock weight for an account
        @dev Also updates local storage values for this account. Using
             this function over it's `view` counterpart is preferred for
             contract -> contract interactions.
     */
    function getAccountWeightWrite(address account) external returns (uint256 weight) {
        weight = _weeklyWeightWrite(account);
    }

    /**
        @notice Get the current total lock weight
        @dev Also updates local storage values for total weights. Using
             this function over it's `view` counterpart is preferred for
             contract -> contract interactions.
     */
    function getTotalWeightWrite() public returns (uint256 weightOut) {
        // get current system week
        uint256 week = getWeek();

        // cache important values from storage
        uint32 rate = totalDecayRate;
        uint32 updatedWeek = totalUpdatedWeek;
        uint40 weight = totalWeeklyWeights[updatedWeek];

        // if there was no weight in last weekly update
        if (weight == 0) {
            // then set current week as last update and
            // return 0 for weight
            totalUpdatedWeek = SafeCast.toUint16(week);
            return 0;
        }
        // otherwise if there was weight in the last update,
        // iterate through the missed weeks from last update
        // to current week
        while (updatedWeek < week) {
            updatedWeek++;

            // decrease weight by decay rate
            weight -= rate;

            // update storage weight for that week
            totalWeeklyWeights[updatedWeek] = weight;

            // adjust decay rate by unlocks for that week
            rate -= totalWeeklyUnlocks[updatedWeek];
        }

        // update storage decay rate and last updated week
        totalDecayRate = rate;
        totalUpdatedWeek = SafeCast.toUint16(week);

        weightOut = weight;
    }

    /**
        @notice Deposit tokens into the contract to create a new lock.
        @dev A lock is created for a given number of weeks. Minimum 1, maximum `MAX_LOCK_WEEKS`.
             An account can have multiple locks active at the same time. The account's "lock weight"
             is calculated as the sum of [number of tokens] * [weeks until unlock] for all active
             locks. At the start of each new week, each lock's weeks until unlock is reduced by 1.
             Locks that reach 0 weeks no longer receive any weight, and tokens may be withdrawn by
             calling `withdrawExpiredLocks`.
        @param _account Address to create a new lock for (does not have to be the caller)
        @param _amount Amount of tokens to lock. This balance transfered from the caller.
        @param _weeks The number of weeks for the lock
     */
    function lock(address _account, uint256 _amount, uint256 _weeks) external returns (bool success) {
        // enforce minimum lock time
        require(_weeks > 0, "Min 1 week");

        // enforce positive lock amount
        require(_amount > 0, "Amount must be nonzero");

        // first transfer locked tokens from user
        lockToken.transferToLocker(msg.sender, _amount * lockToTokenRatio);

        // then perform the lock
        _lock(_account, _amount, _weeks);

        success = true;
    }

    function _lock(address _account, uint256 _amount, uint256 _weeks) internal {
        // enforce maximum lock time; important to do this here as
        // this function can also be called during withdrawals when re-locking
        require(_weeks <= MAX_LOCK_WEEKS, "Exceeds MAX_LOCK_WEEKS");

        // get storage reference to account's lock data
        AccountData storage accountData = accountLockData[_account];

        // perform account weekly weight write to get fresh account weight
        uint256 accountWeight = _weeklyWeightWrite(_account);

        // perform weekly write to get fresh total weight
        uint256 totalWeight = getTotalWeightWrite();

        // get current system week
        uint256 systemWeek = getWeek();

        // cache account's frozen amount
        uint256 frozen = accountData.frozen;

        // if account has a frozen amount, add the newly locked tokens
        // to the frozen amount
        if (frozen > 0) {
            accountData.frozen = SafeCast.toUint32(frozen + _amount);
            _weeks = MAX_LOCK_WEEKS;
        }
        // otherwise account has no frozen amount so lock normally
        else {
            // change 1 week lock into 2 week lock if the lock occurs
            // during the final 3 days of the week
            if (_weeks == 1 && block.timestamp % 1 weeks > 4 days) _weeks = 2;

            // update storage add amount to account's locked amount
            accountData.locked = SafeCast.toUint32(accountData.locked + _amount);

            // update storage decay rate by newly locked account
            totalDecayRate = SafeCast.toUint32(totalDecayRate + _amount);

            // update unlock totals for future week when this lock will expire
            uint32[65535] storage unlocks = accountWeeklyUnlocks[_account];
            uint256 unlockWeek = systemWeek + _weeks;
            uint256 previous = unlocks[unlockWeek];

            // modify weekly unlocks and unlock bitfield
            unlocks[unlockWeek] = SafeCast.toUint32(previous + _amount);
            totalWeeklyUnlocks[unlockWeek] += SafeCast.toUint32(_amount);
            if (previous == 0) {
                uint256 idx = unlockWeek / 256;
                uint256 bitfield = accountData.updateWeeks[idx] | (uint256(1) << (unlockWeek % 256));
                accountData.updateWeeks[idx] = bitfield;
            }
        }

        // update and adjust account weight and decay rate
        accountWeeklyWeights[_account][systemWeek] = SafeCast.toUint40(accountWeight + _amount * _weeks);

        // update and modify total weight
        totalWeeklyWeights[systemWeek] = SafeCast.toUint40(totalWeight + _amount * _weeks);

        emit LockCreated(_account, _amount, _weeks);
    }

    /**
        @notice Extend the length of an existing lock.
        @param _amount Amount of tokens to extend the lock for. When the value given equals
                       the total size of the existing lock, the entire lock is moved.
                       If the amount is less, then the lock is effectively split into
                       two locks, with a portion of the balance extended to the new length
                       and the remaining balance at the old length.
        @param _weeks The number of weeks for the lock that is being extended.
        @param _newWeeks The number of weeks to extend the lock until.
     */
    function extendLock(
        uint256 _amount,
        uint256 _weeks,
        uint256 _newWeeks
    ) external notFrozen(msg.sender) returns (bool success) {
        // enforce minimum lock time
        require(_weeks > 0, "Min 1 week");

        // enforce maximum lock time
        require(_newWeeks <= MAX_LOCK_WEEKS, "Exceeds MAX_LOCK_WEEKS");

        // must be extending the lock
        require(_weeks < _newWeeks, "newWeeks must be greater than weeks");

        // enforce positive amount to extend
        require(_amount > 0, "Amount must be nonzero");

        // get storage reference to account's lock data
        AccountData storage accountData = accountLockData[msg.sender];

        // get current system week
        uint256 systemWeek = getWeek();

        // calculate weight increase due to extension
        uint256 increase = (_newWeeks - _weeks) * _amount;

        // get storage reference to account's weekly unlocks
        uint32[65535] storage unlocks = accountWeeklyUnlocks[msg.sender];

        // perform weekly weight write for account and get latest weight
        uint256 weight = _weeklyWeightWrite(msg.sender);

        // update account's weekly weight for current system week
        // to include increase amount
        accountWeeklyWeights[msg.sender][systemWeek] = SafeCast.toUint40(weight + increase);

        // reduce account weekly unlock for previous week and modify bitfield
        uint256 changedWeek = systemWeek + _weeks;
        uint256 previous = unlocks[changedWeek];

        unlocks[changedWeek] = SafeCast.toUint32(previous - _amount);
        totalWeeklyUnlocks[changedWeek] -= SafeCast.toUint32(_amount);

        // if extend the total locked amount for the changed week modify bitfield
        if (previous == _amount) {
            uint256 idx = changedWeek / 256;
            uint256 bitfield = accountData.updateWeeks[idx] & ~(uint256(1) << (changedWeek % 256));
            accountData.updateWeeks[idx] = bitfield;
        }

        // increase account weekly unlock for new week and modify bitfield
        changedWeek = systemWeek + _newWeeks;
        previous = unlocks[changedWeek];

        unlocks[changedWeek] = SafeCast.toUint32(previous + _amount);
        totalWeeklyUnlocks[changedWeek] += SafeCast.toUint32(_amount);

        // if account had no locked amount for the extended week, modify the bitfield
        if (previous == 0) {
            uint256 idx = changedWeek / 256;
            uint256 bitfield = accountData.updateWeeks[idx] | (uint256(1) << (changedWeek % 256));
            accountData.updateWeeks[idx] = bitfield;
        }

        // update and modify total weight
        totalWeeklyWeights[systemWeek] = SafeCast.toUint40(getTotalWeightWrite() + increase);

        emit LockExtended(msg.sender, _amount, _weeks, _newWeeks);

        success = true;
    }

    /**
        @notice Deposit tokens into the contract to create multiple new locks.
        @param _account Address to create new locks for (does not have to be the caller)
        @param newLocks Array of [(amount, weeks), ...] where amount is the amount of
                        tokens to lock, and weeks is the number of weeks for the lock.
                        All tokens to be locked are transferred from the caller.
     */
    function lockMany(
        address _account,
        LockData[] calldata newLocks
    ) external notFrozen(_account) returns (bool success) {
        // get storage references to account lock & unlock data
        AccountData storage accountData = accountLockData[_account];
        uint32[65535] storage unlocks = accountWeeklyUnlocks[_account];

        // update account weight
        uint256 accountWeight = _weeklyWeightWrite(_account);

        // get current system week
        uint256 systemWeek = getWeek();

        // copy maybe-updated bitfield entries to memory
        uint256[2] memory bitfield = [
            accountData.updateWeeks[systemWeek / 256],
            accountData.updateWeeks[(systemWeek / 256) + 1]
        ];

        // cumulative amounts
        uint256 increasedAmount;
        uint256 increasedWeight;

        // iterate new locks and store intermediate values in memory where possible
        // note: cheaper not to cache length for calldata input
        for (uint256 i; i < newLocks.length; i++) {
            // read week into memory from calldata since it may need to be changed
            uint256 week = newLocks[i].weeksToUnlock;

            // sanity checks for positive amount, lock week min/max
            require(newLocks[i].amount > 0, "Amount must be nonzero");
            require(week > 0, "Min 1 week");
            require(week <= MAX_LOCK_WEEKS, "Exceeds MAX_LOCK_WEEKS");

            // change 1 week lock into 2 week lock if the lock occurs
            // during the final 3 days of the week
            if (week == 1 && block.timestamp % 1 weeks > 4 days) week = 2;

            // update memory cumulative amounts
            increasedAmount += newLocks[i].amount;
            increasedWeight += newLocks[i].amount * week;

            // calculate week when unlock will occur
            uint256 unlockWeek = systemWeek + week;

            // update storage account & total unlock for week when unlock will occur
            uint256 previous = unlocks[unlockWeek];

            unlocks[unlockWeek] = SafeCast.toUint32(previous + newLocks[i].amount);
            totalWeeklyUnlocks[unlockWeek] += SafeCast.toUint32(newLocks[i].amount);

            // update bitfield if future unlock week had no unlocks and now does
            if (previous == 0) {
                uint256 idx = (unlockWeek / 256) - (systemWeek / 256);
                bitfield[idx] = bitfield[idx] | (uint256(1) << (unlockWeek % 256));
            }
        }

        // write updated bitfield to storage
        accountData.updateWeeks[systemWeek / 256] = bitfield[0];
        accountData.updateWeeks[(systemWeek / 256) + 1] = bitfield[1];

        // update storage account and total weight for current system week
        accountWeeklyWeights[_account][systemWeek] = SafeCast.toUint40(accountWeight + increasedWeight);
        totalWeeklyWeights[systemWeek] = SafeCast.toUint40(getTotalWeightWrite() + increasedWeight);

        // update storage account total locked and total decay rate
        accountData.locked = SafeCast.toUint32(accountData.locked + increasedAmount);
        totalDecayRate = SafeCast.toUint32(totalDecayRate + increasedAmount);

        // finally transfer tokens being locked after all storage updates are complete
        lockToken.transferToLocker(msg.sender, increasedAmount * lockToTokenRatio);

        emit LocksCreated(_account, newLocks);

        success = true;
    }

    /**
        @notice Extend the length of multiple existing locks.
        @param newExtendLocks Array of [(amount, weeks, newWeeks), ...] where amount is the amount
                              of tokens to extend the lock for, weeks is the current number of weeks
                              for the lock that is being extended, and newWeeks is the number of weeks
                              to extend the lock until.
     */
    function extendMany(
        ExtendLockData[] calldata newExtendLocks
    ) external notFrozen(msg.sender) returns (bool success) {
        // get storage references for account lock & unlock data
        AccountData storage accountData = accountLockData[msg.sender];
        uint32[65535] storage unlocks = accountWeeklyUnlocks[msg.sender];

        // update account weight
        uint256 accountWeight = _weeklyWeightWrite(msg.sender);

        // get current system week
        uint256 systemWeek = getWeek();

        // copy maybe-updated bitfield entries to memory
        uint256[2] memory bitfield = [
            accountData.updateWeeks[systemWeek / 256],
            accountData.updateWeeks[(systemWeek / 256) + 1]
        ];

        // cumulative data
        uint256 increasedWeight;

        // iterate extended locks and store intermediate values in memory where possible
        for (uint256 i; i < newExtendLocks.length; i++) {
            uint256 oldWeeks = newExtendLocks[i].currentWeeks;
            uint256 newWeeks = newExtendLocks[i].newWeeks;

            // sanity checks for amount & week min/max
            require(oldWeeks > 0, "Min 1 week");
            require(newWeeks <= MAX_LOCK_WEEKS, "Exceeds MAX_LOCK_WEEKS");
            require(oldWeeks < newWeeks, "newWeeks must be greater than weeks");
            require(newExtendLocks[i].amount > 0, "Amount must be nonzero");

            // update memory cumulative weight increase
            increasedWeight += (newWeeks - oldWeeks) * newExtendLocks[i].amount;

            // reduce account weekly unlock for previous week and modify bitfield
            oldWeeks += systemWeek;
            uint256 previous = unlocks[oldWeeks];

            unlocks[oldWeeks] = SafeCast.toUint32(previous - newExtendLocks[i].amount);
            totalWeeklyUnlocks[oldWeeks] -= SafeCast.toUint32(newExtendLocks[i].amount);

            if (previous == newExtendLocks[i].amount) {
                uint256 idx = (oldWeeks / 256) - (systemWeek / 256);
                bitfield[idx] = bitfield[idx] & ~(uint256(1) << (oldWeeks % 256));
            }

            // increase account weekly unlock for new week and modify bitfield
            newWeeks += systemWeek;
            previous = unlocks[newWeeks];

            unlocks[newWeeks] = SafeCast.toUint32(previous + newExtendLocks[i].amount);
            totalWeeklyUnlocks[newWeeks] += SafeCast.toUint32(newExtendLocks[i].amount);

            if (previous == 0) {
                uint256 idx = (newWeeks / 256) - (systemWeek / 256);
                bitfield[idx] = bitfield[idx] | (uint256(1) << (newWeeks % 256));
            }
        }

        // write updated bitfield to storage
        accountData.updateWeeks[systemWeek / 256] = bitfield[0];
        accountData.updateWeeks[(systemWeek / 256) + 1] = bitfield[1];

        // update storage account and total weight for current system week
        accountWeeklyWeights[msg.sender][systemWeek] = SafeCast.toUint40(accountWeight + increasedWeight);
        totalWeeklyWeights[systemWeek] = SafeCast.toUint40(getTotalWeightWrite() + increasedWeight);

        emit LocksExtended(msg.sender, newExtendLocks);

        success = true;
    }

    /**
        @notice Freeze all locks for the caller
        @dev When an account's locks are frozen, the weeks-to-unlock does not decay.
             All other functionality remains the same; the account can continue to lock,
             extend locks, and withdraw tokens. Freezing greatly reduces gas costs for
             actions such as emissions voting.
     */
    function freeze() external notFrozen(msg.sender) {
        // get storage references for account lock & unlock data
        AccountData storage accountData = accountLockData[msg.sender];
        uint32[65535] storage unlocks = accountWeeklyUnlocks[msg.sender];

        // trigger account & total weekly writes, get fresh weights
        uint256 accountWeight = _weeklyWeightWrite(msg.sender);
        uint256 totalWeight = getTotalWeightWrite();

        // can only freeze an account with locked tokens
        uint32 locked = accountData.locked;
        require(locked > 0, "No locked balance");

        // remove account locked balance from the total decay rate
        totalDecayRate -= locked;

        // update storage account frozen balance and reset locked balance
        accountData.frozen = locked;
        accountData.locked = 0;

        // get current system week
        uint256 systemWeek = getWeek();

        // update storage account and total weight for current system week
        accountWeeklyWeights[msg.sender][systemWeek] = SafeCast.toUint40(locked * MAX_LOCK_WEEKS);
        totalWeeklyWeights[systemWeek] = SafeCast.toUint40(totalWeight - accountWeight + locked * MAX_LOCK_WEEKS);

        // emit event first as locked will be decreased in the while loop
        emit LocksFrozen(msg.sender, locked);

        // use bitfield to iterate acount unlocks and subtract them from the total unlocks
        uint256 bitfield = accountData.updateWeeks[systemWeek / 256] >> (systemWeek % 256);
        while (locked > 0) {
            systemWeek++;
            if (systemWeek % 256 == 0) {
                bitfield = accountData.updateWeeks[systemWeek / 256];
                accountData.updateWeeks[(systemWeek / 256) - 1] = 0;
            } else {
                bitfield = bitfield >> 1;
            }
            if (bitfield & uint256(1) == 1) {
                uint32 amount = unlocks[systemWeek];
                unlocks[systemWeek] = 0;
                totalWeeklyUnlocks[systemWeek] -= amount;
                locked -= amount;
            }
        }
        accountData.updateWeeks[systemWeek / 256] = 0;
    }

    /**
        @notice Unfreeze all locks for the caller
        @dev When an account's locks are unfrozen, the weeks-to-unlock decay normally.
             This is the default locking behaviour for each account. Unfreezing locks
             also updates the frozen status within `IncentiveVoter` - otherwise it could be
             possible for accounts to have a larger registered vote weight than their actual
             lock weight.
        @param keepIncentivesVote If true, existing incentive votes are preserved when updating
                                  the frozen status within `IncentiveVoter`. Voting with unfrozen
                                  weight uses significantly more gas than voting with frozen weight.
                                  If the caller has many active locks and/or many votes, it will be
                                  much cheaper to set this value to false.

     */
    function unfreeze(bool keepIncentivesVote) external {
        // get storage references for account lock & unlock data
        AccountData storage accountData = accountLockData[msg.sender];
        uint32[65535] storage unlocks = accountWeeklyUnlocks[msg.sender];

        // revert if nothing to unfreeze
        uint32 frozen = accountData.frozen;
        require(frozen > 0, "Locks already unfrozen");

        // unfreeze the caller's registered vote weights
        incentiveVoter.unfreeze(msg.sender, keepIncentivesVote);

        // trigger account & total weekly writes
        _weeklyWeightWrite(msg.sender);
        getTotalWeightWrite();

        // add account frozen balance to the total decay rate
        totalDecayRate += frozen;

        // update storage account locked balance and reset frozen balance
        accountData.locked = frozen;
        accountData.frozen = 0;

        // get current system week
        uint256 systemWeek = getWeek();

        // calculate locked week as always max lock time
        uint256 unlockWeek = systemWeek + MAX_LOCK_WEEKS;

        // account unlocks in unlock week set to frozen amount
        unlocks[unlockWeek] = frozen;

        // total unlocks in unlock week increased by frozen amount
        totalWeeklyUnlocks[unlockWeek] += frozen;

        // note: no changes required to totalWeeklyWeights and accountWeeklyWeights
        // since a freeze is equivalent to a max length lock and unfreezing
        // effectively creates a max length lock

        // modify bitfield
        uint256 idx = unlockWeek / 256;
        uint256 bitfield = accountData.updateWeeks[idx] | (uint256(1) << (unlockWeek % 256));
        accountData.updateWeeks[idx] = bitfield;

        emit LocksUnfrozen(msg.sender, frozen);
    }

    /**
        @notice Withdraw tokens from locks that have expired
        @param _weeks Optional number of weeks for the re-locking.
                      If 0 the full amount is transferred back to the user.

     */
    function withdrawExpiredLocks(uint256 _weeks) external returns (bool success) {
        // trigger account & total weekly writes
        _weeklyWeightWrite(msg.sender);
        getTotalWeightWrite();

        // get storage references for account lock data
        AccountData storage accountData = accountLockData[msg.sender];

        // revert if account has no unlocked balance
        uint256 unlocked = accountData.unlocked;
        require(unlocked > 0, "No unlocked tokens");

        // update storage reset account unlocked balance
        accountData.unlocked = 0;

        // either re-lock or send user their unlocked tokens
        if (_weeks > 0) {
            _lock(msg.sender, unlocked, _weeks);
        } else {
            lockToken.transfer(msg.sender, unlocked * lockToTokenRatio);

            emit LocksWithdrawn(msg.sender, unlocked, 0);
        }
        success = true;
    }

    /**
        @notice Pay a penalty to withdraw locked tokens
        @dev Withdrawals are processed starting with the lock that will expire soonest.
             The penalty starts at 100% and decays linearly based on the number of weeks
             remaining until the tokens unlock. The exact calculation used is:

             [total amount] * [weeks to unlock] / MAX_LOCK_WEEKS = [penalty amount]

        @param amountToWithdraw Amount to withdraw, divided by `lockToTokenRatio`. This
                                is the same number of tokens that will be received; the
                                penalty amount is taken on top of this. Reverts if the
                                caller's locked balances are insufficient to cover both
                                the withdrawal and penalty amounts. Setting this value as
                                `type(uint256).max` withdrawals the entire available locked
                                balance, excluding any lock at `MAX_LOCK_WEEKS` as the
                                penalty on this lock would be 100%.
        @return output uint256 Amount of tokens withdrawn
     */
    function withdrawWithPenalty(uint256 amountToWithdraw) external notFrozen(msg.sender) returns (uint256 output) {
        // penalty withdrawals must be enabled by admin
        require(penaltyWithdrawalsEnabled, "Penalty withdrawals are disabled");

        // revert on zero input
        require(amountToWithdraw != 0, "Must withdraw a positive amount");

        // get storage reference to user's account
        AccountData storage accountData = accountLockData[msg.sender];

        // trigger weekly account weight update before processing this call
        uint256 weight = _weeklyWeightWrite(msg.sender);

        // scale up both amount to withdraw and unlocked amount by lockToTokenRatio
        if (amountToWithdraw != type(uint256).max) amountToWithdraw *= lockToTokenRatio;
        uint256 unlocked = accountData.unlocked * lockToTokenRatio;

        // if user has enough unlocked to cover the withdraw, then there is no penalty
        if (unlocked >= amountToWithdraw) {
            // update user's unlocked storage to deduct withdrawn amount
            accountData.unlocked = SafeCast.toUint32((unlocked - amountToWithdraw) / lockToTokenRatio);

            // send user the tokens
            lockToken.transfer(msg.sender, amountToWithdraw);

            // stop function execution here returning withdrawn amount
            return amountToWithdraw;
        }

        // if execution reaches here user doesn't have enough unlocked to
        // cover the amount they want to withdraw

        // clear the caller's registered vote weight
        incentiveVoter.clearRegisteredWeight(msg.sender);

        // make a copy of the scaled up withdraw amount
        uint256 remaining = amountToWithdraw;

        // if user has some unlocked tokens, deduct them from the
        // remaining amount and reset user's unlocked - this way no
        // penalty is applied on the unlocked amount
        if (unlocked > 0) {
            remaining -= unlocked;
            accountData.unlocked = 0;
        }

        uint256 systemWeek = getWeek();
        uint256 bitfield = accountData.updateWeeks[systemWeek / 256];
        uint256 penaltyTotal;
        uint256 decreasedWeight;

        // `weeksToUnlock < MAX_LOCK_WEEKS` stops iteration prior to the final week
        for (uint256 weeksToUnlock = 1; weeksToUnlock < MAX_LOCK_WEEKS; weeksToUnlock++) {
            systemWeek++;
            if (systemWeek % 256 == 0) {
                accountData.updateWeeks[systemWeek / 256 - 1] = 0;
                bitfield = accountData.updateWeeks[systemWeek / 256];
            }

            if ((bitfield >> (systemWeek % 256)) & uint256(1) == 1) {
                // get amount locked for given week scaled up by lockToTokenRatio
                uint256 lockAmount = accountWeeklyUnlocks[msg.sender][systemWeek] * lockToTokenRatio;

                // calculate penalty such the longer the amount of weeks left before
                // the tokens are unlocked, the greater amount of penalty. this first
                // penalty calculation uses entire locked amount
                uint256 penaltyOnAmount = (lockAmount * weeksToUnlock) / MAX_LOCK_WEEKS;

                // if after deducting the penalty from the locked amount the result is
                // greater than the remaining amount the user wishes to withdraw
                if (lockAmount - penaltyOnAmount > remaining) {
                    // then recalculate the penalty using only the portion of the lock
                    // amount that will be withdrawn
                    penaltyOnAmount = (remaining * MAX_LOCK_WEEKS) / (MAX_LOCK_WEEKS - weeksToUnlock) - remaining;

                    // add any dust to the penalty amount
                    uint256 dust = ((penaltyOnAmount + remaining) % lockToTokenRatio);
                    if (dust > 0) penaltyOnAmount += lockToTokenRatio - dust;

                    // update memory total penalty
                    penaltyTotal += penaltyOnAmount;

                    // calculate amount to reduce lock as penalty + withdrawn amount,
                    // scaled down by lockToTokenRatio as those values were prev scaled up by this
                    uint256 lockReduceAmount = (penaltyOnAmount + remaining) / lockToTokenRatio;

                    // update memory total voting weight reduction
                    decreasedWeight += lockReduceAmount * weeksToUnlock;

                    // update storage to decrease week's future unlocks
                    accountWeeklyUnlocks[msg.sender][systemWeek] -= SafeCast.toUint32(lockReduceAmount);
                    totalWeeklyUnlocks[systemWeek] -= SafeCast.toUint32(lockReduceAmount);

                    // if after dust handling user has no remaining tokens locked
                    // then reset the bitfield
                    if (accountWeeklyUnlocks[msg.sender][systemWeek] == 0) {
                        bitfield = bitfield & ~(uint256(1) << (systemWeek % 256));
                    }

                    // nothing remaining to be withdrawn
                    remaining = 0;
                }
                // otherwise use entire locked amount to service the withdrawal
                else {
                    // update memory total penalty
                    penaltyTotal += penaltyOnAmount;

                    // update memory total voting weight reduction
                    decreasedWeight += (lockAmount / lockToTokenRatio) * weeksToUnlock;

                    bitfield = bitfield & ~(uint256(1) << (systemWeek % 256));

                    // update storage to decrease week's future unlocks
                    accountWeeklyUnlocks[msg.sender][systemWeek] = 0;
                    totalWeeklyUnlocks[systemWeek] -= SafeCast.toUint32(lockAmount / lockToTokenRatio);

                    // adjust remaining amount by net amount withdraw after penalty incurred
                    remaining -= lockAmount - penaltyOnAmount;
                }

                // exit loop if amount to be withdrawn satisfied
                if (remaining == 0) {
                    break;
                }
            }
        }

        accountData.updateWeeks[systemWeek / 256] = bitfield;

        // if users tried to withdraw as much as possible, then subtract
        // the "unfilled" net amount (not inc penalties) from the user input
        // which gives the "filled" amount (not inc penalties)
        if (amountToWithdraw == type(uint256).max) {
            amountToWithdraw -= remaining;

            // revert if nothing was withdrawn, eg if user had no locked
            // tokens but attempted withdraw with input type(uint256).max
            require(amountToWithdraw != 0, "Must withdraw a positive amount");
        }
        // otherwise if user tried to withdraw a specific amount, revert if
        // it was impossible to fill that exact amount
        else {
            require(remaining == 0, "Insufficient balance after fees");
        }

        // calculate & cache total amount of locked tokens withdraw inc penalties,
        // scaled down by lockToTokenRatio
        uint32 lockedPlusPenalties = SafeCast.toUint32((amountToWithdraw + penaltyTotal - unlocked) / lockToTokenRatio);

        // update account locked and global totalDecayRate subtracting
        // locked tokens withdrawn including penalties paid
        accountData.locked -= lockedPlusPenalties;

        // update account and global weights subtracting decreased weights
        systemWeek = getWeek();
        accountWeeklyWeights[msg.sender][systemWeek] = SafeCast.toUint40(weight - decreasedWeight);
        totalWeeklyWeights[systemWeek] = SafeCast.toUint40(getTotalWeightWrite() - decreasedWeight);

        totalDecayRate -= lockedPlusPenalties;

        // send the withdraw tokens and pay penalty fees
        lockToken.transfer(msg.sender, amountToWithdraw);
        lockToken.transfer(bimaCore.feeReceiver(), penaltyTotal);
        emit LocksWithdrawn(msg.sender, amountToWithdraw, penaltyTotal);

        output = amountToWithdraw;
    }

    /**
        @dev Updates all data for a given account and returns the account's current weight and week
     */
    function _weeklyWeightWrite(address account) internal returns (uint256 weight) {
        // get storage references to account lock, unlock & weight data
        AccountData storage accountData = accountLockData[account];
        uint32[65535] storage weeklyUnlocks = accountWeeklyUnlocks[account];
        uint40[65535] storage weeklyWeights = accountWeeklyWeights[account];

        // get current system week
        uint256 systemWeek = getWeek();

        // cache current account week
        uint256 accountWeek = accountData.week;

        // output account weight from last processed account week
        weight = weeklyWeights[accountWeek];

        // if the last processed account week is this week
        // then return as nothing else to do
        if (accountWeek != systemWeek) {
            // if account is frozen
            if (accountData.frozen > 0) {
                // then iterate through every week until current one,
                // setting the account's weight for every week to their
                // frozen weight amount
                while (systemWeek > accountWeek) {
                    accountWeek++;
                    weeklyWeights[accountWeek] = SafeCast.toUint40(weight);
                }

                // then update the account's processed week to current
                // and return as nothing else to do
                accountData.week = SafeCast.toUint16(systemWeek);
                return weight;
            }

            // if account is not frozen and locked balance is 0
            // we only need to update the account week then return 0
            // since nothing locked means no weight
            uint32 locked = accountData.locked;

            if (locked == 0) {
                if (accountWeek < systemWeek) {
                    accountData.week = SafeCast.toUint16(systemWeek);
                }
                return 0;
            }

            // otherwise account is not frozen and has tokens locked
            uint32 unlocked;
            uint256 bitfield = accountData.updateWeeks[accountWeek / 256] >> (accountWeek % 256);

            // iterate through every week until current one
            while (accountWeek < systemWeek) {
                accountWeek++;

                // deduct locked tokens from account weight
                weight -= locked;

                // update storage for account's weekly weight
                weeklyWeights[accountWeek] = SafeCast.toUint40(weight);

                if (accountWeek % 256 == 0) {
                    bitfield = accountData.updateWeeks[accountWeek / 256];
                } else {
                    bitfield = bitfield >> 1;
                }
                if (bitfield & uint256(1) == 1) {
                    // as unlocks happen, modify the locked/unlocked
                    // memory variables for each week
                    uint32 amount = weeklyUnlocks[accountWeek];

                    locked -= amount;
                    unlocked += amount;

                    if (locked == 0) {
                        // if locked balance hits 0, there are no further tokens to unlock
                        accountWeek = systemWeek;
                        break;
                    }
                }
            }

            // finally the account has processed all missing weeks
            // up to the current system week, so update storage to record
            // new unlocked, locked values and system week as latest processed week
            accountData.unlocked = accountData.unlocked + unlocked;
            accountData.locked = locked;
            accountData.week = SafeCast.toUint16(accountWeek);
        }
    }
}
