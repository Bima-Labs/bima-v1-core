// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup} from "../TestSetup.sol";

contract EmissionScheduleTest is TestSetup {

    function test_setWeeklyPctSchedule() external {
        // warp forward 5 weeks
        vm.warp(block.timestamp + 5 weeks);
        uint256 currentWeek = emissionSchedule.getWeek();
        assertEq(currentWeek, 5);

        // verify no scheduled emissions
        uint64[2][] memory currentScheduledWeeklyPct = emissionSchedule.getWeeklyPctSchedule();
        assertEq(currentScheduledWeeklyPct.length, 0);

        // schedule some emissions;
        // first parameter  : number of weeks from now, must be descending and unique
        // second parameter : % of unallocated BABEL supply emitted in that week
        uint64[2][] memory newScheduledWeeklyPct = new uint64[2][](4);
        newScheduledWeeklyPct[0] = [uint64(4),1];
        newScheduledWeeklyPct[1] = [uint64(3),1];
        newScheduledWeeklyPct[2] = [uint64(2),1];
        newScheduledWeeklyPct[3] = [uint64(1),1];

        vm.prank(users.owner);
        assertTrue(emissionSchedule.setWeeklyPctSchedule(newScheduledWeeklyPct));

        // verify schedule was correctly saved
        currentScheduledWeeklyPct = emissionSchedule.getWeeklyPctSchedule();
        assertEq(currentScheduledWeeklyPct.length, 4);

        for(uint256 i; i<4; i++) {
            // verify current week was added to input week to get actual week number
            assertEq(newScheduledWeeklyPct[i][0] + currentWeek, currentScheduledWeeklyPct[i][0]);

            // verify emission percent same as input
            assertEq(newScheduledWeeklyPct[i][1], currentScheduledWeeklyPct[i][1]);
        }
    }

    function test_setWeeklyPctSchedule_sameWeekFails() external {
        // verify no scheduled emissions
        uint64[2][] memory curentScheduledWeeklyPct = emissionSchedule.getWeeklyPctSchedule();
        assertEq(curentScheduledWeeklyPct.length, 0);

        // schedule some emissions;
        // first parameter  : number of weeks from now, must be descending and unique
        // second parameter : % of unallocated BABEL supply emitted in that week
        uint64[2][] memory newScheduledWeeklyPct = new uint64[2][](2);
        newScheduledWeeklyPct[0] = [uint64(4),1];
        newScheduledWeeklyPct[1] = [uint64(4),1];

        vm.expectRevert("Must sort by week descending");
        vm.prank(users.owner);
        emissionSchedule.setWeeklyPctSchedule(newScheduledWeeklyPct);
    }

    function test_setWeeklyPctSchedule_ascendingWeekFails() external {
        // verify no scheduled emissions
        uint64[2][] memory curentScheduledWeeklyPct = emissionSchedule.getWeeklyPctSchedule();
        assertEq(curentScheduledWeeklyPct.length, 0);

        // schedule some emissions;
        // first parameter  : number of weeks from now, must be descending and unique
        // second parameter : % of unallocated BABEL supply emitted in that week
        uint64[2][] memory newScheduledWeeklyPct = new uint64[2][](2);
        newScheduledWeeklyPct[0] = [uint64(4),1];
        newScheduledWeeklyPct[1] = [uint64(5),1];

        vm.expectRevert("Must sort by week descending");
        vm.prank(users.owner);
        emissionSchedule.setWeeklyPctSchedule(newScheduledWeeklyPct);
    }
}