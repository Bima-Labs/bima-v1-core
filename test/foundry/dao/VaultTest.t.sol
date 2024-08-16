// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// vault specific members
import {IEmissionSchedule} from "../../../contracts/interfaces/IEmissionSchedule.sol";
import {IBoostCalculator} from "../../../contracts/interfaces/IBoostCalculator.sol";
import {EmissionSchedule} from "../../../contracts/dao/EmissionSchedule.sol";
import {BoostCalculator} from "../../../contracts/dao/BoostCalculator.sol";

// test setup
import {TestSetup, IBabelVault, BabelVault, IIncentiveVoting, ITokenLocker} from "../TestSetup.sol";

contract VaultTest is TestSetup {
    // only vault uses these
    EmissionSchedule internal emissionSchedule;
    BoostCalculator  internal boostCalc;

    uint256 internal constant INIT_BS_GRACE_WEEKS = 1;
    uint64 internal constant INIT_ES_LOCK_WEEKS = 4;
    uint64 internal constant INIT_ES_LOCK_DECAY_WEEKS = 1;
    uint64 internal constant INIT_ES_WEEKLY_PCT = 2500; // 25%
    uint64[2][] internal scheduledWeeklyPct;

    uint256 internal constant INIT_BAB_TKN_TOTAL_SUPPLY = 1_000_000e18;
    uint64 internal constant INIT_VLT_LOCK_WEEKS = 2;

    function setUp() public virtual override {
        super.setUp();
        
        // create EmissionSchedule
        emissionSchedule = new EmissionSchedule(address(babelCore), 
                                                IIncentiveVoting(address(incentiveVoting)),
                                                IBabelVault(address(babelVault)),
                                                INIT_ES_LOCK_WEEKS,
                                                INIT_ES_LOCK_DECAY_WEEKS,
                                                INIT_ES_WEEKLY_PCT,
                                                scheduledWeeklyPct);

        // create BoostCalculator
        boostCalc = new BoostCalculator(address(babelCore),
                                        ITokenLocker(address(tokenLocker)),
                                        INIT_BS_GRACE_WEEKS);
    }

    function test_constructor() external view {
        // addresses correctly set
        assertEq(address(babelVault.babelToken()), address(babelToken));
        assertEq(address(babelVault.locker()), address(tokenLocker));
        assertEq(address(babelVault.voter()), address(incentiveVoting));
        assertEq(babelVault.deploymentManager(), users.owner);
        assertEq(babelVault.lockToTokenRatio(), INIT_LOCK_TO_TOKEN_RATIO);

        // StabilityPool made receiver with ID 0
        (address account, bool isActive) = babelVault.idToReceiver(0);        
        assertEq(account, address(stabilityPool));
        assertEq(isActive, true);

        // IncentiveVoting receiver count was increased by 1
        assertEq(incentiveVoting.receiverCount(), 1);
    }

    function test_setInitialParameters() public {
        uint128[] memory _fixedInitialAmounts;
        BabelVault.InitialAllowance[] memory initialAllowances;

        vm.prank(users.owner);
        babelVault.setInitialParameters(emissionSchedule,
                                        IBoostCalculator(address(boostCalc)),
                                        INIT_BAB_TKN_TOTAL_SUPPLY,
                                        INIT_VLT_LOCK_WEEKS,
                                        _fixedInitialAmounts,
                                        initialAllowances);

        // addresses correctly set
        assertEq(address(babelVault.emissionSchedule()), address(emissionSchedule));
        assertEq(address(babelVault.boostCalculator()), address(boostCalc));

        // BabelToken supply correct
        assertEq(babelToken.totalSupply(), INIT_BAB_TKN_TOTAL_SUPPLY);
        assertEq(babelToken.maxTotalSupply(), INIT_BAB_TKN_TOTAL_SUPPLY);

        // BabelToken supply minted to BabelVault
        assertEq(babelToken.balanceOf(address(babelVault)), INIT_BAB_TKN_TOTAL_SUPPLY);

        // BabelVault::unallocatedTotal correct (no initial allowances)
        assertEq(babelVault.unallocatedTotal(), INIT_BAB_TKN_TOTAL_SUPPLY);

        // BabelVault::totalUpdateWeek correct
        assertEq(babelVault.totalUpdateWeek(), _fixedInitialAmounts.length + babelVault.getWeek());

        // BabelVault::lockWeeks correct
        assertEq(babelVault.lockWeeks(), INIT_VLT_LOCK_WEEKS);

    }
}