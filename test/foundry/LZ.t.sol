//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
//import {ILayerZeroEndpointV2, SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {DebtToken} from "../../contracts/core/DebtToken.sol";

contract layerZeroSetUp is Test {
    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;
    address[] dvns = new address[](0);
    address signer = 0xE3FBba95BB35bE804696624dd1e9344a86E3cbC4;

    string public RPC_URL = "https://rpc.hemi.network/rpc";

    function setUp() external {
        vm.createSelectFork(RPC_URL);
    }

    function test_lz_simsski() public {
        // hemi mainnet 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B
        address LZ_ENDPOINT_ADDRESS = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
        address OFT_ADDRESS = 0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c;
        address SEND_LIB_ADDRESS = 0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7;

        uint32 SOURCE_ID = 30153;

        address DVN_1 = 0x282b3386571f7f794450d5789911a9804FA346b4;
        address DVN_2 = 0xDd7B5E1dB4AaFd5C8EC3b764eFB8ed265Aa5445B;
        address EXECUTOR_ADDRESS = 0x4208D6E27538189bB48E603D6123A94b8Abe0A0b;

        dvns.push(DVN_1);
        dvns.push(DVN_2);

        /// @notice ULNConfig defines security parameters (DVNs + confirmation threshold)
        /// @notice Send config requests these settings to be applied to the DVNs and Executor
        /// @dev 0 values will be interpretted as defaults, so to apply NIL settings, use:
        /// @dev uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
        /// @dev uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
        UlnConfig memory uln = UlnConfig({
            confirmations: 15, // minimum block confirmations required
            requiredDVNCount: 2, // number of DVNs required
            optionalDVNCount: type(uint8).max, // optional DVNs count, uint8
            optionalDVNThreshold: 0, // optional DVN threshold
            requiredDVNs: dvns, // sorted list of required DVN addresses
            optionalDVNs: new address[](0) // sorted list of optional DVNs
        });

        /// @notice ExecutorConfig sets message size limit + fee‑paying executor
        ExecutorConfig memory exec = ExecutorConfig({
            maxMessageSize: 10000, // max bytes per cross-chain message
            executor: EXECUTOR_ADDRESS // address that pays destination execution fees
        });

        bytes memory encodedUln = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);

        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam(SOURCE_ID, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[1] = SetConfigParam(SOURCE_ID, ULN_CONFIG_TYPE, encodedUln);

        vm.startPrank(signer);
        // DebtToken(0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c).setDelegate(signer);
        ILayerZeroEndpointV2(LZ_ENDPOINT_ADDRESS).setConfig(OFT_ADDRESS, SEND_LIB_ADDRESS, params);

        vm.stopPrank();
    }
}
