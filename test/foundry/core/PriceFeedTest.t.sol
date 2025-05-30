// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// test setup
import {TestSetup} from "../TestSetup.sol";

// mocks
import {MockOracle} from "../../../contracts/mock/MockOracle.sol";
import {PriceFeed} from "../../../contracts/core/PriceFeed.sol";
// forge
import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";

error PriceFeed__FeedFrozenError(address token);
error PriceFeed__InvalidFeedResponseError(address token);
error PriceFeed__UnknownFeedError(address token);

contract PriceFeedTest is TestSetup {
    MockOracle mockOracle2;

    function setUp() public virtual override {
        super.setUp();

        mockOracle2 = new MockOracle();
    }

    function test_setOracle_invalidFeedResponse() external {
        vm.startPrank(users.owner);

        mockOracle2.setResponse(1, 60_000e8, block.timestamp, block.timestamp, 1);

        vm.expectRevert(abi.encodeWithSelector(PriceFeed__InvalidFeedResponseError.selector, address(stakedBTC)));
        priceFeed.setOracle(address(stakedBTC), address(mockOracle2), 30 minutes, bytes4(0x00000000), 18, false);

        mockOracle2.setResponse(2, 0, block.timestamp, block.timestamp, 2);

        vm.expectRevert(abi.encodeWithSelector(PriceFeed__InvalidFeedResponseError.selector, address(stakedBTC)));
        priceFeed.setOracle(address(stakedBTC), address(mockOracle2), 30 minutes, bytes4(0x00000000), 18, false);

        mockOracle2.setResponse(2, 60_000e8, 0, 0, 2);

        vm.expectRevert(abi.encodeWithSelector(PriceFeed__InvalidFeedResponseError.selector, address(stakedBTC)));
        priceFeed.setOracle(address(stakedBTC), address(mockOracle2), 30 minutes, bytes4(0x00000000), 18, false);

        mockOracle2.setResponse(2, 60_000e8, block.timestamp + 1, block.timestamp + 1, 2);

        vm.expectRevert(abi.encodeWithSelector(PriceFeed__InvalidFeedResponseError.selector, address(stakedBTC)));
        priceFeed.setOracle(address(stakedBTC), address(mockOracle2), 30 minutes, bytes4(0x00000000), 18, false);
    }

    function testFuzz_setOracle_frozenFeed(uint32 _heartbeat, uint16 _delta) external {
        vm.assume(_heartbeat <= 365 days);
        vm.assume(_delta > 0);

        vm.startPrank(users.owner);

        mockOracle2.setResponse(
            2,
            60_000e8,
            block.timestamp - _heartbeat - _delta,
            block.timestamp - _heartbeat - _delta,
            2
        );

        vm.expectRevert(abi.encodeWithSelector(PriceFeed__FeedFrozenError.selector, address(stakedBTC)));
        priceFeed.setOracle(address(stakedBTC), address(mockOracle2), _heartbeat, bytes4(0x00000000), 18, false);
    }

    function testFuzz_fetchPrice_unknownFeed(address _token) external {
        vm.assume(_token != address(stakedBTC) && _token != address(0));

        vm.expectRevert(abi.encodeWithSelector(PriceFeed__UnknownFeedError.selector, address(_token)));
        priceFeed.fetchPrice(_token);
    }

    function test_fetchPrice_cached() external {
        vm.startPrank(users.owner);

        mockOracle2.setResponse(2, 60_000e8, block.timestamp, block.timestamp, 2);

        priceFeed.setOracle(address(stakedBTC), address(mockOracle2), 30 minutes, bytes4(0x00000000), 18, false);

        skip(1 minutes);

        assertEq(priceFeed.fetchPrice(address(stakedBTC)), 60_000e18);
    }
}
