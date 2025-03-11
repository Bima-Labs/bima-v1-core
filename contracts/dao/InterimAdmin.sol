// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBimaCore} from "../interfaces/IBimaCore.sol";

/**
    @title Bima DAO Interim Admin
    @notice Temporary ownership contract for all Bima contracts during bootstrap phase. Allows executing
            arbitrary function calls by the deployer following a minimum time before execution.
            The protocol guardian can cancel any proposals and cannot be replaced.
            To avoid a malicious flood attack the number of daily proposals is capped.
 */
contract InterimAdmin is Ownable {
    using Address for address;

    event ProposalCreated(uint256 proposalId, Action[] payload);
    event ProposalExecuted(uint256 proposalId);
    event ProposalCancelled(uint256 proposalId);
    event AdminVotingSet(address);

    struct Proposal {
        uint32 createdAt; // timestamp when the proposal was created
        uint32 canExecuteAfter; // earliest timestamp when proposal can be executed (0 if not passed)
        bool processed; // set to true once the proposal is processed
    }

    struct Action {
        address target;
        bytes data;
    }

    uint256 public constant MIN_TIME_TO_EXECUTION = 1 days;
    uint256 public constant MAX_TIME_TO_EXECUTION = 3 weeks;
    uint256 public constant MAX_DAILY_PROPOSALS = 3;

    IBimaCore public immutable bimaCore;
    address public adminVoting;

    Proposal[] proposalData;
    mapping(uint256 => Action[]) proposalPayloads;

    // store number of proposals created per day
    mapping(uint256 dayNumber => uint256 proposalCount) dailyProposalsCount;

    constructor(address _bimaCore) {
        bimaCore = IBimaCore(_bimaCore);
    }

    function setAdminVoting(address _adminVoting) external onlyOwner {
        // can only be set once
        require(adminVoting == address(0), "Already set");

        // must be set to a valid contract
        require(_adminVoting.isContract(), "adminVoting must be a contract");

        // update storage
        adminVoting = _adminVoting;

        emit AdminVotingSet(_adminVoting);
    }

    /**
        @notice The total number of votes created
     */
    function getProposalCount() external view returns (uint256 count) {
        count = proposalData.length;
    }

    /**
        @notice Gets information on a specific proposal
     */
    function getProposalData(
        uint256 id
    )
        external
        view
        returns (uint256 createdAt, uint256 canExecuteAfter, bool executed, bool canExecute, Action[] memory payload)
    {
        Proposal memory proposal = proposalData[id];
        payload = proposalPayloads[id];
        canExecute = (!proposal.processed &&
            proposal.canExecuteAfter < block.timestamp &&
            proposal.canExecuteAfter + MAX_TIME_TO_EXECUTION > block.timestamp);

        createdAt = proposal.createdAt;
        canExecuteAfter = proposal.canExecuteAfter;
        executed = proposal.processed;
    }

    function getProposalCreatedAt(uint256 id) external view returns (uint256 createdAt) {
        createdAt = proposalData[id].createdAt;
    }

    function getProposalCanExecuteAfter(uint256 id) external view returns (uint256 canExecuteAfter) {
        canExecuteAfter = proposalData[id].canExecuteAfter;
    }

    function getProposalExecuted(uint256 id) external view returns (bool executed) {
        executed = proposalData[id].processed;
    }

    function getProposalCanExecute(uint256 id) external view returns (bool canExecute) {
        Proposal memory proposal = proposalData[id];
        canExecute = (!proposal.processed &&
            proposal.canExecuteAfter < block.timestamp &&
            proposal.canExecuteAfter + MAX_TIME_TO_EXECUTION > block.timestamp);
    }

    function getProposalPayload(uint256 id) external view returns (Action[] memory payload) {
        payload = proposalPayloads[id];
    }

    /**
        @notice Create a new proposal
        @param payload Tuple of [(target address, calldata), ... ] to be
                       executed if the proposal is passed.
     */
    function createNewProposal(Action[] calldata payload) external onlyOwner returns (uint256 proposalId) {
        // enforce >=1 payload
        require(payload.length > 0, "Empty payload");

        // get current day number
        uint256 day = block.timestamp / 1 days;

        // fetch how many proposals have been created today
        // and increment storage by 1 after fetching value
        uint256 currentDailyCount = dailyProposalsCount[day]++;

        // enforce maximum on number of proposals per day
        require(currentDailyCount < MAX_DAILY_PROPOSALS, "MAX_DAILY_PROPOSALS");

        // more efficient to not cache length for calldata
        // search every payload and prevent calls to `IBimaCore::setGuardian`
        for (uint256 i; i < payload.length; i++) {
            require(!_isSetGuardianPayload(payload[i]), "Cannot change guardian");
        }

        // fetch next proposal id
        proposalId = proposalData.length;

        // save new proposal data
        proposalData.push(
            Proposal({
                createdAt: uint32(block.timestamp),
                canExecuteAfter: uint32(block.timestamp + MIN_TIME_TO_EXECUTION),
                processed: false
            })
        );

        // save payload data for new proposal
        for (uint256 i; i < payload.length; i++) {
            proposalPayloads[proposalId].push(payload[i]);
        }
        emit ProposalCreated(proposalId, payload);
    }

    /**
        @notice Cancels a pending proposal
        @dev Can only be called by the guardian to avoid malicious proposals
             The guardian cannot cancel a proposal where the only action is
             changing the guardian.
        @param id Proposal ID
     */
    function cancelProposal(uint256 id) external {
        // only owner or guardian can cancel proposals
        require(msg.sender == owner() || msg.sender == bimaCore.guardian(), "Unauthorized");

        // enforce valid proposal id
        require(id < proposalData.length, "Invalid ID");

        // prevent cancellation of executed or cancelled proposals
        require(!proposalData[id].processed, "Already processed");

        // mark proposal as cancelled
        proposalData[id].processed = true;

        emit ProposalCancelled(id);
    }

    /**
        @notice Execute a proposal's payload
        @dev Can only be called if the proposal has been active for at least `MIN_TIME_TO_EXECUTION`
        @param id Proposal ID
     */
    function executeProposal(uint256 id) external onlyOwner {
        // enforce valid proposal id
        require(id < proposalData.length, "Invalid ID");

        // cache proposal data from storage into memory
        Proposal memory proposal = proposalData[id];

        // prevent execution of executed or cancelled proposals
        require(!proposal.processed, "Already processed");

        // revert if the minimum time from passing to execution
        // has not yet elapsed (execute too early after passing)
        require(proposal.canExecuteAfter < block.timestamp, "MIN_TIME_TO_EXECUTION");

        // revert if the maximum time from passing to execution
        // has elapsed (execute too late after passing)
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
        @dev Allow accepting ownership transfer of `BimaCore`
     */
    function acceptTransferOwnership() external onlyOwner {
        bimaCore.acceptTransferOwnership();
    }

    /**
        @dev Restricted method to transfer ownership of `BimaCore`
             to the actual Admin voting contract
     */
    function transferOwnershipToAdminVoting() external {
        require(msg.sender == owner() || msg.sender == bimaCore.guardian(), "Unauthorized");
        bimaCore.commitTransferOwnership(adminVoting);
    }

    function _isSetGuardianPayload(Action calldata action) internal pure returns (bool output) {
        bytes memory data = action.data;
        // Extract the call sig from payload data
        bytes4 sig;
        assembly {
            sig := mload(add(data, 0x20))
        }
        output = sig == IBimaCore.setGuardian.selector;
    }
}
