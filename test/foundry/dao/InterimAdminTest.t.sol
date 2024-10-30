// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBimaCore} from "../../../contracts/interfaces/IBimaCore.sol";
import {BIMA_100_PCT} from "../../../contracts/dependencies/Constants.sol";

// test setup
import {TestSetup, InterimAdmin, IBimaVault} from "../TestSetup.sol";

contract InterimAdminTest is TestSetup {
    function setUp() public virtual override {
        super.setUp();

        assertEq(interimAdmin.adminVoting(), address(0));
        assertEq(interimAdmin.getProposalCount(), 0);
    }

    // helper function to verify proposal data after creation
    function _verifyCreatedProposal(uint256 proposalId, InterimAdmin.Action[] memory payload) internal view {
        assertEq(interimAdmin.getProposalCreatedAt(proposalId), block.timestamp);
        assertEq(
            interimAdmin.getProposalCanExecuteAfter(proposalId),
            block.timestamp + interimAdmin.MIN_TIME_TO_EXECUTION()
        );
        assertFalse(interimAdmin.getProposalExecuted(proposalId));
        assertFalse(interimAdmin.getProposalCanExecute(proposalId));

        InterimAdmin.Action[] memory savedPayload = interimAdmin.getProposalPayload(proposalId);
        assertEq(payload.length, savedPayload.length);
        for (uint256 i; i < payload.length; i++) {
            assertEq(payload[i].target, savedPayload[i].target);
            assertEq(payload[i].data, savedPayload[i].data);
        }

        // also test view function InterminAdmin::getProposalData
        (
            uint256 createdAt,
            uint256 canExecuteAfter,
            bool executed,
            bool canExecute,
            InterimAdmin.Action[] memory savedPayload2
        ) = interimAdmin.getProposalData(proposalId);

        assertEq(createdAt, block.timestamp);
        assertEq(canExecuteAfter, block.timestamp + interimAdmin.MIN_TIME_TO_EXECUTION());
        assertEq(executed, false);
        assertEq(canExecute, false);

        assertEq(payload.length, savedPayload2.length);
        for (uint256 i; i < payload.length; i++) {
            assertEq(payload[i].target, savedPayload2[i].target);
            assertEq(payload[i].data, savedPayload2[i].data);
        }
    }

    function test_setAdminVoting_failNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");
        interimAdmin.setAdminVoting(address(0));
    }

    function test_setAdminVoting_failNotContract() external {
        vm.expectRevert("adminVoting must be a contract");
        vm.prank(users.owner);
        interimAdmin.setAdminVoting(users.user1);
    }

    function test_setAdminVoting() public {
        vm.prank(users.owner);
        interimAdmin.setAdminVoting(address(bimaVault));

        assertEq(interimAdmin.adminVoting(), address(bimaVault));
    }

    function test_setAdminVoting_failAlreadySet() external {
        test_setAdminVoting();

        vm.expectRevert("Already set");
        vm.prank(users.owner);
        interimAdmin.setAdminVoting(address(bimaCore));
    }

    function test_createNewProposal_failNotOwner() external {
        InterimAdmin.Action[] memory payload;

        vm.expectRevert("Ownable: caller is not the owner");
        interimAdmin.createNewProposal(payload);
    }

    function test_createNewProposal_failEmpty() external {
        InterimAdmin.Action[] memory payload;

        vm.expectRevert("Empty payload");
        vm.prank(users.owner);
        interimAdmin.createNewProposal(payload);
    }

    function test_createNewProposal_failSetGuardian() external {
        InterimAdmin.Action[] memory payload = new InterimAdmin.Action[](1);
        payload[0].target = address(bimaCore);
        payload[0].data = abi.encodeWithSelector(IBimaCore.setGuardian.selector, users.user1);

        vm.expectRevert("Cannot change guardian");
        vm.prank(users.owner);
        interimAdmin.createNewProposal(payload);
    }

    function test_createNewProposal() public returns (uint256 proposalId) {
        InterimAdmin.Action[] memory payload = new InterimAdmin.Action[](1);
        payload[0].target = address(bimaVault);
        payload[0].data = abi.encodeWithSelector(IBimaVault.unallocatedTotal.selector);

        vm.prank(users.owner);
        proposalId = interimAdmin.createNewProposal(payload);

        _verifyCreatedProposal(proposalId, payload);
    }

    function test_createNewProposal_failMaxDailyProposals() public {
        for (uint256 i; i < interimAdmin.MAX_DAILY_PROPOSALS(); i++) {
            test_createNewProposal();
        }

        InterimAdmin.Action[] memory payload = new InterimAdmin.Action[](1);
        payload[0].target = address(bimaCore);
        payload[0].data = abi.encodeWithSelector(IBimaVault.unallocatedTotal.selector);

        vm.expectRevert("MAX_DAILY_PROPOSALS");
        vm.prank(users.owner);
        interimAdmin.createNewProposal(payload);
    }

    function test_createNewProposal_maxDailyResetOnNewDay() external {
        test_createNewProposal_failMaxDailyProposals();
        vm.warp(block.timestamp + 1 days);
        test_createNewProposal_failMaxDailyProposals();
    }

    function test_cancelProposal_failNormalUser() external {
        uint256 proposalId = test_createNewProposal();
        vm.expectRevert("Unauthorized");
        interimAdmin.cancelProposal(proposalId);
    }

    function test_cancelProposal_failInvalidId() external {
        uint256 proposalId = test_createNewProposal();
        vm.expectRevert("Invalid ID");
        vm.prank(users.owner);
        interimAdmin.cancelProposal(proposalId + 1);
    }

    function test_cancelProposal() public returns (uint256 cancelledProposalId) {
        cancelledProposalId = test_createNewProposal();
        vm.prank(users.owner);
        interimAdmin.cancelProposal(cancelledProposalId);
        assertTrue(interimAdmin.getProposalExecuted(cancelledProposalId));
        assertFalse(interimAdmin.getProposalCanExecute(cancelledProposalId));

        cancelledProposalId = test_createNewProposal();
        vm.prank(users.guardian);
        interimAdmin.cancelProposal(cancelledProposalId);
        assertTrue(interimAdmin.getProposalExecuted(cancelledProposalId));
        assertFalse(interimAdmin.getProposalCanExecute(cancelledProposalId));
    }

    function test_cancelProposal_failAlreadyCancelled() external {
        uint256 cancelledProposalId = test_cancelProposal();

        vm.expectRevert("Already processed");
        vm.prank(users.owner);
        interimAdmin.cancelProposal(cancelledProposalId);
    }

    function test_cancelProposal_failAlreadyExecuted() external {
        uint256 executedProposalId = test_executeProposal();

        vm.expectRevert("Already processed");
        vm.prank(users.owner);
        interimAdmin.cancelProposal(executedProposalId);
    }

    function test_executeProposal_failNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");
        interimAdmin.executeProposal(0);
    }

    function test_executeProposal_failInvalidId() external {
        uint256 proposalId = test_createNewProposal();
        vm.expectRevert("Invalid ID");
        vm.prank(users.owner);
        interimAdmin.executeProposal(proposalId + 1);
    }

    function test_executeProposal_failAlreadyCancelled() external {
        uint256 cancelledProposalId = test_cancelProposal();

        vm.expectRevert("Already processed");
        vm.prank(users.owner);
        interimAdmin.executeProposal(cancelledProposalId);
    }

    function test_executeProposal_failMinTimeNotElapsed() external {
        uint256 proposalId = test_createNewProposal();
        vm.expectRevert("MIN_TIME_TO_EXECUTION");
        vm.prank(users.owner);
        interimAdmin.executeProposal(proposalId);
    }

    function test_executeProposal_failMaxTimeElapsed() external {
        uint256 proposalId = test_createNewProposal();

        vm.warp(interimAdmin.getProposalCanExecuteAfter(proposalId) + interimAdmin.MAX_TIME_TO_EXECUTION() + 1);

        vm.expectRevert("MAX_TIME_TO_EXECUTION");
        vm.prank(users.owner);
        interimAdmin.executeProposal(proposalId);
    }

    function test_executeProposal() public returns (uint256 executedProposalId) {
        executedProposalId = test_createNewProposal();

        vm.warp(interimAdmin.getProposalCanExecuteAfter(executedProposalId) + 1);
        vm.prank(users.owner);
        interimAdmin.executeProposal(executedProposalId);

        assertTrue(interimAdmin.getProposalExecuted(executedProposalId));
        assertFalse(interimAdmin.getProposalCanExecute(executedProposalId));
    }

    function test_executeProposal_failAlreadyExecuted() external {
        uint256 executedProposalId = test_executeProposal();

        vm.expectRevert("Already processed");
        vm.prank(users.owner);
        interimAdmin.executeProposal(executedProposalId);
    }

    function test_acceptTransferOwnership_failNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");
        interimAdmin.acceptTransferOwnership();
    }

    function test_acceptTransferOwnership() public {
        vm.prank(users.owner);
        bimaCore.commitTransferOwnership(address(interimAdmin));

        vm.warp(bimaCore.ownershipTransferDeadline());

        vm.prank(users.owner);
        interimAdmin.acceptTransferOwnership();

        assertEq(bimaCore.owner(), address(interimAdmin));
    }

    function test_transferOwnershipToAdminVoting_failNormalUser() external {
        vm.expectRevert("Unauthorized");
        interimAdmin.transferOwnershipToAdminVoting();
    }

    function test_transferOwnershipToAdminVoting() external {
        vm.prank(users.owner);
        interimAdmin.setAdminVoting(address(bimaVault));
        assertEq(interimAdmin.adminVoting(), address(bimaVault));

        test_acceptTransferOwnership();

        vm.prank(users.owner);
        interimAdmin.transferOwnershipToAdminVoting();
        assertEq(bimaCore.pendingOwner(), address(bimaVault));
        assertEq(bimaCore.ownershipTransferDeadline(), block.timestamp + bimaCore.OWNERSHIP_TRANSFER_DELAY());

        vm.prank(address(interimAdmin));
        bimaCore.revokeTransferOwnership();
        assertEq(bimaCore.pendingOwner(), address(0));
        assertEq(bimaCore.ownershipTransferDeadline(), 0);

        vm.prank(users.guardian);
        interimAdmin.transferOwnershipToAdminVoting();
        assertEq(bimaCore.pendingOwner(), address(bimaVault));
        assertEq(bimaCore.ownershipTransferDeadline(), block.timestamp + bimaCore.OWNERSHIP_TRANSFER_DELAY());
    }
}
