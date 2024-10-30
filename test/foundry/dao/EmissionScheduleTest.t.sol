// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup} from "../TestSetup.sol";

// dependencies
import {BIMA_100_PCT} from "../../../contracts/dependencies/Constants.sol";

contract EmissionScheduleTest is TestSetup {
    uint64 internal constant EMISSION_10_PCT = 1000; // 10%

    // helper function
    function _setWeeklyPctSchedule(
        uint256 currentWeek,
        uint64 emissionPct4,
        uint64 emissionPct3,
        uint64 emissionPct2,
        uint64 emissionPct1
    ) internal {
        // verify no scheduled emissions
        uint64[2][] memory currentScheduledWeeklyPct = emissionSchedule.getWeeklyPctSchedule();
        assertEq(currentScheduledWeeklyPct.length, 0);

        // schedule some emissions;
        // first parameter  : number of weeks from now, must be descending and unique
        // second parameter : % of unallocated BIMA supply emitted in that week
        uint64[2][] memory newScheduledWeeklyPct = new uint64[2][](4);
        newScheduledWeeklyPct[0] = [uint64(4), emissionPct4];
        newScheduledWeeklyPct[1] = [uint64(3), emissionPct3];
        newScheduledWeeklyPct[2] = [uint64(2), emissionPct2];
        newScheduledWeeklyPct[3] = [uint64(1), emissionPct1];

        vm.prank(users.owner);
        assertTrue(emissionSchedule.setWeeklyPctSchedule(newScheduledWeeklyPct));

        // verify schedule was correctly saved
        currentScheduledWeeklyPct = emissionSchedule.getWeeklyPctSchedule();
        assertEq(currentScheduledWeeklyPct.length, 4);

        for (uint256 i; i < 4; i++) {
            // verify current week was added to input week to get actual week number
            assertEq(newScheduledWeeklyPct[i][0] + currentWeek, currentScheduledWeeklyPct[i][0]);

            // verify emission percent same as input
            assertEq(newScheduledWeeklyPct[i][1], currentScheduledWeeklyPct[i][1]);
        }
    }

    function test_setWeeklyPctSchedule(
        uint64 emissionPct4,
        uint64 emissionPct3,
        uint64 emissionPct2,
        uint64 emissionPct1
    ) external {
        // bound inputs
        emissionPct4 = uint64(bound(emissionPct4, 0, BIMA_100_PCT));
        emissionPct3 = uint64(bound(emissionPct3, 0, BIMA_100_PCT));
        emissionPct2 = uint64(bound(emissionPct2, 0, BIMA_100_PCT));
        emissionPct1 = uint64(bound(emissionPct1, 0, BIMA_100_PCT));

        // warp forward 5 weeks
        vm.warp(block.timestamp + 5 weeks);
        uint256 currentWeek = emissionSchedule.getWeek();
        assertEq(currentWeek, 5);

        _setWeeklyPctSchedule(currentWeek, emissionPct4, emissionPct3, emissionPct2, emissionPct1);
    }

    function test_setWeeklyPctSchedule_sameWeekFails() external {
        // verify no scheduled emissions
        uint64[2][] memory curentScheduledWeeklyPct = emissionSchedule.getWeeklyPctSchedule();
        assertEq(curentScheduledWeeklyPct.length, 0);

        // schedule some emissions;
        // first parameter  : number of weeks from now, must be descending and unique
        // second parameter : % of unallocated BIMA supply emitted in that week
        uint64[2][] memory newScheduledWeeklyPct = new uint64[2][](2);
        newScheduledWeeklyPct[0] = [uint64(4), 1];
        newScheduledWeeklyPct[1] = [uint64(4), 1];

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
        // second parameter : % of unallocated BIMA supply emitted in that week
        uint64[2][] memory newScheduledWeeklyPct = new uint64[2][](2);
        newScheduledWeeklyPct[0] = [uint64(4), 1];
        newScheduledWeeklyPct[1] = [uint64(5), 1];

        vm.expectRevert("Must sort by week descending");
        vm.prank(users.owner);
        emissionSchedule.setWeeklyPctSchedule(newScheduledWeeklyPct);
    }

    function test_getTotalWeeklyEmissions_onlyVault() external {
        vm.expectRevert();
        emissionSchedule.getTotalWeeklyEmissions(0, 0);
    }

    function test_getTotalWeeklyEmissions(
        uint256 unallocatedTotal,
        uint64 emissionPct4,
        uint64 emissionPct3,
        uint64 emissionPct2,
        uint64 emissionPct1
    ) external {
        // bound inputs
        unallocatedTotal = bound(unallocatedTotal, 0, type(uint128).max);
        emissionPct4 = uint64(bound(emissionPct4, 0, BIMA_100_PCT));
        emissionPct3 = uint64(bound(emissionPct3, 0, BIMA_100_PCT));
        emissionPct2 = uint64(bound(emissionPct2, 0, BIMA_100_PCT));
        emissionPct1 = uint64(bound(emissionPct1, 0, BIMA_100_PCT));

        // warp forward 5 weeks
        vm.warp(block.timestamp + 5 weeks);
        uint256 currentWeek = emissionSchedule.getWeek();
        assertEq(currentWeek, 5);

        _setWeeklyPctSchedule(currentWeek, emissionPct4, emissionPct3, emissionPct2, emissionPct1);

        // warp to first week of schedule
        vm.warp(block.timestamp + 1 weeks);
        currentWeek = emissionSchedule.getWeek();
        assertEq(currentWeek, 6);

        uint256 savedLockWeeks = emissionSchedule.lockWeeks();

        vm.prank(address(bimaVault));
        (uint256 amount, uint256 lock) = emissionSchedule.getTotalWeeklyEmissions(currentWeek, unallocatedTotal);

        assertEq(amount, (unallocatedTotal * emissionPct1) / BIMA_100_PCT);

        // lockWeeks reduced by 1 and storage updated
        assertEq(lock, savedLockWeeks - 1);
        assertEq(lock, emissionSchedule.lockWeeks());

        // weeklyPct updated
        assertEq(emissionPct1, emissionSchedule.weeklyPct());

        // one schedule update removed
        assertEq(emissionSchedule.getWeeklyPctSchedule().length, 3);

        // warp to second week of schedule
        vm.warp(block.timestamp + 1 weeks);
        currentWeek = emissionSchedule.getWeek();
        assertEq(currentWeek, 7);

        vm.prank(address(bimaVault));
        (amount, lock) = emissionSchedule.getTotalWeeklyEmissions(currentWeek, unallocatedTotal);

        assertEq(amount, (unallocatedTotal * emissionPct2) / BIMA_100_PCT);

        // lockWeeks reduced by 2 and storage updated
        assertEq(lock, savedLockWeeks - 2);
        assertEq(lock, emissionSchedule.lockWeeks());

        // weeklyPct updated
        assertEq(emissionPct2, emissionSchedule.weeklyPct());

        // two schedule updates removed
        assertEq(emissionSchedule.getWeeklyPctSchedule().length, 2);

        // warp to third week of schedule
        vm.warp(block.timestamp + 1 weeks);
        currentWeek = emissionSchedule.getWeek();
        assertEq(currentWeek, 8);

        vm.prank(address(bimaVault));
        (amount, lock) = emissionSchedule.getTotalWeeklyEmissions(currentWeek, unallocatedTotal);

        assertEq(amount, (unallocatedTotal * emissionPct3) / BIMA_100_PCT);

        // lockWeeks reduced by 3 and storage updated
        assertEq(lock, savedLockWeeks - 3);
        assertEq(lock, emissionSchedule.lockWeeks());

        // weeklyPct updated
        assertEq(emissionPct3, emissionSchedule.weeklyPct());

        // three schedule updates removed
        assertEq(emissionSchedule.getWeeklyPctSchedule().length, 1);

        // warp to fourth week of schedule
        vm.warp(block.timestamp + 1 weeks);
        currentWeek = emissionSchedule.getWeek();
        assertEq(currentWeek, 9);

        vm.prank(address(bimaVault));
        (amount, lock) = emissionSchedule.getTotalWeeklyEmissions(currentWeek, unallocatedTotal);

        assertEq(amount, (unallocatedTotal * emissionPct4) / BIMA_100_PCT);

        // lockWeeks reduced by 4 and storage updated
        assertEq(lock, savedLockWeeks - 4);
        assertEq(lock, emissionSchedule.lockWeeks());

        // weeklyPct updated
        assertEq(emissionPct4, emissionSchedule.weeklyPct());

        // four schedule updates removed
        assertEq(emissionSchedule.getWeeklyPctSchedule().length, 0);

        // warp one week forward after schedule
        vm.warp(block.timestamp + 1 weeks);
        currentWeek = emissionSchedule.getWeek();
        assertEq(currentWeek, 10);

        vm.prank(address(bimaVault));
        (amount, lock) = emissionSchedule.getTotalWeeklyEmissions(currentWeek, unallocatedTotal);

        // confirm it is using values from last week of schedule
        // since that was the last modification
        assertEq(amount, (unallocatedTotal * emissionPct4) / BIMA_100_PCT);
        assertEq(lock, savedLockWeeks - 4);
        assertEq(lock, emissionSchedule.lockWeeks());
        assertEq(emissionPct4, emissionSchedule.weeklyPct());
        assertEq(emissionSchedule.getWeeklyPctSchedule().length, 0);
    }

    function test_setLockParameters_failNotOwner() external {
        vm.expectRevert("Only owner");
        emissionSchedule.setLockParameters(0, 0);
    }

    function test_setLockParameters_failExceedMaxLockWeeks() external {
        uint64 lockWeeks = uint64(emissionSchedule.MAX_LOCK_WEEKS()) + 1;

        vm.expectRevert("Cannot exceed MAX_LOCK_WEEKS");
        vm.prank(users.owner);
        emissionSchedule.setLockParameters(lockWeeks, 0);
    }

    function test_setLockParameters_failZeroDecayWeeks() external {
        uint64 lockWeeks = uint64(emissionSchedule.MAX_LOCK_WEEKS());

        vm.expectRevert("Decay weeks cannot be 0");
        vm.prank(users.owner);
        emissionSchedule.setLockParameters(lockWeeks, 0);
    }

    function test_setLockParameters(uint64 lockWeeks, uint64 decayWeeks) external {
        lockWeeks = uint64(bound(lockWeeks, 0, emissionSchedule.MAX_LOCK_WEEKS()));
        decayWeeks = uint64(bound(decayWeeks, 1, type(uint64).max));

        vm.prank(users.owner);
        assertTrue(emissionSchedule.setLockParameters(lockWeeks, decayWeeks));

        assertEq(emissionSchedule.lockWeeks(), lockWeeks);
        assertEq(emissionSchedule.lockDecayWeeks(), decayWeeks);
    }
}
