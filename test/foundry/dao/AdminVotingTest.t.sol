// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AdminVoting} from "../../../contracts/dao/AdminVoting.sol";

// test setup
import {TestSetup} from "../TestSetup.sol";

contract AdminVotingTest is TestSetup {
    AdminVoting adminVoting;


    uint256 constant internal INIT_MIN_CREATE_PROP_PCT = 10;   // 0.01%
    uint256 constant internal INIT_PROP_PASSING_PCT    = 2000; // 20%

    function setUp() public virtual override {
        super.setUp();

        adminVoting = new AdminVoting(address(babelCore),
                                      tokenLocker,
                                      INIT_MIN_CREATE_PROP_PCT,
                                      INIT_PROP_PASSING_PCT);
    }

    function test_constructor() external view {
        // parameters correctly set
        assertEq(adminVoting.minCreateProposalPct(), INIT_MIN_CREATE_PROP_PCT);
        assertEq(adminVoting.passingPct(), INIT_PROP_PASSING_PCT);
        assertEq(address(adminVoting.tokenLocker()), address(tokenLocker));

        // week initialized to zero
        assertEq(adminVoting.getWeek(), 0);
        assertEq(adminVoting.minCreateProposalWeight(), 0);

        // no proposals
        assertEq(adminVoting.getProposalCount(), 0);
    }

    function test_createNewProposal_inInitialState() external {
        // create dummy proposal
        AdminVoting.Action[] memory payload = new AdminVoting.Action[](1);
        payload[0].target = address(0x0);
        payload[0].data   = abi.encode("");

        uint256 lastProposalTimestamp = adminVoting.latestProposalTimestamp(users.user1);
        assertEq(lastProposalTimestamp, 0);

        // verify no proposals can be created in first week
        vm.startPrank(users.user1);
        vm.expectRevert("No proposals in first week");
        adminVoting.createNewProposal(users.user1, payload);

        // advance time by 1 week
        vm.warp(block.timestamp + 1 weeks);
        uint256 weekNum = 1;
        assertEq(adminVoting.getWeek(), weekNum);

        // verify there are no tokens locked
        assertEq(tokenLocker.getTotalWeightAt(weekNum), 0);

        // verify no proposals can be created if there is no
        // total voting weight in that week
        vm.expectRevert("Zero total voting weight for given week");
        adminVoting.createNewProposal(users.user1, payload);
        vm.stopPrank();
    }
}