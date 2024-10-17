 // SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
import {StorkOracleWrapper} from "contracts/core/StorkOracleWrapper.sol";
import {Script,console} from "forge-std/Script.sol";

contract storkWrapper is Script {
    // Fill the address 
    address internal constant STORK_ORACLE= ;
    bytes32 internal constant ENCODED_ASSET_ID =0x7404e3d104ea7841c3d9e6fd20adfe99b4ad586bc08d8f3bd3afef894cf184de;
    function run() external {
        vm.startBroadcast();
        StorkOracleWrapper storkOracleWrapper = new StorkOracleWrapper(STORK_ORACLE,ENCODED_ASSET_ID);
        address storkOracleWrapperAddress = address(storkOracleWrapper);
        console.log("StorkOracleWrapper deployed!: ", storkOracleWrapperAddress);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = storkOracleWrapper.latestRoundData();
        console.log("roundId:",roundId);
        console.log("answer:",answer);
        console.log("startedAt:",startedAt);
        console.log("updatedAt:",updatedAt);
        console.log("answeredInRound:",answeredInRound);
        vm.stopBroadcast();
    }
}
