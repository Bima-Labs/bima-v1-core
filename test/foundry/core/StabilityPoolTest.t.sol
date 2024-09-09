// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup} from "../TestSetup.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StabilityPoolTest is TestSetup {

    function setUp() public virtual override {
        super.setUp();

        // only 1 collateral token exists due to base setup
        assertEq(stabilityPool.getNumCollateralTokens(), 1);
    }

    function test_enableCollateral() public returns(IERC20 newCollateral) {
        // add 1 new collateral
        newCollateral = IERC20(address(0x1234));

        vm.prank(address(factory));
        stabilityPool.enableCollateral(newCollateral);

        // verify storage
        assertEq(stabilityPool.getNumCollateralTokens(), 2);
        assertEq(stabilityPool.indexByCollateral(newCollateral), 2);
        assertEq(address(stabilityPool.collateralTokens(1)), address(newCollateral));
    }

    function test_enableCollateral_failToAddMoreThanMaxCollaterals() external {
        for(uint160 i=1; i<=255; i++) {
            address newCollateral = address(i);

            vm.prank(address(factory));
            stabilityPool.enableCollateral(IERC20(newCollateral));
        }

        // try to add one more
        vm.expectRevert("Maximum collateral length reached");
        vm.prank(address(factory));
        stabilityPool.enableCollateral(IERC20(address(uint160(256))));
    }

    function test_startCollateralSunset() public returns(IERC20 sunsetCollateral) {
        // first add new collateral
        sunsetCollateral = test_enableCollateral();

        // get sunset queue before sunset
        (, uint16 nextSunsetIndexKeyPre) = stabilityPool.getSunsetQueueKeys();

        // then sunset it
        vm.prank(users.owner);
        stabilityPool.startCollateralSunset(sunsetCollateral);

        // verify storage
        assertEq(stabilityPool.getNumCollateralTokens(), 2);
        assertEq(stabilityPool.indexByCollateral(sunsetCollateral), 0);
        assertEq(address(stabilityPool.collateralTokens(1)), address(sunsetCollateral));
        
        (uint128 idx, uint128 expiry) = stabilityPool.getSunsetIndexes(nextSunsetIndexKeyPre);
        assertEq(idx, 1);
        assertEq(expiry, block.timestamp + stabilityPool.SUNSET_DURATION());

        (, uint16 nextSunsetIndexKeyPost) = stabilityPool.getSunsetQueueKeys();
        assertEq(nextSunsetIndexKeyPost, nextSunsetIndexKeyPre + 1);
    }

    function test_enableCollateral_overwriteSunsetCollateral() external {
        // first add new collateral then sunset it
        IERC20 sunsetCollateral = test_startCollateralSunset();

        // then add another new collateral
        IERC20 newCollateral1 = IERC20(address(0x12345));
        vm.prank(address(factory));
        stabilityPool.enableCollateral(newCollateral1);

        // verify storage
        assertEq(stabilityPool.getNumCollateralTokens(), 3);
        assertEq(stabilityPool.indexByCollateral(newCollateral1), 3);
        assertEq(address(stabilityPool.collateralTokens(1)), address(sunsetCollateral));
        assertEq(address(stabilityPool.collateralTokens(2)), address(newCollateral1));

        // warp time past the sunset expiry
        vm.warp(block.timestamp + stabilityPool.SUNSET_DURATION() + 1);

        // get sunset queue before overwrite
        (uint16 firstSunsetIndexKeyPre, ) = stabilityPool.getSunsetQueueKeys();

        // add 1 more new collateral; this should over-write the sunsetted one
        IERC20 newCollateral2 = IERC20(address(0x123456));

        vm.prank(address(factory));
        stabilityPool.enableCollateral(newCollateral2);

        // verify that this over-wrote the sunsetted collateral
        assertEq(stabilityPool.getNumCollateralTokens(), 3);
        assertEq(stabilityPool.indexByCollateral(newCollateral2), 2);
        assertEq(stabilityPool.indexByCollateral(sunsetCollateral), 0);
        assertEq(address(stabilityPool.collateralTokens(1)), address(newCollateral2));
        assertEq(address(stabilityPool.collateralTokens(2)), address(newCollateral1));

        (uint128 idx, uint128 expiry) = stabilityPool.getSunsetIndexes(firstSunsetIndexKeyPre);
        assertEq(idx, 0);
        assertEq(expiry, 0);

        (uint16 firstSunsetIndexKeyPost, ) = stabilityPool.getSunsetQueueKeys();
        assertEq(firstSunsetIndexKeyPost, firstSunsetIndexKeyPre + 1);
    }

    // used to get around "stack too deep errors"
    struct DepositWithdrawState {
        uint128 accountTotalDep;
        uint128 accountLastDepositTime;
        uint256 totalDebtTokenDeposits;
        uint128 scale;
        uint128 epoch;
        uint256 userDebtTokenBalance;
        uint256 poolDebtTokenBalance;
    }
    function _getDepositWithdrawState(address user) internal view returns (DepositWithdrawState memory state) {
        (state.accountTotalDep, state.accountLastDepositTime) = stabilityPool.accountDeposits(user);
        state.totalDebtTokenDeposits = stabilityPool.getTotalDebtTokenDeposits();
        state.scale = stabilityPool.currentScale();
        state.epoch = stabilityPool.currentEpoch();
        state.userDebtTokenBalance = debtToken.balanceOf(user);
        state.poolDebtTokenBalance = debtToken.balanceOf(address(stabilityPool));
    }

    // helper function to execute one or more successful deposits into the stability pool
    function _provideToSP(address user, uint96 depositAmount, uint256 numDeposits) internal {
        // cache state before call
        DepositWithdrawState memory statePre = _getDepositWithdrawState(user);

        for(uint256 i=1; i<=numDeposits; i++) {
            // mint user1 some tokens
            vm.prank(address(borrowerOps));
            debtToken.mint(user, depositAmount);
            assertEq(debtToken.balanceOf(user), depositAmount);

            // user1 deposits them into stability pool
            vm.prank(user);
            stabilityPool.provideToSP(depositAmount);

            // verify depositor lost tokens so balance remains the same as
            // tokens were just minted to the user
            assertEq(debtToken.balanceOf(user), statePre.userDebtTokenBalance);

            // verify stability pool received tokens
            assertEq(debtToken.balanceOf(address(stabilityPool)),
                     statePre.poolDebtTokenBalance + depositAmount*i);

            // verify storage updates
            assertEq(stabilityPool.getTotalDebtTokenDeposits(),
                     statePre.totalDebtTokenDeposits + depositAmount*i);

            (uint128 accountTotalDepPost, uint128 accountLastDepositTimePost) = stabilityPool.accountDeposits(user);
            assertEq(accountTotalDepPost, statePre.accountTotalDep + depositAmount*i);
            assertEq(accountLastDepositTimePost, block.timestamp);

            assertEq(stabilityPool.getStoredPendingReward(user), 0);

            assertEq(stabilityPool.currentScale(), statePre.scale);
            assertEq(stabilityPool.currentEpoch(), statePre.epoch);

            (uint256 depositorP, uint256 depositorG, uint128 depositorScale, uint128 depositorEpoch)
                = stabilityPool.depositSnapshots(user);
            
            assertEq(depositorP, stabilityPool.P());
            assertEq(depositorG, stabilityPool.epochToScaleToG(statePre.epoch, statePre.scale));
            assertEq(depositorScale, statePre.scale);
            assertEq(depositorEpoch, statePre.epoch);
        }
    }

    function test_provideToSP(uint96 depositAmount, uint256 numDeposits) external {
        // bound fuzz inputs
        depositAmount = uint96(bound(depositAmount, 1, type(uint96).max));
        numDeposits   = bound(numDeposits, 1, 10);

        _provideToSP(users.user1, depositAmount, numDeposits);
    }

    // helper function to execute a successful withdrawal from the stability pool
    function _withdrawFromToSP(address user, uint96 withdrawAmount) internal {
        // cache state before call
        DepositWithdrawState memory statePre = _getDepositWithdrawState(user);

        // then perform the withdrawal
        vm.prank(user);
        stabilityPool.withdrawFromSP(withdrawAmount);

        // verify depositor received withdrawn tokens
        assertEq(debtToken.balanceOf(user), statePre.userDebtTokenBalance + withdrawAmount);

        // verify stability pool sent tokens
        assertEq(debtToken.balanceOf(address(stabilityPool)),
                 statePre.poolDebtTokenBalance - withdrawAmount);

        // verify storage updates
        assertEq(stabilityPool.getTotalDebtTokenDeposits(),
                 statePre.totalDebtTokenDeposits - withdrawAmount);

        (uint128 accountTotalDepPost, uint128 accountLastDepositTimePost) = stabilityPool.accountDeposits(user);
        assertEq(accountTotalDepPost, statePre.accountTotalDep - withdrawAmount);
        assertEq(accountLastDepositTimePost, statePre.accountLastDepositTime);

        assertEq(stabilityPool.getStoredPendingReward(user), 0);

        assertEq(stabilityPool.currentScale(), statePre.scale);
        assertEq(stabilityPool.currentEpoch(), statePre.epoch);

        (uint256 depositorP, uint256 depositorG, uint128 depositorScale, uint128 depositorEpoch)
            = stabilityPool.depositSnapshots(user);
        
        if(accountTotalDepPost == 0) {
            assertEq(depositorP, 0);
            assertEq(depositorG, 0);
            assertEq(depositorScale, 0);
            assertEq(depositorEpoch, 0);
        }
        else {
            assertEq(depositorP, stabilityPool.P());
            assertEq(depositorG, stabilityPool.epochToScaleToG(statePre.epoch, statePre.scale));
            assertEq(depositorScale, statePre.scale);
            assertEq(depositorEpoch, statePre.epoch);
        }
    }

    function test_withdrawFromSP(uint96 depositAmount, uint96 withdrawAmount) external {
        // bound fuzz inputs
        depositAmount  = uint96(bound(depositAmount, 1, type(uint96).max));
        withdrawAmount = uint96(bound(withdrawAmount, 1, depositAmount));

        // first perform a deposit
        _provideToSP(users.user1, depositAmount, 1);

        // warp forward since deposits & withdraws not allowed in same block
        vm.warp(block.timestamp + 1);

        _withdrawFromToSP(users.user1, withdrawAmount);
    }
}