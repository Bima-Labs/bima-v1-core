// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup} from "../TestSetup.sol";
import {AllocationVesting} from "./../../../contracts/dao/AllocationVesting.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AllocationVestingTest is TestSetup {
    AllocationVesting internal allocationVesting;

    uint256 internal constant totalAllocation = 100_000_000e18;
    uint256 internal constant maxTotalPreclaimPct = 10;
    uint24 internal constant INIT_USER_POINTS = 50_000;

    function setUp() public virtual override {
        super.setUp();

        // first setup the vault
        _vaultSetDefaultInitialParameters();

        // then create the AllocationVesting contract
        allocationVesting = new AllocationVesting(
            IERC20(address(bimaToken)),
            tokenLocker,
            totalAllocation,
            address(bimaVault),
            maxTotalPreclaimPct
        );

        // BimaVault needs to give max approval to AllocationVesting contract
        vm.prank(address(bimaVault));
        bimaToken.approve(address(allocationVesting), type(uint256).max);
    }

    function test_transferPoints_failSelfTransfer() external {
        AllocationVesting.AllocationSplit[] memory allocationSplits = new AllocationVesting.AllocationSplit[](2);

        // allocate to 2 users 50% 50%
        allocationSplits[0].recipient = users.user1;
        allocationSplits[0].points = INIT_USER_POINTS;
        allocationSplits[0].numberOfWeeks = 4;

        allocationSplits[1].recipient = users.user2;
        allocationSplits[1].points = INIT_USER_POINTS;
        allocationSplits[1].numberOfWeeks = 4;

        // setup allocations
        uint256 vestingStart = block.timestamp + 1 weeks;
        allocationVesting.setAllocations(allocationSplits, vestingStart);

        // warp to start time
        vm.warp(vestingStart + 1);

        // reverts on self-transfer exploit which would allow infinite point generation
        vm.expectRevert(AllocationVesting.SelfTransfer.selector);
        vm.prank(users.user1);
        allocationVesting.transferPoints(users.user1, users.user1, INIT_USER_POINTS);
    }

    function test_transferPoints_failBypassVestingViaPreclaim() external {
        AllocationVesting.AllocationSplit[] memory allocationSplits = new AllocationVesting.AllocationSplit[](2);

        // allocate to 2 users 50% 50%
        allocationSplits[0].recipient = users.user1;
        allocationSplits[0].points = INIT_USER_POINTS;
        allocationSplits[0].numberOfWeeks = 4;

        allocationSplits[1].recipient = users.user2;
        allocationSplits[1].points = INIT_USER_POINTS;
        allocationSplits[1].numberOfWeeks = 4;

        // setup allocations
        uint256 vestingStart = block.timestamp + 1 weeks;
        allocationVesting.setAllocations(allocationSplits, vestingStart);

        // warp to start time
        vm.warp(vestingStart + 1);

        // each entity receiving allocations is entitled to 10% preclaim
        // which they can use to get voting power by locking it up in TokenLocker
        uint256 MAX_PRECLAIM = (maxTotalPreclaimPct * totalAllocation) / (2 * 100);

        // verify preclaimable amount before claiming
        assertEq(allocationVesting.preclaimable(users.user1), MAX_PRECLAIM);

        // attempting to claim over MAX_PRECLAIM fails
        vm.expectRevert(AllocationVesting.PreclaimTooLarge.selector);
        vm.prank(users.user1);
        allocationVesting.lockFutureClaims(users.user1, MAX_PRECLAIM + 1);

        // user1 does this once, passing 0 to preclaim max possible
        vm.prank(users.user1);
        allocationVesting.lockFutureClaims(users.user1, 0);

        // user1 has now preclaimed the max allowed
        (uint24 points, , , uint96 preclaimed) = allocationVesting.allocations(users.user1);
        assertEq(preclaimed, MAX_PRECLAIM);

        // verify preclaimable amount now 0
        assertEq(allocationVesting.preclaimable(users.user1), 0);

        // user1 attempts it again but this fails
        // as nothing can be claimed
        vm.expectRevert("Amount must be nonzero");
        vm.prank(users.user1);
        allocationVesting.lockFutureClaimsWithReceiver(users.user1, users.user1, 0);

        // user 1 needs to wait 3 days to bypass LockedAllocation revert
        vm.warp(block.timestamp + 3 days);

        // user1 calls `transferPoints` to move their points to a new address
        address user1Second = address(0x1337);
        vm.prank(users.user1);
        allocationVesting.transferPoints(users.user1, user1Second, INIT_USER_POINTS);

        // but since `transferPoints` transfers preclaimed amounts, the
        // new address has its preclaimed amounts updated
        (points, , , preclaimed) = allocationVesting.allocations(user1Second);
        assertEq(preclaimed, MAX_PRECLAIM);
        assertEq(points, INIT_USER_POINTS);

        // old address has its preclaimed amounts reduced and also points
        (points, , , preclaimed) = allocationVesting.allocations(users.user1);
        assertEq(preclaimed, 0);
        assertEq(points, 0);

        // both new and old address preclaimable amounts are 0
        assertEq(allocationVesting.preclaimable(users.user1), 0);
        assertEq(allocationVesting.preclaimable(user1Second), 0);
    }

    function test_transferPoints_failIncompatibleVestingPeriod() external {
        AllocationVesting.AllocationSplit[] memory allocationSplits = new AllocationVesting.AllocationSplit[](2);

        // allocate to 2 users 50% 50%
        allocationSplits[0].recipient = users.user1;
        allocationSplits[0].points = INIT_USER_POINTS;
        allocationSplits[0].numberOfWeeks = 4;

        // user 2 gets different vesting weeks
        allocationSplits[1].recipient = users.user2;
        allocationSplits[1].points = INIT_USER_POINTS;
        allocationSplits[1].numberOfWeeks = 5;

        // setup allocations
        uint256 vestingStart = block.timestamp + 1 weeks;
        allocationVesting.setAllocations(allocationSplits, vestingStart);

        // warp to start time
        vm.warp(vestingStart + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AllocationVesting.IncompatibleVestingPeriod.selector,
                allocationSplits[0].numberOfWeeks,
                allocationSplits[1].numberOfWeeks
            )
        );
        vm.prank(users.user1);
        allocationVesting.transferPoints(users.user1, users.user2, INIT_USER_POINTS);
    }

    function test_claim_failNothingToClaim() external {
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        allocationVesting.claim(address(this));
    }

    function test_claim() public {
        AllocationVesting.AllocationSplit[] memory allocationSplits = new AllocationVesting.AllocationSplit[](2);

        // allocate to 2 users 50% 50%
        allocationSplits[0].recipient = users.user1;
        allocationSplits[0].points = INIT_USER_POINTS;
        allocationSplits[0].numberOfWeeks = 4;

        allocationSplits[1].recipient = users.user2;
        allocationSplits[1].points = INIT_USER_POINTS;
        allocationSplits[1].numberOfWeeks = 4;

        // setup allocations
        uint256 vestingStart = block.timestamp + 1 weeks;
        allocationVesting.setAllocations(allocationSplits, vestingStart);

        // warp to end of vesting time
        vm.warp(vestingStart + 4 weeks);

        // verify unclaimed amounts
        uint256 expectedClaimPerUser = totalAllocation / 2;

        assertEq(allocationVesting.unclaimed(users.user1), expectedClaimPerUser);
        assertEq(allocationVesting.unclaimed(users.user2), expectedClaimPerUser);
        assertEq(allocationVesting.claimableNow(users.user1), expectedClaimPerUser);
        assertEq(allocationVesting.claimableNow(users.user2), expectedClaimPerUser);

        // claim
        vm.prank(users.user1);
        allocationVesting.claim(users.user1);

        vm.prank(users.user2);
        allocationVesting.claim(users.user2);

        // verify end state
        assertEq(bimaToken.balanceOf(users.user1), expectedClaimPerUser);
        assertEq(bimaToken.balanceOf(users.user2), expectedClaimPerUser);
        assertEq(allocationVesting.getClaimed(users.user1), expectedClaimPerUser);
        assertEq(allocationVesting.getClaimed(users.user2), expectedClaimPerUser);

        assertEq(allocationVesting.unclaimed(users.user1), 0);
        assertEq(allocationVesting.unclaimed(users.user2), 0);
        assertEq(allocationVesting.claimableNow(users.user1), 0);
        assertEq(allocationVesting.claimableNow(users.user2), 0);
    }

    function test_claim_failAlreadyClaimed() external {
        test_claim();

        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        vm.prank(users.user1);
        allocationVesting.claim(users.user1);
    }
}
