// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {StorkOracleWrapper, IStorkOracle} from "../../contracts/core/StorkOracleWrapper.sol";
import {IAggregatorV3Interface} from "../../contracts/interfaces/IAggregatorV3Interface.sol";
import {PriceFeed} from "../../contracts/core/PriceFeed.sol";
import {IBorrowerOperations} from "../../contracts/interfaces/IBorrowerOperations.sol";
import {ITroveManager} from "../../contracts/interfaces/ITroveManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

  function testFlow() public {
    address collateralAddress = 0xE20B0B5E240910Ca1461893542C6F226793aAD25;
    address troveManagerAddress = 0x1B2f879Ab2a3eB125a650cd53a6964052cf53613;
    address oracleAddress = 0xd296Ea42A6dBbd171025d6087AAe4dBFBfc7c70d;

    address borrowOperationsAddress = 0x98cb20D30da0389028EB71eF299B688979F5cB8b;
    address priceFeedAddress = 0xEdd95b1325140Eb6c06d8C738DE98accb2104dFB;

    (uint80 roundId1, int256 answer, , uint256 updatedAt, ) = IAggregatorV3Interface(oracleAddress).latestRoundData();
    // console.log("ROUND ID AND ANSWER AND UPDATED AT FROM ORACLE: ");
    // console.log(roundId1);
    console.log(answer);
    // console.log(updatedAt);

    console.log("FETCHING PRICE");

    PriceFeed(priceFeedAddress).fetchPrice(collateralAddress);

    console.log("PRICE FETCHED");

    console.log("APPROVING COLLATERAL");

    vm.prank(0x39d2770AbcC456f6C6be820705eD966592E0ad96); // This address holds the mock collateral token
    IERC20(collateralAddress).approve(borrowOperationsAddress, 1e18);

    console.log("OPENING TROVE");

    vm.prank(0x39d2770AbcC456f6C6be820705eD966592E0ad96);
    IBorrowerOperations(borrowOperationsAddress).openTrove(
      ITroveManager(troveManagerAddress),
      0x39d2770AbcC456f6C6be820705eD966592E0ad96,
      0.1e18,
      1e18,
      10_000e18,
      address(0),
      address(0)
    );

    console.log(IERC20(collateralAddress).balanceOf(0x39d2770AbcC456f6C6be820705eD966592E0ad96));
    console.log(ITroveManager(troveManagerAddress).debtToken().balanceOf(0x39d2770AbcC456f6C6be820705eD966592E0ad96));
  }
}
