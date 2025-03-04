// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {DelegatedOps} from "../dependencies/DelegatedOps.sol";
import {SystemStart} from "../dependencies/SystemStart.sol";
import {BIMA_100_PCT} from "../dependencies/Constants.sol";
import {BimaMath} from "../dependencies/BimaMath.sol";
import {ITokenLocker} from "../interfaces/ITokenLocker.sol";
import {IBimaCore} from "../interfaces/IBimaCore.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
    @title Bima DAO Admin Voter
    @notice Primary ownership contract for all Bima contracts. Allows executing
            arbitrary function calls only after a required percentage of BIMA
            lockers have signalled in favor of performing the action.
 */
contract AdminVoting is DelegatedOps, SystemStart {
    using Address for address;

    event ProposalCreated(
        address indexed account,
        uint256 proposalId,
        Action[] payload,
        uint256 week,
        uint256 requiredWeight
    );
    event ProposalHasMetQuorum(uint256 id, uint256 canExecuteAfter);
    event ProposalExecuted(uint256 proposalId);
    event ProposalCancelled(uint256 proposalId);
    event VoteCast(
        address indexed account,
        uint256 indexed id,
        uint256 weight,
        uint256 proposalCurrentWeight,
        bool hasPassed
    );
    event ProposalCreationMinPctSet(uint256 weight);
    event ProposalPassingPctSet(uint256 pct);

    struct Proposal {
        uint16 week; // week which vote weights are based upon
        uint32 createdAt; // timestamp when the proposal was created
        uint32 canExecuteAfter; // earliest timestamp when proposal can be executed (0 if not passed)
        uint40 currentWeight; //  amount of weight currently voting in favor
        uint40 requiredWeight; // amount of weight required for the proposal to be executed
        bool processed; // set to true once the proposal is processed
    }

    struct Action {
        address target;
        bytes data;
    }

    uint256 public constant BOOTSTRAP_PERIOD = 30 days;
    uint256 public constant VOTING_PERIOD = 1 weeks;
    uint256 public constant MIN_TIME_TO_EXECUTION = 1 days;
    uint256 public constant MAX_TIME_TO_EXECUTION = 3 weeks;
    uint256 public constant MIN_TIME_BETWEEN_PROPOSALS = 1 weeks;
    uint256 public constant SET_GUARDIAN_PASSING_PCT = 5010;

    ITokenLocker public immutable tokenLocker;
    IBimaCore public immutable bimaCore;

    Proposal[] proposalData;

    // proposal payloads
    mapping(uint256 proposalId => Action[] payload) proposalPayloads;

    // voting records
    mapping(address account => mapping(uint256 proposalId => uint256 votedWeight)) public accountVoteWeights;

    // account last proposal creation timestamps
    mapping(address account => uint256 timestamp) public latestProposalTimestamp;

    // percent of total weight required to create a new proposal
    uint256 public minCreateProposalPct;
    // percent of total weight that must vote for a proposal before it can be executed
    uint256 public passingPct;

    constructor(
        address _bimaCore,
        ITokenLocker _tokenLocker,
        uint256 _minCreateProposalPct,
        uint256 _passingPct
    ) SystemStart(_bimaCore) {
        tokenLocker = _tokenLocker;
        bimaCore = IBimaCore(_bimaCore);

        minCreateProposalPct = _minCreateProposalPct;
        passingPct = _passingPct;
    }

    /**
        @notice The total number of votes created
     */
    function getProposalCount() external view returns (uint256 count) {
        count = proposalData.length;
    }

    function minCreateProposalWeight() external view returns (uint256 weight) {
        // store getWeek() directly into output `weight` return
        weight = getWeek();

        // if week == 0 nothing else to do since weight also 0
        if (weight != 0) {
            // otherwise over-write output with weight calculation subtracting
            // 1 from the week
            weight = _minCreateProposalWeight(weight - 1);
        }
    }

    function _minCreateProposalWeight(uint256 week) internal view returns (uint256 weight) {
        // store total weight directly into output `weight` return
        weight = tokenLocker.getTotalWeightAt(week);

        // prevent proposal creation if zero total weight for given week
        require(weight > 0, "Zero total voting weight for given week");

        // over-write output return with weight calculation
        weight = ((weight * minCreateProposalPct) / BIMA_100_PCT);
    }

    /**
        @notice Gets information on a specific proposal
     */
    function getProposalData(
        uint256 id
    )
        external
        view
        returns (
            uint256 week,
            uint256 createdAt,
            uint256 currentWeight,
            uint256 requiredWeight,
            uint256 canExecuteAfter,
            bool executed,
            bool canExecute,
            Action[] memory payload
        )
    {
        Proposal memory proposal = proposalData[id];
        payload = proposalPayloads[id];
        canExecute = (!proposal.processed &&
            proposal.currentWeight >= proposal.requiredWeight &&
            proposal.canExecuteAfter < block.timestamp &&
            proposal.canExecuteAfter + MAX_TIME_TO_EXECUTION > block.timestamp);

        week = proposal.week;
        createdAt = proposal.createdAt;
        currentWeight = proposal.currentWeight;
        requiredWeight = proposal.requiredWeight;
        canExecuteAfter = proposal.canExecuteAfter;
        executed = proposal.processed;
    }

    // helper functions added because getProposalData returns a lot of fields
    // which can result in "stack too deep" errors
    function getProposalWeek(uint256 id) external view returns (uint256 week) {
        week = proposalData[id].week;
    }

    function getProposalCreatedAt(uint256 id) external view returns (uint32 createdAt) {
        createdAt = proposalData[id].createdAt;
    }

    function getProposalCurrentWeight(uint256 id) external view returns (uint256 currentWeight) {
        currentWeight = proposalData[id].currentWeight;
    }

    function getProposalRequiredWeight(uint256 id) external view returns (uint256 requiredWeight) {
        requiredWeight = proposalData[id].requiredWeight;
    }

    function getProposalCanExecuteAfter(uint256 id) external view returns (uint32 canExecAfter) {
        canExecAfter = proposalData[id].canExecuteAfter;
    }

    function getProposalProcessed(uint256 id) external view returns (bool processed) {
        processed = proposalData[id].processed;
    }

    function getProposalCanExecute(uint256 id) external view returns (bool canExec) {
        Proposal memory proposal = proposalData[id];

        canExec = (!proposal.processed &&
            proposal.currentWeight >= proposal.requiredWeight &&
            proposal.canExecuteAfter < block.timestamp &&
            proposal.canExecuteAfter + MAX_TIME_TO_EXECUTION > block.timestamp);
    }

    function getProposalPayload(uint256 id) external view returns (Action[] memory payload) {
        payload = proposalPayloads[id];
    }

    function getProposalPassed(uint256 id) external view returns (bool passed) {
        Proposal memory proposal = proposalData[id];
        passed = proposal.currentWeight >= proposal.requiredWeight;
    }

    /**
        @notice Create a new proposal
        @param payload Tuple of [(target address, calldata), ... ] to be
                       executed if the proposal is passed.
     */
    function createNewProposal(
        address account,
        Action[] calldata payload
    ) external callerOrDelegated(account) returns (uint256 proposalId) {
        // enforce >=1 payload
        require(payload.length > 0, "Empty payload");

        // restrict accounts from spamming proposals
        require(
            latestProposalTimestamp[account] + MIN_TIME_BETWEEN_PROPOSALS < block.timestamp,
            "MIN_TIME_BETWEEN_PROPOSALS"
        );

        // week is set at -1 to the active week so that weights are finalized
        uint256 week = getWeek();
        require(week > 0, "No proposals in first week");
        week -= 1;

        // account must satisfy minimum weight to create proposals
        uint256 accountWeight = tokenLocker.getAccountWeightAt(account, week);
        require(accountWeight >= _minCreateProposalWeight(week), "Not enough weight to propose");

        // if any of the payloads call `IBimaCore::setGuardian`,
        // then enforce the `SET_GUARDIAN_PASSING_PCT` 50.1% majority
        uint256 proposalPassPct;

        if (_containsSetGuardianPayload(payload.length, payload)) {
            // prevent changing guardians during bootstrap period
            require(block.timestamp > startTime + BOOTSTRAP_PERIOD, "Cannot change guardian during bootstrap");

            // enforce 50.1% majority for setGuardian proposals; if the default
            // passing percent is greater than the hard-coded setGuardian percent
            // then use that instead
            proposalPassPct = BimaMath._max(SET_GUARDIAN_PASSING_PCT, passingPct);
        }
        // otherwise for ordinary proposals enforce standard configured passing %
        else proposalPassPct = passingPct;

        // fetch total voting weight for the week
        uint256 totalWeight = tokenLocker.getTotalWeightAt(week);

        // calculate required quorum for the proposal to pass
        uint40 requiredWeight = SafeCast.toUint40((totalWeight * proposalPassPct) / BIMA_100_PCT);

        // output newly created proposal id
        proposalId = proposalData.length;

        // save proposal data
        proposalData.push(
            Proposal({
                week: SafeCast.toUint16(week),
                createdAt: uint32(block.timestamp),
                canExecuteAfter: 0,
                currentWeight: 0,
                requiredWeight: requiredWeight,
                processed: false
            })
        );

        // save proposal payload data
        for (uint256 i; i < payload.length; i++) {
            proposalPayloads[proposalId].push(payload[i]);
        }

        // update account's last proposal creation timestamp
        latestProposalTimestamp[account] = block.timestamp;

        emit ProposalCreated(account, proposalId, payload, week, requiredWeight);
    }

    /**
        @notice Vote in favor of a proposal
        @dev Each account can vote once per proposal
        @param id Proposal ID
        @param weight Weight to allocate to this action. If set to zero, the full available
                      account weight is used. Integrating protocols may wish to use partial
                      weight to reflect partial support from their own users.
     */
    function voteForProposal(address account, uint256 id, uint256 weight) external callerOrDelegated(account) {
        // enforce valid proposal id
        require(id < proposalData.length, "Invalid ID");

        // prevent account from voting on same proposal more than once
        require(accountVoteWeights[account][id] == 0, "Already voted");

        // cache proposal data from storage into memory
        Proposal memory proposal = proposalData[id];

        // prevent voting if proposal has been cancelled or executed
        require(!proposal.processed, "Proposal already processed");

        // prevent voting outside the allowed voting window
        require(proposal.createdAt + VOTING_PERIOD > block.timestamp, "Voting period has closed");

        // fetch account's voting weight during the proposal's week
        uint256 accountWeight = tokenLocker.getAccountWeightAt(account, proposal.week);

        // if account passed 0 they want to vote with all their weight
        if (weight == 0) {
            weight = accountWeight;

            // enforce minimum weight > 0 to vote
            require(weight > 0, "No vote weight");
            // otherwise if account specified an exact voting weight > 0 then
            // enforce it is <= their max voting weight
        } else {
            require(weight <= accountWeight, "Weight exceeds account weight");
        }

        // update account voting record for this proposal to save voting weight
        accountVoteWeights[account][id] = weight;

        // calculate proposal's accumulated voting weight
        uint40 updatedWeight = SafeCast.toUint40(proposal.currentWeight + weight);

        // update proposal's accumulated voting weight
        proposalData[id].currentWeight = updatedWeight;

        // proposal has passed if the updated weight is >= required weight
        bool hasPassed = updatedWeight >= proposal.requiredWeight;

        // if the proposal has passed as a result of this vote, then update
        // the time at which the proposal can be executed
        if (proposal.canExecuteAfter == 0 && hasPassed) {
            uint256 canExecuteAfter = block.timestamp + MIN_TIME_TO_EXECUTION;

            proposalData[id].canExecuteAfter = uint32(canExecuteAfter);
            emit ProposalHasMetQuorum(id, canExecuteAfter);
        }

        // note: explicitly allowing users to vote on proposals which have
        // passed but have not yet been cancelled or executed

        emit VoteCast(account, id, weight, updatedWeight, hasPassed);
    }

    /**
        @notice Cancels a pending proposal
        @dev Can only be called by the guardian to avoid malicious proposals
             The guardian cannot cancel a proposal where the only action is
             changing the guardian.
        @param id Proposal ID
     */
    function cancelProposal(uint256 id) external {
        // enforce only guardian can cancel
        require(msg.sender == bimaCore.guardian(), "Only guardian can cancel proposals");

        // enforce valid proposal id
        require(id < proposalData.length, "Invalid ID");

        // get a reference to storage data of proposal's payload
        Action[] storage payload = proposalPayloads[id];

        // prevent cancellation of proposals that have only 1 payload, containing `setGuardian` call
        require(
            payload.length > 1 || !_containsSetGuardianPayload(payload.length, payload),
            "Guardian replacement not cancellable"
        );

        // prevent cancellation of executed or cancelled proposals
        require(!proposalData[id].processed, "Already processed");

        // mark the proposal as cancelled
        proposalData[id].processed = true;

        emit ProposalCancelled(id);
    }

    /**
        @notice Execute a proposal's payload
        @dev Can only be called if the proposal has received sufficient vote weight,
             and has been active for at least `MIN_TIME_TO_EXECUTION`
        @param id Proposal ID
     */
    function executeProposal(uint256 id) external {
        // enforce valid proposal id
        require(id < proposalData.length, "Invalid ID");

        // cache proposal data from storage into memory
        Proposal memory proposal = proposalData[id];

        // prevent execution of executed or cancelled proposals
        require(!proposal.processed, "Already processed");

        // revert if proposal has not yet passed
        require(proposal.canExecuteAfter != 0, "Not passed");

        // revert if it has passed but the minimum time from passing
        // to execution has not yet elapsed (execute too early after passing)
        require(proposal.canExecuteAfter < block.timestamp, "MIN_TIME_TO_EXECUTION");

        // revert if it has passed but the maximum time from passing
        // to execution has elapsed (execute too late after passing)
        require(proposal.canExecuteAfter + MAX_TIME_TO_EXECUTION > block.timestamp, "MAX_TIME_TO_EXECUTION");

        // mark the proposal as executed
        proposalData[id].processed = true;

        // get a reference to storage data of proposal's payload
        Action[] storage payload = proposalPayloads[id];

        // cache the payload length
        uint256 payloadLength = payload.length;

        // execute every payload
        for (uint256 i; i < payloadLength; i++) {
            payload[i].target.functionCall(payload[i].data);
        }

        emit ProposalExecuted(id);
    }

    /**
        @notice Set the minimum % of the total weight required to create a new proposal
        @dev Only callable via a passing proposal that includes a call
             to this contract and function within it's payload
     */
    function setMinCreateProposalPct(uint256 pct) external returns (bool success) {
        // enforce this function can only be called by this contract
        require(msg.sender == address(this), "Only callable via proposal");

        // restrict max value
        require(pct <= BIMA_100_PCT, "Invalid value");

        // update to new value
        minCreateProposalPct = pct;

        emit ProposalCreationMinPctSet(pct);
        success = true;
    }

    /**
        @notice Set the required % of the total weight that must vote
                for a proposal prior to being able to execute it
        @dev Only callable via a passing proposal that includes a call
             to this contract and function within it's payload
     */
    function setPassingPct(uint256 pct) external returns (bool success) {
        // enforce this function can only be called by this contract
        require(msg.sender == address(this), "Only callable via proposal");

        // restrict max value
        require(pct <= BIMA_100_PCT && pct > 0, "Invalid value");

        // update to new value
        passingPct = pct;

        emit ProposalPassingPctSet(pct);
        success = true;
    }

    /**
        @dev Unguarded method to allow accepting ownership transfer of `BimaCore`
             at the end of the deployment sequence
     */
    function acceptTransferOwnership() external {
        bimaCore.acceptTransferOwnership();
    }

    function _containsSetGuardianPayload(
        uint256 payloadLength,
        Action[] memory payload
    ) internal pure returns (bool success) {
        // iterate through every payload
        for (uint256 i; i < payloadLength; i++) {
            bytes memory data = payload[i].data;

            // Extract the call sig from payload data
            bytes4 sig;
            assembly {
                sig := mload(add(data, 0x20))
            }

            // return true if any payload calls `IBimaCore::setGuardian`
            if (sig == IBimaCore.setGuardian.selector) return true;
        }

        // if reach here return default false
    }
}
