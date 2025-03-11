// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILiquidityGauge} from "../../interfaces/ILiquidityGauge.sol";
import {BimaOwnable} from "../../dependencies/BimaOwnable.sol";
import {BIMA_100_PCT} from "../../dependencies/Constants.sol";

import {ICurveProxy, IGaugeController, IERC20, IMinter, IFeeDistributor, IVotingEscrow, IAragon} from "../../interfaces/ICurveProxy.sol";

/**
    @title Bima Curve Proxy
    @notice Locks CRV in Curve's `VotingEscrow` and interacts with various Curve
            contracts that require / provide benefit from the locked CRV position.
    @dev This contract cannot operate without approval in Curve's VotingEscrow
         smart wallet whitelist. See the Curve documentation for more info:
         https://docs.curve.fi/curve_dao/VotingEscrow/#smart-wallet-whitelist
 */
contract CurveProxy is ICurveProxy, BimaOwnable {
    using Address for address;
    using SafeERC20 for IERC20;

    IERC20 public immutable CRV;
    IGaugeController public immutable gaugeController;
    IMinter public immutable minter;
    IVotingEscrow public immutable votingEscrow;
    IFeeDistributor public immutable feeDistributor;
    IERC20 public immutable feeToken;

    uint256 constant WEEK = 604800;
    uint256 constant MAX_LOCK_DURATION = 4 * 365 * 86400; // 4 years

    uint64 public crvFeePct; // fee as a pct out of BIMA_100_PCT
    uint64 public unlockTime;

    // the vote manager is approved to call voting-related functions
    // these functions are also callable directly by the owner
    address public voteManager;

    // the deposit manager is approved to call all gauge-related functionality
    // and can permit other contracts to access the same functions on a per-gauge basis
    address public depositManager;

    // permission for contracts which can call gauge-related functionality for a single gauge
    mapping(address caller => address gauge) public perGaugeApproval;

    // permission for callers which can execute arbitrary calls via this contract's `execute` function
    mapping(address caller => mapping(address target => mapping(bytes4 selector => bool))) executePermissions;

    constructor(
        address _bimaCore,
        IERC20 _CRV,
        IGaugeController _gaugeController,
        IMinter _minter,
        IVotingEscrow _votingEscrow,
        IFeeDistributor _feeDistributor
    ) BimaOwnable(_bimaCore) {
        CRV = _CRV;
        gaugeController = _gaugeController;
        minter = _minter;
        votingEscrow = _votingEscrow;
        feeDistributor = _feeDistributor;
        feeToken = IERC20(_feeDistributor.token());

        CRV.approve(address(votingEscrow), type(uint256).max);
    }

    modifier ownerOrVoteManager() {
        require(msg.sender == voteManager || msg.sender == owner(), "Only owner or vote manager");
        _;
    }

    modifier onlyDepositManager() {
        require(msg.sender == depositManager, "Only deposit manager");
        _;
    }

    modifier onlyApprovedGauge(address gauge) {
        require(perGaugeApproval[msg.sender] == gauge || msg.sender == depositManager, "Not approved for gauge");
        _;
    }

    /**
        @notice Grant or revoke permission for `caller` to call one or more
                functions on `target` via this contract.
     */
    function setExecutePermissions(
        address caller,
        address target,
        bytes4[] calldata selectors,
        bool permitted
    ) external onlyOwner returns (bool success) {
        mapping(bytes4 => bool) storage _executePermission = executePermissions[caller][target];
        for (uint256 i; i < selectors.length; i++) {
            _executePermission[selectors[i]] = permitted;
        }
        success = true;
    }

    /**
        @notice Set the fee percent taken on all CRV earned through this contract
        @dev CRV earned as fees is periodically added to the contract's locked position
     */
    function setCrvFeePct(uint64 _feePct) external onlyOwner returns (bool success) {
        require(_feePct <= BIMA_100_PCT, "Invalid setting");
        crvFeePct = _feePct;
        emit CrvFeePctSet(_feePct);
        success = true;
    }

    function setVoteManager(address _voteManager) external onlyOwner returns (bool success) {
        voteManager = _voteManager;
        emit SetVoteManager(_voteManager);

        success = true;
    }

    function setDepositManager(address _depositManager) external onlyOwner returns (bool success) {
        depositManager = _depositManager;
        emit SetDepositManager(_depositManager);

        success = true;
    }

    function setPerGaugeApproval(address caller, address gauge) external onlyDepositManager returns (bool success) {
        perGaugeApproval[caller] = gauge;
        emit SetPerGaugeApproval(caller, gauge);

        success = true;
    }

    /**
        @notice Claim pending 3CRV fees earned from the veCRV balance
                and transfer the fees onward to the fee receiver
        @dev This method is intentionally left unguarded
     */
    function claimFees() external returns (uint256 amount) {
        feeDistributor.claim();
        amount = feeToken.balanceOf(address(this));

        feeToken.transfer(BIMA_CORE.feeReceiver(), amount);
    }

    /**
        @notice Lock any CRV balance within the contract, and extend
                the unlock time to the maximum possible
        @dev This method is intentionally left unguarded
     */
    function lockCRV() external returns (bool success) {
        uint256 maxUnlock = ((block.timestamp / WEEK) * WEEK) + MAX_LOCK_DURATION;
        uint256 amount = CRV.balanceOf(address(this));

        _updateLock(amount, unlockTime, maxUnlock);

        success = true;
    }

    /**
        @notice Mint CRV rewards earned for a specific gauge
        @dev Once per week, also locks any CRV balance within the contract and extends the lock duration
        @param gauge Address of the gauge to mint CRV for
        @param receiver Address to send the minted CRV to
        @return amount uint256 Amount of CRV send to the receiver (after the fee)
     */
    function mintCRV(address gauge, address receiver) external onlyApprovedGauge(gauge) returns (uint256 amount) {
        uint256 initial = CRV.balanceOf(address(this));
        minter.mint(gauge);
        amount = CRV.balanceOf(address(this)) - initial;

        // apply fee prior to transfer
        uint256 fee = (amount * crvFeePct) / BIMA_100_PCT;
        amount -= fee;

        CRV.transfer(receiver, amount);

        // lock and extend if needed
        uint256 unlock = unlockTime;
        uint256 maxUnlock = ((block.timestamp / WEEK) * WEEK) + MAX_LOCK_DURATION;
        if (unlock < maxUnlock) {
            _updateLock(initial + fee, unlock, maxUnlock);
        }
    }

    /**
        @notice Submit one or more gauge weight votes
     */
    function voteForGaugeWeights(GaugeWeightVote[] calldata votes) external ownerOrVoteManager returns (bool success) {
        for (uint256 i; i < votes.length; i++) {
            gaugeController.vote_for_gauge_weights(votes[i].gauge, votes[i].weight);
        }

        success = true;
    }

    /**
        @notice Submit a vote within the Curve DAO
     */
    function voteInCurveDao(
        IAragon aragon,
        uint256 id,
        bool support
    ) external ownerOrVoteManager returns (bool success) {
        aragon.vote(id, support, false);

        success = true;
    }

    /**
        @notice Approve a 3rd-party caller to deposit into a specific gauge
        @dev Only required for some older Curve gauges
     */
    function approveGaugeDeposit(
        address gauge,
        address depositor
    ) external onlyApprovedGauge(gauge) returns (bool success) {
        ILiquidityGauge(gauge).set_approve_deposit(depositor, true);

        success = true;
    }

    /**
        @notice Set the default receiver for extra rewards on a specific gauge
        @dev Only works on some gauge versions
     */
    function setGaugeRewardsReceiver(
        address gauge,
        address receiver
    ) external onlyApprovedGauge(gauge) returns (bool success) {
        ILiquidityGauge(gauge).set_rewards_receiver(receiver);

        success = true;
    }

    /**
        @notice Withdraw LP tokens from a gauge
        @param gauge Address of the gauge to withdraw from
        @param lpToken Address of the LP token we are withdrawing from the gauge.
                       The contract trusts the caller to supply the correct address.
        @param amount Amount of LP tokens to withdraw
        @param receiver Address to send the LP token to
     */
    function withdrawFromGauge(
        address gauge,
        IERC20 lpToken,
        uint256 amount,
        address receiver
    ) external onlyApprovedGauge(gauge) returns (bool success) {
        ILiquidityGauge(gauge).withdraw(amount);
        lpToken.transfer(receiver, amount);

        success = true;
    }

    /**
        @notice Transfer arbitrary token balances out of this contract
        @dev Necessary for handling extra rewards on older gauge types
     */
    function transferTokens(
        address receiver,
        TokenBalance[] calldata balances
    ) external onlyDepositManager returns (bool success) {
        for (uint256 i; i < balances.length; i++) {
            balances[i].token.safeTransfer(receiver, balances[i].amount);
        }

        success = true;
    }

    /**
        @notice Execute an arbitrary function call using this contract
        @dev Callable via the owner, or if explicit permission is given
             to the caller for this target and function selector
     */
    function execute(address target, bytes calldata data) external returns (bytes memory retData) {
        if (msg.sender != owner()) {
            bytes4 selector = bytes4(data[:4]);
            require(executePermissions[msg.sender][target][selector], "Not permitted");
        }
        retData = target.functionCall(data);
    }

    function _updateLock(uint256 amount, uint256 unlock, uint256 maxUnlock) internal {
        if (amount > 0) {
            if (unlock == 0) {
                votingEscrow.create_lock(amount, maxUnlock);
                unlockTime = uint64(maxUnlock);
                return;
            }
            votingEscrow.increase_amount(amount);
        }
        if (unlock < maxUnlock) {
            votingEscrow.increase_unlock_time(maxUnlock);
            unlockTime = uint64(maxUnlock);
        }
    }
}
