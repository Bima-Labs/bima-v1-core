// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BimaOwnable} from "../dependencies/BimaOwnable.sol";
import {SystemStart} from "../dependencies/SystemStart.sol";
import {BIMA_100_PCT} from "../dependencies/Constants.sol";
import {IBimaVault, ITokenLocker, IBimaToken, IIncentiveVoting, IEmissionSchedule, IBoostDelegate, IBoostCalculator, IRewards, IERC20} from "../interfaces/IVault.sol";
import {IEmissionReceiver} from "../interfaces/IEmissionReceiver.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
    @title Bima Vault
    @notice The total supply of BIMA is initially minted to this contract.
            The token balance held here can be considered "uncirculating". The
            vault gradually releases tokens to registered emissions receivers
            as determined by `EmissionSchedule` and `BoostCalculator`.
 */
contract BimaVault is IBimaVault, BimaOwnable, SystemStart {
    using Address for address;
    using SafeERC20 for IERC20;

    IBimaToken public immutable bimaToken;
    ITokenLocker public immutable locker;
    IIncentiveVoting public immutable voter;
    address public immutable deploymentManager;
    uint256 public immutable lockToTokenRatio;

    IEmissionSchedule public emissionSchedule;
    IBoostCalculator public boostCalculator;

    // `bimaToken` balance within the treasury that is not yet allocated.
    // Starts as `bimaToken.totalSupply()` and decreases over time.
    uint128 public unallocatedTotal;
    // most recent week that `unallocatedTotal` was reduced by a call to
    // `emissionSchedule.getTotalWeeklyEmissions`
    uint64 public totalUpdateWeek;
    // number of weeks that BIMA is locked for when transferred using
    // `transferAllocatedTokens`. updated weekly by the emission schedule.
    uint64 public lockWeeks;

    // id -> receiver data
    // not bi-directional, one receiver can have multiple ids
    mapping(uint256 receiverId => Receiver receiverData) public idToReceiver;

    // week -> total amount of tokens to be released in that week
    uint128[65535] public weeklyEmissions;

    // receiver -> remaining tokens which have been allocated but not yet distributed
    mapping(address receiver => uint256 remainingAllocated) public allocated;

    // account -> week -> BIMA amount claimed in that week (used for calculating boost)
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
        address _bimaCore,
        IBimaToken _token,
        ITokenLocker _locker,
        IIncentiveVoting _voter,
        address _stabilityPool,
        address _manager
    ) BimaOwnable(_bimaCore) SystemStart(_bimaCore) {
        bimaToken = _token;
        locker = _locker;
        voter = _voter;
        lockToTokenRatio = _locker.lockToTokenRatio();
        deploymentManager = _manager;

        // ensure the stability pool is registered with receiver ID 0
        uint256 id = _voter.registerNewReceiver();
        require(id == 0, "Stability pool must have receiver ID 0");

        idToReceiver[id] = Receiver({account: _stabilityPool, isActive: true, updatedWeek: 0});
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
        require(
            totalSupply <= type(uint32).max * locker.lockToTokenRatio(),
            "Total supply must be <= type(uint32).max * lockToTokenRatio"
        );

        // only deployment manager can set initial parameters
        require(msg.sender == deploymentManager, "!deploymentManager");

        emissionSchedule = _emissionSchedule;
        boostCalculator = _boostCalculator;

        // mint totalSupply to vault - this reverts after the first call
        bimaToken.mintToVault(totalSupply);

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
            bimaToken.increaseAllowance(initialAllowances[i].receiver, initialAllowances[i].amount);

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
            idToReceiver[id] = Receiver({account: receiver, isActive: true, updatedWeek: week});

            emit NewReceiverRegistered(receiver, id);
        }

        // notify the receiver contract of the newly registered ID
        // also serves as a sanity check to ensure the contract
        // is capable of receiving emissions
        require(IEmissionReceiver(receiver).notifyRegisteredId(assignedIds), "notifyRegisteredId must return true");

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

    function isReceiverActive(uint256 id) external view returns (bool isActive) {
        isActive = idToReceiver[id].isActive;
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
        if (address(token) == address(bimaToken)) {
            require(receiver != address(this), "Self transfer denied");

            uint256 unallocated = unallocatedTotal - amount;

            unallocatedTotal = SafeCast.toUint128(unallocated);
            emit UnallocatedSupplyReduced(amount, unallocated);
        }

        token.safeTransfer(receiver, amount);

        success = true;
    }

    /**
        @notice Receive BIMA tokens and add them to the unallocated supply
     */
    function increaseUnallocatedSupply(uint256 amount) external returns (bool success) {
        // safe to use `transferFrom` here since it is the protocol's token
        bimaToken.transferFrom(msg.sender, address(this), amount);

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
            if (weeklyAmount > 0) {
                unallocated = unallocated - weeklyAmount;

                emit UnallocatedSupplyReduced(weeklyAmount, unallocated);
            }
        }

        // update storage
        unallocatedTotal = SafeCast.toUint128(unallocated);
        totalUpdateWeek = SafeCast.toUint64(currentWeek);
        lockWeeks = lock;
    }

    /**
        @notice Allocate additional `bimaToken` allowance to an emission receiver
                based on the emission schedule
        @param id Receiver ID. The caller must be the receiver mapped to this ID.
        @return amount Additional `bimaToken` allowance for the receiver. The receiver
                       accesses the tokens using `Vault.transferAllocatedTokens`
     */
    function allocateNewEmissions(uint256 id) external returns (uint256 amount) {
        // cache receiver data from storage
        Receiver memory receiver = idToReceiver[id];

        // if receiver is active, then only account linked to receiver
        // can call this function
        if (receiver.isActive) {
            require(receiver.account == msg.sender, "Not receiver account");
        }
        // otherwise anyone can call this function - required so that tokens
        // are not permanently lost for disabled receivers

        // get current system week
        uint256 currentWeek = getWeek();

        // nothing to do if the receiver was last processed
        // on same week as current system week; just return
        // default 0
        if (receiver.updatedWeek != currentWeek) {
            // otherwise ensure weekly totals have been processed
            // up to the current system week
            IEmissionSchedule _emissionSchedule = emissionSchedule;

            // note: even if no valid emission schedule exists, this
            // call is still required to update storage totalUpdateWeek
            // to current system week
            _allocateTotalWeekly(_emissionSchedule, currentWeek);

            // update storage receiver last processed week to
            // current system week
            idToReceiver[id].updatedWeek = SafeCast.toUint16(currentWeek);

            // if a valid emission schedule exists perform additional
            // processing otherwise return default 0
            if (address(_emissionSchedule) != address(0)) {
                // iterate through unprocessed weeks for receiver
                // using original cached last updated week since storage
                // was just updated to current system week
                while (receiver.updatedWeek < currentWeek) {
                    ++receiver.updatedWeek;

                    // update output with emissions for previous week being processed
                    amount += _emissionSchedule.getReceiverWeeklyEmissions(
                        id,
                        receiver.updatedWeek,
                        weeklyEmissions[receiver.updatedWeek]
                    );
                }

                // if receiver is active, update storage allocated amount
                // with the newly emitted total amount
                if (receiver.isActive) {
                    allocated[msg.sender] += amount;

                    emit IncreasedAllocation(msg.sender, amount);
                }
                // otherwise return allocation to the unallocated supply
                else {
                    uint256 unallocated = unallocatedTotal + amount;
                    unallocatedTotal = SafeCast.toUint128(unallocated);

                    emit UnallocatedSupplyIncreased(amount, unallocated);

                    // set output to 0 since inactive receiver doesn't receive
                    // emissions but they are added to unallocated supply
                    amount = 0;
                }
            }
        }
    }

    /**
        @notice Transfer `bimaToken` tokens previously allocated to the caller
        @dev Callable only by registered receiver contracts which were previously
             allocated tokens using `allocateNewEmissions`.
        @param claimant Address that is claiming the tokens
        @param receiver Address to transfer tokens to
        @param amount Desired amount of tokens to transfer. This value always assumes max boost.
        @return success bool
     */
    function transferAllocatedTokens(
        address claimant,
        address receiver,
        uint256 amount
    ) external returns (bool success) {
        if (amount > 0) {
            allocated[msg.sender] -= amount;
            _transferAllocated(0, claimant, receiver, address(0), amount);
        }

        success = true;
    }

    /**
        @notice Claim earned tokens from multiple reward contracts, optionally with delegated boost
        @param receiver Address to transfer tokens to. Any earned 3rd-party rewards
                        are also sent to this address.
        @param boostDelegate Address to delegate boost from during this claim. Set as
                             `address(0)` to use the boost of the claimer.
        @param rewardContracts Array of addresses of registered receiver contracts where
                               the caller has pending rewards to claim.
        @param maxFeePct Maximum fee percent to pay to delegate, as a whole number out of BIMA_100_PCT
        @return success bool
     */
    function batchClaimRewards(
        address receiver,
        address boostDelegate,
        IRewards[] calldata rewardContracts,
        uint256 maxFeePct
    ) external returns (bool success) {
        // enforce max fee
        require(maxFeePct <= BIMA_100_PCT, "Invalid maxFeePct");

        // working data
        uint256 total;

        // more efficient not to cache length as calldata
        for (uint256 i; i < rewardContracts.length; i++) {
            uint256 amount = rewardContracts[i].vaultClaimReward(msg.sender, receiver);

            // update storage; decrease allocated for reward contract
            // by the claimed amount
            allocated[address(rewardContracts[i])] -= amount;

            // update working data
            total += amount;
        }

        // transfer total claimed rewards to receiver
        _transferAllocated(maxFeePct, msg.sender, receiver, boostDelegate, total);

        success = true;
    }

    /**
        @notice Claim tokens earned from boost delegation fees
        @param receiver Address to transfer the tokens to
        @return success bool
     */
    function claimBoostDelegationFees(address receiver) external returns (bool success) {
        // cache pending rewards for caller
        uint256 amount = storedPendingReward[msg.sender];

        // enforce claim minimum
        require(amount >= lockToTokenRatio, "Nothing to claim");

        // either transfer or lock the rewards based on
        // value of storage `lockWeeks`
        _transferOrLock(msg.sender, receiver, amount);

        success = true;
    }

    function _transferAllocated(
        uint256 maxFeePct,
        address account,
        address receiver,
        address boostDelegate,
        uint256 amount
    ) internal {
        // nothing to do for 0 amount
        if (amount > 0) {
            // get current system week
            uint256 week = getWeek();

            // cache weekly emission for current system week
            uint256 totalWeekly = weeklyEmissions[week];

            address claimant = boostDelegate == address(0) ? account : boostDelegate;

            // weekly amount claimed so far
            uint256 previousAmount = accountWeeklyEarned[claimant][week];

            // working data
            uint256 fee;
            IBoostDelegate delegateCallback;

            // if boost delegation is active, get the fee and optional callback address
            if (boostDelegate != address(0)) {
                // cache delegation data from storage
                Delegation memory data = boostDelegation[boostDelegate];

                // revert if delegation is not enabled
                require(data.isEnabled, "Invalid delegate");

                // copy callback address to working data
                delegateCallback = data.callback;

                // if fee in delegation data is max(uint16) then execute callback
                // to get actual fee percent
                if (data.feePct == type(uint16).max) {
                    fee = delegateCallback.getFeePct(account, receiver, amount, previousAmount, totalWeekly);

                    // enforce callback fee can't be greater than constant max fee
                    require(fee <= BIMA_100_PCT, "Invalid delegate fee");
                }
                // otherwise use fee percent in delegation data
                else fee = data.feePct;

                // enforce fee percent can't be greater than input max fee
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

                    unallocatedTotal = SafeCast.toUint128(unallocated);

                    emit UnallocatedSupplyIncreased(boostUnclaimed, unallocated);
                }
            }

            // update storage weekly amount claimed so far for newly claimed amount
            accountWeeklyEarned[claimant][week] = SafeCast.toUint128(previousAmount + amount);

            // apply boost delegation fee; `fee` currently = fee percent
            if (fee != 0) {
                // calculate actual fee amount using fee percent
                fee = (adjustedAmount * fee) / BIMA_100_PCT;

                // deduced fee from adjusted amount
                adjustedAmount -= fee;
            }

            // add `storedPendingReward` to `adjustedAmount`
            // this happens after any boost modifiers or delegation fees, since
            // these effects were already applied to the stored value
            adjustedAmount += storedPendingReward[account];

            // either transfer or lock amount based on
            // value of storage `lockWeeks`
            _transferOrLock(account, receiver, adjustedAmount);

            // apply delegate fee
            if (fee != 0) storedPendingReward[boostDelegate] += fee;

            // optionally perform callback
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
        // cache number of weeks allocated tokens are locked for
        uint256 lockWeekCache = lockWeeks;

        // if no forced lock, reset pending rewards and transfer claimed tokens
        if (lockWeekCache == 0) {
            storedPendingReward[claimant] = 0;
            bimaToken.transfer(receiver, amount);
        }
        // otherwise perform a forced lock
        else {
            // lock for receiver and store remaining balance in `storedPendingReward`

            // calculate lock amount accounting for lock to token ratio
            uint256 lockAmount = amount / lockToTokenRatio;

            // the lock amount gets divided by lockToTokenRatio and the lock function
            // will multiply the input by lockToTokenRatio when transferring tokens, hence
            // do the same here when updating storage; this sets the pending reward to the
            // "dust" amount which didn't get locked
            storedPendingReward[claimant] = amount - lockAmount * lockToTokenRatio;

            // perform the lock
            if (lockAmount > 0) locker.lock(receiver, lockAmount, lockWeekCache);
        }
    }

    /**
        @notice Claimable BIMA amount for `account` in `rewardContract` after applying boost
        @dev Returns (0, 0) if the boost delegate is invalid, or the delegate's callback fee
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
        // get claimable reward amount from reward contract
        uint256 amount = rewardContract.claimableReward(account);

        // get current system week
        uint256 week = getWeek();

        // cache weekly emissions for current systme week
        uint256 totalWeekly = weeklyEmissions[week];

        address claimant = boostDelegate == address(0) ? account : boostDelegate;

        // cache previous amount claimed this week by claimant
        uint256 previousAmount = accountWeeklyEarned[claimant][week];

        if (boostDelegate != address(0)) {
            // cache delegate data from storage
            Delegation memory data = boostDelegation[boostDelegate];

            // return 0 if delegate not enabled
            if (!data.isEnabled) return (0, 0);

            // if fee in delegation data is max(uint16) then execute callback
            // to get actual fee percent
            if (data.feePct == type(uint16).max) {
                try data.callback.getFeePct(claimant, receiver, amount, previousAmount, totalWeekly) returns (
                    uint256 _fee
                ) {
                    feeToDelegate = _fee;
                } catch {
                    return (0, 0);
                }
            }
            // otherwise use fee percent in delegation data
            else feeToDelegate = data.feePct;

            // enforce fee can't be greater than constant max fee
            if (feeToDelegate > BIMA_100_PCT) return (0, 0);
        }

        adjustedAmount = boostCalculator.getBoostedAmount(claimant, amount, previousAmount, totalWeekly);

        // calculate actual fee amount using fee percent (`fee` currently = fee percent)
        feeToDelegate = (adjustedAmount * feeToDelegate) / BIMA_100_PCT;
    }

    /**
        @notice Enable or disable boost delegation, and set boost delegation parameters
        @param isEnabled is boost delegation enabled?
        @param feePct Fee % charged when claims are made that delegate to the caller's boost.
                      Given as a whole number out of BIMA_100_PCT. If set to type(uint16).max, the fee
                      is set by calling `IBoostDelegate(callback).getFeePct` prior to each claim.
        @param callback Optional contract address to receive a callback each time a claim is
                        made which delegates to the caller's boost.
     */
    function setBoostDelegationParams(bool isEnabled, uint16 feePct, address callback) external returns (bool success) {
        if (isEnabled) {
            // enforce fee percent is either max(uint16) or <= constant max fee
            require(feePct <= BIMA_100_PCT || feePct == type(uint16).max, "Invalid feePct");

            // enforce callback address is a contract
            if (callback != address(0) || feePct == type(uint16).max) {
                require(callback.isContract(), "Callback must be a contract");
            }

            // save delegation data to storage
            boostDelegation[msg.sender] = Delegation({
                isEnabled: true,
                feePct: feePct,
                callback: IBoostDelegate(callback)
            });
        } else {
            delete boostDelegation[msg.sender];
        }

        emit BoostDelegationSet(msg.sender, isEnabled, feePct, callback);

        success = true;
    }

    /**
        @notice Get the remaining claimable amounts this week that will receive boost
        @param claimant address to query boost amounts for
        @return maxBoosted remaining claimable amount that will receive max boost
        @return boosted remaining claimable amount that will receive some amount of boost (including max boost)
     */
    function getClaimableWithBoost(address claimant) external view returns (uint256 maxBoosted, uint256 boosted) {
        // get current system week
        uint256 week = getWeek();

        // cache total weekly emissions for current system week
        uint256 totalWeekly = weeklyEmissions[week];

        // cache previous amount account claimed for current system week
        uint256 previousAmount = accountWeeklyEarned[claimant][week];

        (maxBoosted, boosted) = boostCalculator.getClaimableWithBoost(claimant, previousAmount, totalWeekly);
    }

    /**
        @notice Get the claimable amount that `claimant` has earned boost delegation fees
     */
    function claimableBoostDelegationFees(address claimant) external view returns (uint256 amount) {
        // output pending rewards for claimant
        amount = storedPendingReward[claimant];

        // if smaller than lock to token ratio, return 0
        if (amount < lockToTokenRatio) amount = 0;
    }

    function getAccountWeeklyEarned(address claimant, uint16 week) external view returns (uint128 amount) {
        amount = accountWeeklyEarned[claimant][week];
    }

    function getStoredPendingReward(address claimant) external view returns (uint256 amount) {
        amount = storedPendingReward[claimant];
    }

    function isBoostDelegatedEnabled(address account) external view returns (bool isEnabled) {
        isEnabled = boostDelegation[account].isEnabled;
    }
}
