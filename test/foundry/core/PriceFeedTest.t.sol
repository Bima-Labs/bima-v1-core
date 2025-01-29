// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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
        priceFeed.setOracle(address(stakedBTC), address(mockOracle2), 80_000, bytes4(0x00000000), 18, false);

        mockOracle2.setResponse(2, 0, block.timestamp, block.timestamp, 2);

        vm.expectRevert(abi.encodeWithSelector(PriceFeed__InvalidFeedResponseError.selector, address(stakedBTC)));
        priceFeed.setOracle(address(stakedBTC), address(mockOracle2), 80_000, bytes4(0x00000000), 18, false);

        mockOracle2.setResponse(2, 60_000e8, 0, 0, 2);

        vm.expectRevert(abi.encodeWithSelector(PriceFeed__InvalidFeedResponseError.selector, address(stakedBTC)));
        priceFeed.setOracle(address(stakedBTC), address(mockOracle2), 80_000, bytes4(0x00000000), 18, false);

        mockOracle2.setResponse(2, 60_000e8, block.timestamp + 1, block.timestamp + 1, 2);

        vm.expectRevert(abi.encodeWithSelector(PriceFeed__InvalidFeedResponseError.selector, address(stakedBTC)));
        priceFeed.setOracle(address(stakedBTC), address(mockOracle2), 80_000, bytes4(0x00000000), 18, false);
    }

    function testFuzz_setOracle_frozenFeed(uint32 _heartbeat, uint16 _delta) external {
        vm.assume(_heartbeat <= 86400);
        vm.assume(_delta > 0);

        vm.startPrank(users.owner);

        mockOracle2.setResponse(
            2,
            60_000e8,
            block.timestamp - _heartbeat - priceFeed.RESPONSE_TIMEOUT_BUFFER() - _delta,
            block.timestamp - _heartbeat - priceFeed.RESPONSE_TIMEOUT_BUFFER() - _delta,
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

        priceFeed.setOracle(address(stakedBTC), address(mockOracle2), 80_000, bytes4(0x00000000), 18, false);

        skip(1 minutes);

        assertEq(priceFeed.fetchPrice(address(stakedBTC)), 60_000e18);
    }

    
    // test_StalePriceUsedDueToReducedBuffer

   function test_StalePriceUsedDueToReducedBuffer() external {
    vm.startPrank(users.owner);

    console2.log("\n=== Initial Setup ===");
    uint256 initialTimestamp = block.timestamp;
    console2.log("Current block timestamp:", initialTimestamp);

    // First set previous round data (round 1)
    mockOracle2.setResponse(
        1, // roundId
        2000e8, // $2000 price
        block.timestamp - 2 minutes, // startedAt
        block.timestamp - 2 minutes, // updatedAt
        1 // answeredInRound
    );

    // Set current round data (round 2) - this price will be stored
    mockOracle2.setResponse(
        2, // roundId
        2000e8, // $2000 price
        block.timestamp, // startedAt
        block.timestamp, // updatedAt
        2 // answeredInRound
    );

    // Set oracle with 30-minute heartbeat
    priceFeed.setOracle(
        address(stakedBTC),
        address(mockOracle2),
        30 minutes, // heartbeat
        bytes4(0), // no share price signature
        18, // decimals
        false // not ETH indexed
    );

    uint256 initialPrice = priceFeed.fetchPrice(address(stakedBTC));
    assertEq(initialPrice, 2000e18, "Initial price should be $2000");
    console2.log("Initial price:", initialPrice / 1e18);

    // Advance time by 40 minutes (> heartbeat but < heartbeat + reduced buffer)
    vm.warp(block.timestamp + 40 minutes);
    console2.log("\nTime advanced by 40 minutes");
    console2.log("New timestamp:", block.timestamp);
    console2.log("Time elapsed:", (block.timestamp - initialTimestamp) / 60, "minutes");

    // Keep the oracle returning the same timestamp for round 2
    mockOracle2.setResponse(
        2, // Same roundId
        2000e8, // Same price
        block.timestamp - 40 minutes, // Old timestamp
        block.timestamp - 40 minutes, // Old timestamp
        2 // Same answeredInRound
    );

    // Get price - should still be valid (40 min < 45 min total threshold)
    uint256 validPrice = priceFeed.fetchPrice(address(stakedBTC));
    assertEq(validPrice, 2000e18, "Price should still be valid within reduced buffer time");
    console2.log("\nPrice still valid within reduced buffer:", validPrice / 1e18);
    console2.log("Price age:", 40, "minutes (> 30min heartbeat but < 45min total timeout)");

    // Now advance past 45 minutes (30 min heartbeat + 15 min buffer)
    vm.warp(block.timestamp + 6 minutes);
    console2.log("\nTime advanced by additional 6 minutes");
    console2.log("Total time elapsed:", (block.timestamp - initialTimestamp) / 60, "minutes");

    // Should revert due to truly stale price (past 45 min threshold)
    vm.expectRevert(abi.encodeWithSelector(PriceFeed__FeedFrozenError.selector, address(stakedBTC)));
    priceFeed.fetchPrice(address(stakedBTC));
    console2.log("Price finally considered stale and fetchPrice() reverted");

    vm.stopPrank();
}

}
