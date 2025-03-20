// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DelegatedOps} from "../dependencies/DelegatedOps.sol";
import {BimaOwnable} from "../dependencies/BimaOwnable.sol";
import {ITokenLocker} from "../interfaces/ITokenLocker.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title Vesting contract for team and investors
 * @author BimaFi
 * @notice Vesting contract which allows transfer of future vesting claims
 */
contract AllocationVesting is DelegatedOps, Ownable {
    error NothingToClaim();
    error CannotLock();
    error WrongMaxTotalPreclaimPct();
    error PreclaimTooLarge();
    error AllocationsMismatch();
    error ZeroTotalAllocation();
    error ZeroAllocation();
    error ZeroNumberOfWeeks();
    error DuplicateAllocation();
    error InsufficientPoints();
    error LockedAllocation();
    error IllegalVestingStart();
    error VestingAlreadyStarted();
    error SelfTransfer();
    error IncompatibleVestingPeriod(uint256 numberOfWeeksFrom, uint256 numberOfWeeksTo);
    error PositivePreclaimButZeroTransfer();

    struct AllocationSplit {
        address recipient;
        uint24 points;
        uint8 numberOfWeeks;
    }

    struct AllocationState {
        uint24 points;
        uint8 numberOfWeeks;
        uint128 claimed;
        uint96 preclaimed;
    }

    // This number should allow a good precision in allocation fractions
    uint24 private constant TOTAL_POINTS = 100000;
    // used as denominator for preclaim % calculations
    uint256 private constant TOTAL_PRECLAIM = 100;
    // Users allocations
    mapping(address recipient => AllocationState) public allocations;
    // max percentage of one's vest that can be preclaimed in total
    uint256 public immutable maxTotalPreclaimPct;
    // Total allocation expressed in tokens
    uint256 public immutable totalAllocation;
    IERC20 public immutable vestingToken;
    address public immutable vault;
    ITokenLocker public immutable tokenLocker;
    uint256 public immutable lockToTokenRatio;
    // Vesting timeline starting timestamp
    uint256 public vestingStart;

    constructor(
        IERC20 vestingToken_,
        ITokenLocker tokenLocker_,
        uint256 totalAllocation_,
        address vault_,
        uint256 maxTotalPreclaimPct_
    ) {
        if (totalAllocation_ == 0) revert ZeroTotalAllocation();
        if (maxTotalPreclaimPct_ > 20) revert WrongMaxTotalPreclaimPct();
        vault = vault_;
        tokenLocker = tokenLocker_;
        vestingToken = vestingToken_;
        totalAllocation = totalAllocation_;
        lockToTokenRatio = tokenLocker_.lockToTokenRatio();
        maxTotalPreclaimPct = maxTotalPreclaimPct_;
    }

    /**
     *
     * @notice Returns claimed amount
     * @param account account to check
     */
    function getClaimed(address account) external view returns (uint256 claimed) {
        claimed = allocations[account].claimed;
    }

    /**
     *
     * @notice Set allocations and starts vesting
     * @param allocationSplits Allocations to be set
     * @param vestingStart_ Start of the vesting timeline
     * @dev This can be called only once by the owner
     */
    function setAllocations(AllocationSplit[] calldata allocationSplits, uint256 vestingStart_) external onlyOwner {
        // enforce vesting start in the future but not more than 5 weeks
        if (vestingStart_ < block.timestamp || block.timestamp + 5 weeks < vestingStart_) revert IllegalVestingStart();

        // can only start vesting once
        if (vestingStart != 0) revert VestingAlreadyStarted();

        // update storage with vesting start time
        vestingStart = vestingStart_;

        // cumulative data
        uint24 totalPoints;

        // more efficient to not cache loop length since calldata
        for (uint256 i; i < allocationSplits.length; ) {
            address recipient = allocationSplits[i].recipient;
            uint8 numberOfWeeks = allocationSplits[i].numberOfWeeks;
            uint24 points = allocationSplits[i].points;

            // sanity checks on allocation inputs
            if (points == 0) revert ZeroAllocation();
            if (numberOfWeeks == 0) revert ZeroNumberOfWeeks();
            if (allocations[recipient].numberOfWeeks > 0) revert DuplicateAllocation();

            // update memory cumulative points
            totalPoints += points;

            // set allocation state for recipient
            allocations[recipient].points = points;
            allocations[recipient].numberOfWeeks = numberOfWeeks;

            unchecked {
                ++i;
            }
        }

        // sanity check to ensure complete allocation
        if (totalPoints != TOTAL_POINTS) revert AllocationsMismatch();
    }

    /**
     * @notice Claims accrued tokens for initiator and transfers a number of allocation points to a recipient
     * @dev Can be delegated
     * @param from Initiator
     * @param to Recipient
     * @param points Number of points to transfer
     */
    function transferPoints(address from, address to, uint24 points) external callerOrDelegated(from) {
        // revert on self-transfer to prevent infinite points exploit
        if (from == to) revert SelfTransfer();

        // revert on zero points input
        if (points == 0) revert ZeroAllocation();

        // cache allocation state of `from` and `to` addresses
        AllocationState memory fromAllocation = allocations[from];
        AllocationState memory toAllocation = allocations[to];

        // revert if `from` has less points allocation than they are
        // trying to transfer
        if (fromAllocation.points < points) revert InsufficientPoints();

        // enforce identical vesting periods if `to` has an active vesting period
        if (toAllocation.numberOfWeeks != 0 && toAllocation.numberOfWeeks != fromAllocation.numberOfWeeks)
            revert IncompatibleVestingPeriod(fromAllocation.numberOfWeeks, toAllocation.numberOfWeeks);

        // get points currently vested for `from` address
        uint256 totalVested = _vestedAt(block.timestamp, fromAllocation.points, fromAllocation.numberOfWeeks);

        // revert if `from` has claimed more than they've vested
        // since then `from` has no points to transfer
        if (totalVested < fromAllocation.claimed) revert LockedAllocation();

        // claim one last time before transfer
        uint256 claimed = _claim(from, fromAllocation.points, fromAllocation.claimed, fromAllocation.numberOfWeeks);

        // passive balance to transfer
        uint128 claimedAdjustment = SafeCast.toUint128((claimed * points) / fromAllocation.points);

        // update storage - if `from` has a positive preclaimed balance,
        // transfer preclaimed amount in proportion to points tranferred
        // to prevent point transfers being used to bypass the maximum preclaim limit
        if (fromAllocation.preclaimed > 0) {
            uint96 preclaimedToTransfer = SafeCast.toUint96(
                (uint256(fromAllocation.preclaimed) * points) / fromAllocation.points
            );

            // this should never happen but sneaky users may try to preclaiming and
            // point transferring using very small amounts so prevent this
            if (preclaimedToTransfer == 0) revert PositivePreclaimButZeroTransfer();

            allocations[to].preclaimed = toAllocation.preclaimed + preclaimedToTransfer;
            allocations[from].preclaimed = fromAllocation.preclaimed - preclaimedToTransfer;
        }

        // update storage - deduct points from `from` using memory cache
        allocations[from].points = fromAllocation.points - points;

        // we don't use fromAllocation as it's been modified with _claim()
        allocations[from].claimed = allocations[from].claimed - claimedAdjustment;

        // update storage - increase points to `to` using memory cache
        // self-transfer prevented at start of the function so this is safe
        allocations[to].points = toAllocation.points + points;

        // update storage - increase `to` for claim adjustment
        allocations[to].claimed = toAllocation.claimed + claimedAdjustment;

        // if `to` had no active vesting period, copy from `from`
        if (toAllocation.numberOfWeeks == 0) {
            allocations[to].numberOfWeeks = fromAllocation.numberOfWeeks;
        }
    }

    /**
     * @notice Lock future claimable tokens tokens
     * @dev Can be delegated
     * @param account Account to lock for
     * @param amount Amount to preclaim
     */
    function lockFutureClaims(address account, uint256 amount) external callerOrDelegated(account) {
        lockFutureClaimsWithReceiver(account, account, amount);
    }

    /**
     * @notice Lock future claimable tokens. This function allows entities
     * who receive token allocations to get voting power by locking their
     * future claims
     * @dev Can be delegated
     * @param account Account to lock for
     * @param receiver Receiver of the lock
     * @param amount Amount to preclaim. If 0 the maximum allowed will be locked
     */
    function lockFutureClaimsWithReceiver(
        address account,
        address receiver,
        uint256 amount
    ) public callerOrDelegated(account) {
        // cache allocation state of account
        AllocationState memory allocation = allocations[account];

        // revert if account has no points or vesting hasn't started
        if (allocation.points == 0 || vestingStart == 0) revert CannotLock();

        // copy currently claimed amount
        uint256 claimedUpdated = allocation.claimed;

        // claim prior to locking if possible
        if (_claimableAt(block.timestamp, allocation.points, allocation.claimed, allocation.numberOfWeeks) > 0) {
            claimedUpdated = _claim(account, allocation.points, allocation.claimed, allocation.numberOfWeeks);
        }

        // calculate user share of allocation
        uint256 userAllocation = (allocation.points * totalAllocation) / TOTAL_POINTS;

        // calculate unclaimed amount accounting for possible claim that just happened
        uint256 _unclaimed = userAllocation - claimedUpdated;

        // copy user preclaim amount
        uint256 preclaimed = allocation.preclaimed;

        // calculate max user can preclaim from their allocation
        uint256 maxTotalPreclaim = (maxTotalPreclaimPct * userAllocation) / TOTAL_PRECLAIM;

        // calculate how much remaining user can preclaim
        uint256 leftToPreclaim = maxTotalPreclaim - preclaimed;

        // if input amount 0, use min(leftToPreclaim, _unclaimed)
        if (amount == 0)
            amount = leftToPreclaim > _unclaimed ? _unclaimed : leftToPreclaim;

            // otherwise revert if attempting to preclaim more than max preclaimed or remaining unclaimed
        else if (preclaimed + amount > maxTotalPreclaim || amount > _unclaimed) revert PreclaimTooLarge();

        // truncate any dust
        amount = (amount / lockToTokenRatio) * lockToTokenRatio;

        // update storage account claimed & preclaimed amounts
        allocations[account].claimed = SafeCast.toUint128(claimedUpdated + amount);
        allocations[account].preclaimed = SafeCast.toUint96(preclaimed + amount);

        // transfer tokens from vault into this contract
        vestingToken.transferFrom(vault, address(this), amount);

        // lock the tokens in the TokenLocker for max length
        tokenLocker.lock(receiver, amount / lockToTokenRatio, tokenLocker.MAX_LOCK_WEEKS());
    }

    /**
     *
     * @notice Claims accrued tokens
     * @dev Can be delegated
     * @param account Account to claim for
     */
    function claim(address account) external callerOrDelegated(account) {
        AllocationState memory allocation = allocations[account];
        _claim(account, allocation.points, allocation.claimed, allocation.numberOfWeeks);
    }

    // This function exists to avoid reloading the AllocationState struct in memory
    function _claim(
        address account,
        uint256 points,
        uint256 claimed,
        uint256 numberOfWeeks
    ) private returns (uint256 claimedUpdated) {
        // revert if nothing to claim
        if (points == 0) revert NothingToClaim();

        uint256 claimable = _claimableAt(block.timestamp, points, claimed, numberOfWeeks);
        if (claimable == 0) revert NothingToClaim();

        // output updated account claimed amount
        claimedUpdated = claimed + claimable;

        // update storage claimed amount
        allocations[account].claimed = SafeCast.toUint128(claimedUpdated);

        // transfer tokens from vault to the sender
        // note: it is intentional that if claim() is called by a delegate,
        // the tokens will be sent to the delegate instead of the account
        vestingToken.transferFrom(vault, msg.sender, claimable);
    }

    /**
     * @notice Calculates number of tokens claimable by the user at the current block
     * @param account Account to calculate for
     * @return claimable Accrued tokens
     */
    function claimableNow(address account) external view returns (uint256 claimable) {
        AllocationState memory allocation = allocations[account];
        claimable = _claimableAt(block.timestamp, allocation.points, allocation.claimed, allocation.numberOfWeeks);
    }

    function _claimableAt(
        uint256 when,
        uint256 points,
        uint256 claimed,
        uint256 numberOfWeeks
    ) private view returns (uint256 claimable) {
        uint256 totalVested = _vestedAt(when, points, numberOfWeeks);

        // tokens are only claimable if the total vested amount
        // is greater than the already claimed amount
        claimable = totalVested > claimed ? totalVested - claimed : 0;
    }

    function _vestedAt(uint256 when, uint256 points, uint256 numberOfWeeks) private view returns (uint256 vested) {
        // cache vesting start time into memory saving 2 redundant storage reads
        uint256 vestingStartCache = vestingStart;

        // revert if vesting hasn't started or account has no vesting period
        if (vestingStartCache == 0 || numberOfWeeks == 0) return 0;

        // convert vesting weeks into timestamp
        uint256 vestingWeeks = numberOfWeeks * 1 weeks;

        // calculate vesting end time as a timestamp
        uint256 vestingEnd = vestingStartCache + vestingWeeks;

        // end time for vesting calculation = min(when, vestingEnd)
        // this prevents incorrectly giving more tokens if called
        // prior to or after vestingEnd
        uint256 endTime = when >= vestingEnd ? vestingEnd : when;

        // calculate how much time has elapsed for the vesting calculation
        uint256 timeSinceStart = endTime - vestingStartCache;

        // finally perform the vesting calculation
        vested = (totalAllocation * timeSinceStart * points) / (TOTAL_POINTS * vestingWeeks);
    }

    /**
     * @notice Calculates the total number of tokens left unclaimed by the user including unvested ones
     * @param account Account to calculate for
     * @return accountUnclaimed tokens
     */
    function unclaimed(address account) external view returns (uint256 accountUnclaimed) {
        AllocationState memory allocation = allocations[account];

        // calculate account's total token allocation
        uint256 accountAllocation = (totalAllocation * allocation.points) / TOTAL_POINTS;

        // unclaimed amount is account allocation minus what they've already claimed
        accountUnclaimed = accountAllocation - allocation.claimed;
    }

    /**
     * @notice Calculates the total number of tokens left to preclaim
     * @param account Account to calculate for
     * @return accountPreclaimable tokens
     */
    function preclaimable(address account) external view returns (uint256 accountPreclaimable) {
        AllocationState memory allocation = allocations[account];

        // if account has no points or vesting hasn't started,
        // nothing can be preclaimed
        if (allocation.points == 0 || vestingStart == 0) {
            accountPreclaimable = 0;
        } else {
            // calculate account's total token allocation
            uint256 accountAllocation = (totalAllocation * allocation.points) / TOTAL_POINTS;

            // calculate max user can preclaim from their allocation
            uint256 maxTotalPreclaim = (maxTotalPreclaimPct * accountAllocation) / TOTAL_PRECLAIM;

            // return max user can preclaim minus what user has already preclaimed
            accountPreclaimable = maxTotalPreclaim - allocation.preclaimed;
        }
    }
}
