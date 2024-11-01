// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {TestSetup} from "../TestSetup.sol";

import {StorkOracleWrapper, IStorkOracle} from "../../../contracts/wrappers/StorkOracleWrapper.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";

import {console} from "forge-std/console.sol";

contract MockStorkOracle {
    uint64 public timestampNs;
    int192 public quantizedValue;

    function getTemporalNumericValueV1(bytes32) external view returns (uint64, int192) {
        return (timestampNs, quantizedValue);
    }

    function setPrice(int192 _quantizedValue) public {
        timestampNs = uint64(block.timestamp * 1e9);
        quantizedValue = _quantizedValue;
    }
}

contract StorkOracleWrapperMockedTest is TestSetup {
    MockStorkOracle public storkOracle;
    StorkOracleWrapper public storkOracleWrapper;

    bytes32 public encodedAssetId;

    function testInitialState() public {
        _setUp();

        assertEq(address(storkOracleWrapper.storkOracle()), address(storkOracle));
        assertEq(storkOracleWrapper.encodedAssetId(), bytes32(0));
        assertEq(storkOracleWrapper.decimals(), storkOracleWrapper.DECIMAL_PRECISION());
        assertEq(storkOracleWrapper.description(), "AggregatorV3Interface Wrapper for Stork Oracle");
        assertEq(storkOracleWrapper.version(), 1);
    }

    function test_latestRoundData(int192 price, uint32 blockTimestamp) public {
        vm.warp(blockTimestamp);

        _setUp();

        storkOracle.setPrice(price);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, ) = storkOracleWrapper.latestRoundData();

        assertEq(block.timestamp, blockTimestamp);

        assertEq(roundId, block.timestamp / 1 seconds);
        assertEq(answer, price);
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
    }

    function test_roundData(int192 price, uint32 blockTimestamp, uint80 _roundId) public {
        vm.assume(blockTimestamp > 100);

        vm.warp(blockTimestamp);

        _setUp();

        storkOracle.setPrice(price);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, ) = storkOracleWrapper.getRoundData(
            _roundId
        );

        assertEq(block.timestamp, blockTimestamp);

        assertEq(roundId, _roundId);
        assertEq(answer, price);
        assertEq(startedAt, block.timestamp - 1 seconds);
        assertEq(updatedAt, block.timestamp - 1 seconds);
    }

    // Test how the PriceFeed contract will handle the price change, if the new price has been set under a minute
    function test_PriceChangeUnderMinute() public {
        _setUp();

        vm.startPrank(users.owner);

        MockERC20 collateral = new MockERC20();

        storkOracle.setPrice(60_000e18);

        priceFeed.setOracle(address(collateral), address(storkOracleWrapper), 80000, bytes4(0x00000000), 18, false);

        assertEq(priceFeed.fetchPrice(address(collateral)), 60_000e18);

        skip(1.1 minutes);

        storkOracle.setPrice(70_000e18);

        assertEq(priceFeed.fetchPrice(address(collateral)), 70_000e18);

        skip(0.1 minutes);

        storkOracle.setPrice(10_000e18);

        assertEq(priceFeed.fetchPrice(address(collateral)), 10_000e18);
    }

    // Test how the PriceFeed contract will handle the stale price, which hasn't been updated for a while
    function test_StalePrice(uint32 heartbeat) public {
        vm.assume(heartbeat > 0 && heartbeat <= 1 days);

        _setUp();

        vm.startPrank(users.owner);

        MockERC20 collateral = new MockERC20();

        storkOracle.setPrice(60_000e18);

        priceFeed.setOracle(address(collateral), address(storkOracleWrapper), heartbeat, bytes4(0x00000000), 18, false);

        skip(heartbeat + priceFeed.RESPONSE_TIMEOUT_BUFFER() + 1);

        vm.expectRevert();
        priceFeed.fetchPrice(address(collateral));
    }

    function _setUp() internal {
        storkOracle = new MockStorkOracle();

        storkOracleWrapper = new StorkOracleWrapper(address(storkOracle), bytes32(0));
    }
}
