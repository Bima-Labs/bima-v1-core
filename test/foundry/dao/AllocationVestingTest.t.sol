// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IBabelVault, ITokenLocker} from "../TestSetup.sol";
import {AllocationVesting} from "./../../../contracts/dao/AllocationVesting.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AllocationVestingTest is TestSetup {
    AllocationVesting internal allocationVesting;

    uint256 internal constant totalAllocation = 100_000_000e18;
    uint256 internal constant maxTotalPreclaimPct = 10;

    function setUp() public virtual override {
        super.setUp();

        allocationVesting = new AllocationVesting(IERC20(address(babelToken)),
                                                  tokenLocker,
                                                  totalAllocation,
                                                  address(babelVault),
                                                  maxTotalPreclaimPct);
    }

    function test_transferPoints_failSelfTransfer() external {
        AllocationVesting.AllocationSplit[] memory allocationSplits
            = new AllocationVesting.AllocationSplit[](2);

        uint24 INIT_POINTS = 50000;

        // allocate to 2 users 50% 50%
        allocationSplits[0].recipient = users.user1;
        allocationSplits[0].points = INIT_POINTS;
        allocationSplits[0].numberOfWeeks = 4;

        allocationSplits[1].recipient = users.user2;
        allocationSplits[1].points = INIT_POINTS;
        allocationSplits[1].numberOfWeeks = 4;

        // setup allocations
        uint256 vestingStart = block.timestamp + 1 weeks;
        allocationVesting.setAllocations(allocationSplits, vestingStart);

        // warp to start time
        vm.warp(vestingStart + 1);

        // reverts on self-transfer exploit which would allow infinite point generation
        vm.expectRevert(AllocationVesting.SelfTransfer.selector);
        vm.prank(users.user1);
        allocationVesting.transferPoints(users.user1, users.user1, INIT_POINTS);
    }
}