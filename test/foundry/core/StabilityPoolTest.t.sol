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
}