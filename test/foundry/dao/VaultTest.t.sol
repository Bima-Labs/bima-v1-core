// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup, IBabelVault, BabelVault, IIncentiveVoting, ITokenLocker} from "../TestSetup.sol";

contract VaultTest is TestSetup {
    
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
        IBabelVault.InitialAllowance[] memory initialAllowances;

        vm.prank(users.owner);
        babelVault.setInitialParameters(emissionSchedule,
                                        boostCalc,
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