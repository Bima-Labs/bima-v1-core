// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {StorkOracleWrapper, IStorkOracle} from "../../contracts/core/StorkOracleWrapper.sol";

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

  function testLatestRoundData() public view {
    (uint64 timestampNs, int192 quantizedValue) = storkOracle.getTemporalNumericValueV1(encodedAssetId);

    (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, ) = storkOracleWrapper.latestRoundData();

    assertEq(roundId, 1);
    assertEq(answer, quantizedValue / 1e10);
    assertEq(startedAt, timestampNs / 1e9);
    assertEq(updatedAt, timestampNs / 1e9);
  }

  function testRoundsData(uint80 _roundId) public view {
    (uint64 timestampNs, int192 quantizedValue) = storkOracle.getTemporalNumericValueV1(encodedAssetId);

    (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, ) = storkOracleWrapper.getRoundData(_roundId);

    assertEq(roundId, _roundId);
    assertEq(answer, quantizedValue / 1e10);
    assertEq(startedAt, timestampNs / 1e9);
    assertEq(updatedAt, timestampNs / 1e9);
  }
}
