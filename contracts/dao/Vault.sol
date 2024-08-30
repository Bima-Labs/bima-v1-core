// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BabelOwnable} from "../dependencies/BabelOwnable.sol";
import {SystemStart} from "../dependencies/SystemStart.sol";
import {IBabelVault, ITokenLocker, IBabelToken, IIncentiveVoting, IEmissionSchedule, IBoostDelegate, IBoostCalculator, IRewards, IERC20} from "../interfaces/IVault.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

interface IEmissionReceiver {
    function notifyRegisteredId(uint256[] memory assignedIds) external returns (bool);
}

/**
    @title Babel Vault
    @notice The total supply of BABEL is initially minted to this contract.
            The token balance held here can be considered "uncirculating". The
            vault gradually releases tokens to registered emissions receivers
            as determined by `EmissionSchedule` and `BoostCalculator`.
 */
contract BabelVault is IBabelVault, BabelOwnable, SystemStart {
    using Address for address;
    using SafeERC20 for IERC20;

    IBabelToken public immutable babelToken;
    ITokenLocker public immutable locker;
    IIncentiveVoting public immutable voter;
    address public immutable deploymentManager;
    uint256 public immutable lockToTokenRatio;

    IEmissionSchedule public emissionSchedule;
    IBoostCalculator public boostCalculator;

    // `babelToken` balance within the treasury that is not yet allocated.
    // Starts as `babelToken.totalSupply()` and decreases over time.
    uint128 public unallocatedTotal;
    // most recent week that `unallocatedTotal` was reduced by a call to
    // `emissionSchedule.getTotalWeeklyEmissions`
    uint64 public totalUpdateWeek;
    // number of weeks that BABEL is locked for when transferred using
    // `transferAllocatedTokens`. updated weekly by the emission schedule.
    uint64 public lockWeeks;

    // id -> receiver data
    // not bi-directional, one receiver can have multiple ids
    mapping(uint256 receiverId => Receiver receiverData) public idToReceiver;

    // week -> total amount of tokens to be released in that week
    uint128[65535] public weeklyEmissions;

    // receiver -> remaining tokens which have been allocated but not yet distributed
    mapping(address receiver => uint256 remainingAllocated) public allocated;

    // account -> week -> BABEL amount claimed in that week (used for calculating boost)
    mapping(address account => uint128[65535] weeklyEarned) accountWeeklyEarned;

    // pending rewards for an address (dust after locking, fees from delegation)
    mapping(address account => uint256 pendingRewards) private storedPendingReward;

    mapping(address account => Delegation delegationData) public boostDelegation;

    struct Receiver {
        address account;
        bool isActive;
        uint16 updatedWeek;
    }

    struct Delegation {
        bool isEnabled;
        uint16 feePct;
        IBoostDelegate callback;
    }

    constructor(
        address _babelCore,
        IBabelToken _token,
        ITokenLocker _locker,
        IIncentiveVoting _voter,
        address _stabilityPool,
        address _manager
    ) BabelOwnable(_babelCore) SystemStart(_babelCore) {
        babelToken = _token;
        locker = _locker;
        voter = _voter;
        lockToTokenRatio = _locker.lockToTokenRatio();
        deploymentManager = _manager;

        // ensure the stability pool is registered with receiver ID 0
        uint256 id = _voter.registerNewReceiver();
        require(id == 0, "Stability pool must have receiver ID 0");

        idToReceiver[id] = Receiver({ account: _stabilityPool,
                                      isActive: true,
                                      updatedWeek: 0 });
        emit NewReceiverRegistered(_stabilityPool, id);
    }

    function setInitialParameters(
        IEmissionSchedule _emissionSchedule,
        IBoostCalculator _boostCalculator,
        uint256 totalSupply,
        uint64 initialLockWeeks,
        uint128[] calldata _fixedInitialAmounts,
        InitialAllowance[] calldata initialAllowances
    ) external {
        // enforce invariant described in TokenLocker to prevent overflows
        require(totalSupply <= type(uint32).max * locker.lockToTokenRatio(), 
                "Total supply must be <= type(uint32).max * lockToTokenRatio");

        // only deployment manager can set initial parameters
        require(msg.sender == deploymentManager, "!deploymentManager");

        emissionSchedule = _emissionSchedule;
        boostCalculator = _boostCalculator;

        // mint totalSupply to vault - this reverts after the first call
        babelToken.mintToVault(totalSupply);

        // working data
        uint256 totalAllocated;

        // get one week after current system week
        uint256 offset = getWeek() + 1;

        // set initial fixed weekly emissions, starting in the future
        // from next system week
        for (uint256 i; i < _fixedInitialAmounts.length; i++) {
            // update storage
            weeklyEmissions[i + offset] = _fixedInitialAmounts[i];

            // update working data
            totalAllocated += _fixedInitialAmounts[i];
        }

        // set initial transfer allowances for airdrops, vests, bribes
        for (uint256 i; i < initialAllowances.length; i++) {
            // initial allocations are given as approvals
            babelToken.increaseAllowance(initialAllowances[i].receiver, initialAllowances[i].amount);

            // update working data
            totalAllocated += initialAllowances[i].amount;
        }

        // cache here to save 1 storage read when emitting event
        uint128 unallocatedAmount = SafeCast.toUint128(totalSupply - totalAllocated);

        // update storage
        unallocatedTotal = unallocatedAmount;
        totalUpdateWeek = SafeCast.toUint64(_fixedInitialAmounts.length + offset - 1);
        lockWeeks = initialLockWeeks;

        emit EmissionScheduleSet(address(_emissionSchedule));
        emit BoostCalculatorSet(address(_boostCalculator));
        emit UnallocatedSupplyReduced(totalAllocated, unallocatedAmount);
    }

    /**
        @notice Register a new emission receiver
        @dev Once this function is called, the receiver ID is immediately
             eligible for votes within `IncentiveVoting`
        @param receiver Address of the receiver
        @param count Number of IDs to assign to the receiver
     */
    function registerReceiver(address receiver, uint256 count) external onlyOwner returns (bool success) {
        // allocate memory to save created receiver ids
        uint256[] memory assignedIds = new uint256[](count);

        // get current system week
        uint16 week = SafeCast.toUint16(getWeek());

        for (uint256 i; i < count; i++) {
            // register new id with IncentiveVoting
            uint256 id = voter.registerNewReceiver();

            // save new id to assigned ids
            assignedIds[i] = id;

            // set receiver data for new receiver id
            idToReceiver[id] = Receiver({ account: receiver,
                                          isActive: true,
                                          updatedWeek: week });

            emit NewReceiverRegistered(receiver, id);
        }

        // notify the receiver contract of the newly registered ID
        // also serves as a sanity check to ensure the contract
        // is capable of receiving emissions
        IEmissionReceiver(receiver).notifyRegisteredId(assignedIds);

        success = true;
    }

    /**
        @notice Modify the active status of an existing receiver
        @dev Emissions directed to an inactive receiver are instead returned to
             the unallocated supply. This way potential emissions are not lost
             due to old emissions votes pointing at a receiver that was phased out.
        @param id ID of the receiver to modify the isActive status for
        @param isActive is this receiver eligible to receive emissions?
     */
    function setReceiverIsActive(uint256 id, bool isActive) external onlyOwner returns (bool success) {
        // revert if receiver id not associated with an address
        require(idToReceiver[id].account != address(0), "ID not set");

        // update storage - isActive status, address remains the same
        idToReceiver[id].isActive = isActive;

        emit ReceiverIsActiveStatusModified(id, isActive);

        success = true;
    }

    /**
        @notice Set the `emissionSchedule` contract
        @dev Callable only by the owner (the DAO admin voter, to change the emission schedule).
             The new schedule is applied from the start of the next epoch.
     */
    function setEmissionSchedule(IEmissionSchedule _emissionSchedule) external onlyOwner returns (bool success) {
        _allocateTotalWeekly(emissionSchedule, getWeek());
        emissionSchedule = _emissionSchedule;
        emit EmissionScheduleSet(address(_emissionSchedule));

        success = true;
    }

    function setBoostCalculator(IBoostCalculator _boostCalculator) external onlyOwner returns (bool success) {
        boostCalculator = _boostCalculator;
        emit BoostCalculatorSet(address(_boostCalculator));

        success = true;
    }

    /**
        @notice Transfer tokens out of the vault
     */
    function transferTokens(IERC20 token, address receiver, uint256 amount) external onlyOwner returns (bool success) {
        // if token being transferred is the protocol's token,
        // then prevent transfers into the vault via this function
        // and update storage unallocated total
        if (address(token) == address(babelToken)) {
            require(receiver != address(this), "Self transfer denied");

            uint256 unallocated = unallocatedTotal - amount;

            unallocatedTotal = SafeCast.toUint128(unallocated);
            emit UnallocatedSupplyReduced(amount, unallocated);
        }

        token.safeTransfer(receiver, amount);

        success = true;
    }

    /**
        @notice Receive BABEL tokens and add them to the unallocated supply
     */
    function increaseUnallocatedSupply(uint256 amount) external returns (bool success) {
        // safe to use `transferFrom` here since it is the protocol's token
        babelToken.transferFrom(msg.sender, address(this), amount);

        // update storage unallocated total
        uint256 unallocated = unallocatedTotal + amount;
        unallocatedTotal = SafeCast.toUint128(unallocated);

        emit UnallocatedSupplyIncreased(amount, unallocated);

        success = true;
    }

    function _allocateTotalWeekly(IEmissionSchedule _emissionSchedule, uint256 currentWeek) internal {
        // cache most recent total update week
        uint256 week = totalUpdateWeek;

        // if same as system week, do nothing
        if (week >= currentWeek) return;

        // if no emission schedule, just update storage to set
        // total update week to current system week
        if (address(_emissionSchedule) == address(0)) {
            totalUpdateWeek = SafeCast.toUint64(currentWeek);
            return;
        }

        // working data
        uint64 lock;
        uint256 weeklyAmount;
        uint256 unallocated = unallocatedTotal;

        // iterate through unprocessed weeks until current system week
        while (week < currentWeek) {
            ++week;

            // get weekly emissions and remaining lock weeks; this call
            // modifies EmissionSchedule storage
            (weeklyAmount, lock) = _emissionSchedule.getTotalWeeklyEmissions(week, unallocated);

            // update storage weekly emission amount for processed week
            weeklyEmissions[week] = SafeCast.toUint128(weeklyAmount);

            // update working data
            unallocated = unallocated - weeklyAmount;
            
            emit UnallocatedSupplyReduced(weeklyAmount, unallocated);
        }

        // update storage
        unallocatedTotal = SafeCast.toUint128(unallocated);
        totalUpdateWeek = SafeCast.toUint64(currentWeek);
        lockWeeks = lock;
    }

    /**
        @notice Allocate additional `babelToken` allowance to an emission receiver
                based on the emission schedule
        @param id Receiver ID. The caller must be the receiver mapped to this ID.
        @return uint256 Additional `babelToken` allowance for the receiver. The receiver
                        accesses the tokens using `Vault.transferAllocatedTokens`
     */
    function allocateNewEmissions(uint256 id) external returns (uint256) {
        // cache receiver data from storage
        Receiver memory receiver = idToReceiver[id];

        // only account linked to receiver can call this function
        require(receiver.account == msg.sender, "Not receiver account");

        uint256 week = receiver.updatedWeek;

        uint256 currentWeek = getWeek();
        if (week == currentWeek) return 0;

        IEmissionSchedule _emissionSchedule = emissionSchedule;
        _allocateTotalWeekly(_emissionSchedule, currentWeek);

        if (address(_emissionSchedule) == address(0)) {
            idToReceiver[id].updatedWeek = SafeCast.toUint16(currentWeek);
            return 0;
        }

        uint256 amount;
        while (week < currentWeek) {
            ++week;
            amount = amount + _emissionSchedule.getReceiverWeeklyEmissions(id, week, weeklyEmissions[week]);
        }

        idToReceiver[id].updatedWeek = SafeCast.toUint16(currentWeek);

        if (receiver.isActive) {
            allocated[msg.sender] = allocated[msg.sender] + amount;
            emit IncreasedAllocation(msg.sender, amount);
            return amount;
        } else {
            // if receiver is not active, return allocation to the unallocated supply
            uint256 unallocated = unallocatedTotal + amount;
            unallocatedTotal = uint128(unallocated);
            emit UnallocatedSupplyIncreased(amount, unallocated);
            return 0;
        }
    }

    /**
        @notice Transfer `babelToken` tokens previously allocated to the caller
        @dev Callable only by registered receiver contracts which were previously
             allocated tokens using `allocateNewEmissions`.
        @param claimant Address that is claiming the tokens
        @param receiver Address to transfer tokens to
        @param amount Desired amount of tokens to transfer. This value always assumes max boost.
        @return bool success
     */
    function transferAllocatedTokens(address claimant, address receiver, uint256 amount) external returns (bool) {
        if (amount > 0) {
            allocated[msg.sender] -= amount;
            _transferAllocated(0, claimant, receiver, address(0), amount);
        }
        return true;
    }

    /**
        @notice Claim earned tokens from multiple reward contracts, optionally with delegated boost
        @param receiver Address to transfer tokens to. Any earned 3rd-party rewards
                        are also sent to this address.
        @param boostDelegate Address to delegate boost from during this claim. Set as
                             `address(0)` to use the boost of the claimer.
        @param rewardContracts Array of addresses of registered receiver contracts where
                               the caller has pending rewards to claim.
        @param maxFeePct Maximum fee percent to pay to delegate, as a whole number out of 10000
        @return bool success
     */
    function batchClaimRewards(
        address receiver,
        address boostDelegate,
        IRewards[] calldata rewardContracts,
        uint256 maxFeePct
    ) external returns (bool) {
        require(maxFeePct <= 10000, "Invalid maxFeePct");

        uint256 total;
        uint256 length = rewardContracts.length;
        for (uint256 i; i < length; i++) {
            uint256 amount = rewardContracts[i].vaultClaimReward(msg.sender, receiver);
            allocated[address(rewardContracts[i])] -= amount;
            total += amount;
        }
        _transferAllocated(maxFeePct, msg.sender, receiver, boostDelegate, total);
        return true;
    }

    /**
        @notice Claim tokens earned from boost delegation fees
        @param receiver Address to transfer the tokens to
        @return bool Success
     */
    function claimBoostDelegationFees(address receiver) external returns (bool) {
        uint256 amount = storedPendingReward[msg.sender];
        require(amount >= lockToTokenRatio, "Nothing to claim");
        _transferOrLock(msg.sender, receiver, amount);
        return true;
    }

    function _transferAllocated(
        uint256 maxFeePct,
        address account,
        address receiver,
        address boostDelegate,
        uint256 amount
    ) internal {
        if (amount > 0) {
            uint256 week = getWeek();
            uint256 totalWeekly = weeklyEmissions[week];
            address claimant = boostDelegate == address(0) ? account : boostDelegate;
            uint256 previousAmount = accountWeeklyEarned[claimant][week];

            // if boost delegation is active, get the fee and optional callback address
            uint256 fee;
            IBoostDelegate delegateCallback;
            if (boostDelegate != address(0)) {
                Delegation memory data = boostDelegation[boostDelegate];
                delegateCallback = data.callback;
                require(data.isEnabled, "Invalid delegate");
                if (data.feePct == type(uint16).max) {
                    fee = delegateCallback.getFeePct(account, receiver, amount, previousAmount, totalWeekly);
                    require(fee <= 10000, "Invalid delegate fee");
                } else fee = data.feePct;
                require(fee <= maxFeePct, "fee exceeds maxFeePct");
            }

            // calculate adjusted amount with actual boost applied
            uint256 adjustedAmount = boostCalculator.getBoostedAmountWrite(
                claimant,
                amount,
                previousAmount,
                totalWeekly
            );
            {
                // remaining tokens from unboosted claims are added to the unallocated total
                // context avoids stack-too-deep
                uint256 boostUnclaimed = amount - adjustedAmount;
                if (boostUnclaimed > 0) {
                    uint256 unallocated = unallocatedTotal + boostUnclaimed;
                    unallocatedTotal = uint128(unallocated);
                    emit UnallocatedSupplyIncreased(boostUnclaimed, unallocated);
                }
            }
            accountWeeklyEarned[claimant][week] = uint128(previousAmount + amount);

            // apply boost delegation fee
            if (fee != 0) {
                fee = (adjustedAmount * fee) / 10000;
                adjustedAmount -= fee;
            }

            // add `storedPendingReward` to `adjustedAmount`
            // this happens after any boost modifiers or delegation fees, since
            // these effects were already applied to the stored value
            adjustedAmount += storedPendingReward[account];

            _transferOrLock(account, receiver, adjustedAmount);

            // apply delegate fee and optionally perform callback
            if (fee != 0) storedPendingReward[boostDelegate] += fee;
            if (address(delegateCallback) != address(0)) {
                require(
                    delegateCallback.delegatedBoostCallback(
                        account,
                        receiver,
                        amount,
                        adjustedAmount,
                        fee,
                        previousAmount,
                        totalWeekly
                    ),
                    "Delegate callback rejected"
                );
            }
        }
    }

    function _transferOrLock(address claimant, address receiver, uint256 amount) internal {
        uint256 _lockWeeks = lockWeeks;
        if (_lockWeeks == 0) {
            storedPendingReward[claimant] = 0;
            babelToken.transfer(receiver, amount);
        } else {
            // lock for receiver and store remaining balance in `storedPendingReward`
            uint256 lockAmount = amount / lockToTokenRatio;
            storedPendingReward[claimant] = amount - lockAmount * lockToTokenRatio;
            if (lockAmount > 0) locker.lock(receiver, lockAmount, _lockWeeks);
        }
    }

    /**
        @notice Claimable BABEL amount for `account` in `rewardContract` after applying boost
        @dev Returns (0, 0) if the boost delegate is invalid, or the delgate's callback fee
             function is incorrectly configured.
        @param account Address claiming rewards
        @param boostDelegate Address to delegate boost from when claiming. Set as
                             `address(0)` to use the boost of the claimer.
        @param rewardContract Address of the contract where rewards are being claimed
        @return adjustedAmount Amount received after boost, prior to paying delegate fee
        @return feeToDelegate Fee amount paid to `boostDelegate`

     */
    function claimableRewardAfterBoost(
        address account,
        address receiver,
        address boostDelegate,
        IRewards rewardContract
    ) external view returns (uint256 adjustedAmount, uint256 feeToDelegate) {
        uint256 amount = rewardContract.claimableReward(account);
        uint256 week = getWeek();
        uint256 totalWeekly = weeklyEmissions[week];
        address claimant = boostDelegate == address(0) ? account : boostDelegate;
        uint256 previousAmount = accountWeeklyEarned[claimant][week];

        uint256 fee;
        if (boostDelegate != address(0)) {
            Delegation memory data = boostDelegation[boostDelegate];
            if (!data.isEnabled) return (0, 0);
            fee = data.feePct;
            if (fee == type(uint16).max) {
                try data.callback.getFeePct(claimant, receiver, amount, previousAmount, totalWeekly) returns (
                    uint256 _fee
                ) {
                    fee = _fee;
                } catch {
                    return (0, 0);
                }
            }
            if (fee > 10000) return (0, 0);
        }

        adjustedAmount = boostCalculator.getBoostedAmount(claimant, amount, previousAmount, totalWeekly);
        fee = (adjustedAmount * fee) / 10000;

        return (adjustedAmount, fee);
    }

    /**
        @notice Enable or disable boost delegation, and set boost delegation parameters
        @param isEnabled is boost delegation enabled?
        @param feePct Fee % charged when claims are made that delegate to the caller's boost.
                      Given as a whole number out of 10000. If set to type(uint16).max, the fee
                      is set by calling `IBoostDelegate(callback).getFeePct` prior to each claim.
        @param callback Optional contract address to receive a callback each time a claim is
                        made which delegates to the caller's boost.
     */
    function setBoostDelegationParams(bool isEnabled, uint256 feePct, address callback) external returns (bool) {
        if (isEnabled) {
            require(feePct <= 10000 || feePct == type(uint16).max, "Invalid feePct");
            if (callback != address(0) || feePct == type(uint16).max) {
                require(callback.isContract(), "Callback must be a contract");
            }
            boostDelegation[msg.sender] = Delegation({
                isEnabled: true,
                feePct: uint16(feePct),
                callback: IBoostDelegate(callback)
            });
        } else {
            delete boostDelegation[msg.sender];
        }
        emit BoostDelegationSet(msg.sender, isEnabled, feePct, callback);

        return true;
    }

    /**
        @notice Get the remaining claimable amounts this week that will receive boost
        @param claimant address to query boost amounts for
        @return maxBoosted remaining claimable amount that will receive max boost
        @return boosted remaining claimable amount that will receive some amount of boost (including max boost)
     */
    function getClaimableWithBoost(address claimant) external view returns (uint256 maxBoosted, uint256 boosted) {
        uint256 week = getWeek();
        uint256 totalWeekly = weeklyEmissions[week];
        uint256 previousAmount = accountWeeklyEarned[claimant][week];
        return boostCalculator.getClaimableWithBoost(claimant, previousAmount, totalWeekly);
    }

    /**
        @notice Get the claimable amount that `claimant` has earned boost delegation fees
     */
    function claimableBoostDelegationFees(address claimant) external view returns (uint256 amount) {
        amount = storedPendingReward[claimant];
        // only return values `>= lockToTokenRatio` so we do not report "dust" stored for normal users
        return amount >= lockToTokenRatio ? amount : 0;
    }
}
