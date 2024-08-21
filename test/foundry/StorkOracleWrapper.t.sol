// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {StorkOracleWrapper, IStorkOracle} from "../../contracts/core/StorkOracleWrapper.sol";
import {IAggregatorV3Interface} from "../../contracts/interfaces/IAggregatorV3Interface.sol";
import {PriceFeed} from "../../contracts/core/PriceFeed.sol";

contract TestSetup is Test {
  StorkOracleWrapper public storkOracleWrapper;
  IStorkOracle public storkOracle;
  bytes32 public encodedAssetId;

  string HOLESKY_RPC_URL = vm.envString("HOLESKY_RPC_URL");

  function setUp() public {
    vm.createSelectFork(HOLESKY_RPC_URL);

    storkOracle = IStorkOracle(0xacC0a0cF13571d30B4b8637996F5D6D774d4fd62);
    encodedAssetId = bytes32(0x7404e3d104ea7841c3d9e6fd20adfe99b4ad586bc08d8f3bd3afef894cf184de);

    storkOracleWrapper = new StorkOracleWrapper(address(storkOracle), encodedAssetId);
  }

  function testInitialState() public view {
    assertEq(address(storkOracleWrapper.storkOracle()), address(storkOracle));
    assertEq(storkOracleWrapper.encodedAssetId(), encodedAssetId);
    assertEq(storkOracleWrapper.decimals(), 8);
    assertEq(storkOracleWrapper.description(), "AggregatorV3Interface Wrapper for Stork Oracle");
    assertEq(storkOracleWrapper.version(), 1);
  }

  // function testOracle() public {
  //   IAggregatorV3Interface oracle = IAggregatorV3Interface(0x7363a69249710548c670Dac0505c9C8710c9Fb50);
  //   PriceFeed priceFeed = PriceFeed(0xaa7Feffe3a3edFd4e9D016e897A21693099F8b8d);

  //   console.log("OWNER: ", priceFeed.owner());

  //   vm.prank(0x5bfe5b93649eD957131594B9906BcFBb5Bb3B920);
  //   priceFeed.setOracle(
  //     0x2e2C128B256884cc2C10D88214FEC53a33a0db49,
  //     address(oracle),
  //     80000,
  //     bytes4(0x00000000),
  //     18,
  //     false
  //   );

  //   // (, int256 answer, , uint256 updatedAt, ) = oracle.latestRoundData();
  //   // console.log(answer);
  //   // console.log(updatedAt);

  //   // (uint64 timestampNs, int192 quantizedValue) = storkOracle.getTemporalNumericValueV1(encodedAssetId);

  //   // console.log("-");

  //   // console.log(quantizedValue);
  //   // console.log(timestampNs);
  // }

  function testLatestRoundData() public view {
    (uint64 timestampNs, int192 quantizedValue) = storkOracle.getTemporalNumericValueV1(encodedAssetId);

    (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, ) = storkOracleWrapper.latestRoundData();

    assertEq(roundId, timestampNs / 1e9 / 1 minutes);
    assertEq(answer, quantizedValue / 1e10);
    assertEq(startedAt, timestampNs / 1e9);
    assertEq(updatedAt, timestampNs / 1e9);
  }

  function testRoundsData(uint80 _roundId) public view {
    (uint64 timestampNs, int192 quantizedValue) = storkOracle.getTemporalNumericValueV1(encodedAssetId);

    (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, ) = storkOracleWrapper.getRoundData(_roundId);

    assertEq(roundId, _roundId);
    assertEq(answer, quantizedValue / 1e10);
    assertEq(startedAt, timestampNs / 1e9 - 1 minutes);
    assertEq(updatedAt, timestampNs / 1e9 - 1 minutes);
  }
}
