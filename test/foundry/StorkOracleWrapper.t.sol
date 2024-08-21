// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {StorkOracleWrapper, IStorkOracle} from "../../contracts/core/StorkOracleWrapper.sol";
import {IAggregatorV3Interface} from "../../contracts/interfaces/IAggregatorV3Interface.sol";
import {PriceFeed} from "../../contracts/core/PriceFeed.sol";
import {IBorrowerOperations} from "../../contracts/interfaces/IBorrowerOperations.sol";
import {ITroveManager} from "../../contracts/interfaces/ITroveManager.sol";

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

  //! FAILS
  function testFlow() public {
    // NEW COLLATERAL, TROVE MANAGER, AND ORACLE WRAPPER ADDRESSES
    address collateralAddress = 0x0206E1f1c74bf0E375f2d8418067CBE996B184ec;
    address troveManagerAddress = 0xCe5873Cca64EcEd738961405832521E959454f97;
    address oracleAddress = 0xc0565F0711B23008831AD9eA47DecaAdfE61dBaD;

    // CORE CONTRACT ADDRESSES ON HOLESKY CHAIN
    address borrowOperationsAddress = 0xa4de6030cd34aD3b6ce951d1b714e6E832b41910;
    address priceFeedAddress = 0xaa7Feffe3a3edFd4e9D016e897A21693099F8b8d;

    // ORACLE WRAPPER WORKS AS EXPECTED
    (uint80 roundId1, int256 answer, , uint256 updatedAt, ) = IAggregatorV3Interface(oracleAddress).latestRoundData();
    console.log("ROUND ID AND ANSWER AND UPDATED AT FROM ORACLE: ");
    console.log(roundId1);
    console.log(answer);
    console.log(updatedAt);

    // THE PRICE FEED CORRECTLY FETCHES PRICES FROM THE NEWLY DEPLOYED WRAPPER ORACLE WHICH IS LINKED TO THAT COLLATERAL TOKEN
    PriceFeed(priceFeedAddress).fetchPrice(collateralAddress);

    // When observed with -vvvv, this function calls `fetchPrice` on PriceFeed for the incorrect collateral token,
    // and that incorrect collateral token is the address of a token which was the first collateral token ever that I opened TroveManager
    // for on this chain. But you can see that when calling this funciton, the new troveManagerAddress is passed as an argument.
    // So, the PriceFeed contract should fetch the price from the new oracleWrapper contract linked to the new collateral token.
    // But it doesn't. It fetches the price for the old collateral token.
    vm.prank(0x5bfe5b93649eD957131594B9906BcFBb5Bb3B920); // This address holds the mock collateral token
    IBorrowerOperations(borrowOperationsAddress).openTrove(
      ITroveManager(troveManagerAddress),
      address(this),
      0.1e18,
      1e18,
      20_000e18,
      address(0),
      address(0)
    );
  }
}
