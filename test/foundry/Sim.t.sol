// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract SimTest is Test {
    using OptionsBuilder for bytes;

    address[] public emptyAddresses; // already empty by default
    address[] public dvns;

    OFT public oft = OFT(0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c);

    string public RPC_URL = "https://rpc.hemi.network/rpc";

    function setUp() public {
        vm.createSelectFork(RPC_URL);
    }

    function test_simski() public {
        console.log("Testing bridging from Hemi to Core");

        address user = 0x3F3B0272cD337eb386F2596eD25351316A165809;

        vm.startPrank(user);

        deal(address(oft), user, 2e18, true);

        SendParam memory sendParam = SendParam(
            30153, // CoreDAO v2 ID
            bytes32(uint256(uint160(user))), // Recipient address
            2e18, // Amount to Send
            2e18, // Amount to Send
            OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0),
            "",
            ""
        );

        console.log("quoteSend..");

        MessagingFee memory fee = oft.quoteSend(sendParam, false);

        oft.send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));
    }
}
