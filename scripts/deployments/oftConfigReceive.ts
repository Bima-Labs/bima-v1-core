import { ethers } from "hardhat";

const abiCoder = ethers.AbiCoder.defaultAbiCoder();

//! HEMI

const LZ_ENDPOINT_ADDRESS = "0x6F475642a6e85809B1c36Fa62763669b1b48DD5B";
const OFT_ADDRESS = "0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c";
const RECEIVE_LIB_ADDRESS = "0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043";
const REMOTE_ID = 30153; // CoreDAO
const DVN_ADDRESSES = [
    "0x282b3386571f7f794450d5789911a9804fa346b4", // LZ Labs
    "0xdd7b5e1db4aafd5c8ec3b764efb8ed265aa5445b", // Stargate
]; // Replace with actual addresses, must be in alphabetical order

async function main() {
    const [owner] = await ethers.getSigners();

    const ulnConfig = {
        confirmations: 20, // Example value, replace with actual
        requiredDVNCount: 2, // Example value, replace with actual
        optionalDVNCount: 0, // Example value, replace with actual
        optionalDVNThreshold: 0, // Example value, replace with actual
        requiredDVNs: DVN_ADDRESSES, // Replace with actual addresses, must be in alphabetical order
        optionalDVNs: [], // Replace with actual addresses, must be in alphabetical order
    };

    // ABI and Contract
    const endpointAbi = [
        "function setConfig(address oappAddress, address receiveLibAddress, tuple(uint32 eid, uint32 configType, bytes config)[] setConfigParams) external",
    ];
    const endpointContract = new ethers.Contract(LZ_ENDPOINT_ADDRESS, endpointAbi, owner);

    // Encode UlnConfig using defaultAbiCoder
    const configTypeUlnStruct =
        "tuple(uint64 confirmations, uint8 requiredDVNCount, uint8 optionalDVNCount, uint8 optionalDVNThreshold, address[] requiredDVNs, address[] optionalDVNs)";
    const encodedUlnConfig = abiCoder.encode([configTypeUlnStruct], [ulnConfig]);

    // Define the SetConfigParam struct
    const setConfigParam = {
        eid: REMOTE_ID,
        configType: 2, // RECEIVE_CONFIG_TYPE
        config: encodedUlnConfig,
    };

    try {
        const tx = await endpointContract.setConfig(
            OFT_ADDRESS,
            RECEIVE_LIB_ADDRESS,
            [setConfigParam] // This should be an array of SetConfigParam structs
        );

        console.log("Transaction sent:", tx.hash);
        const receipt = await tx.wait();
        console.log("Transaction confirmed:", receipt.transactionHash);
    } catch (error) {
        console.error("Transaction failed:", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
