import { ethers } from "hardhat";

const abiCoder = ethers.AbiCoder.defaultAbiCoder();

//! HEMI

const LZ_ENDPOINT_ADDRESS = "0x6F475642a6e85809B1c36Fa62763669b1b48DD5B";
const OFT_ADDRESS = "0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c";
const SEND_LIB_ADDRESS = "0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7";
const SOURCE_ID = 30153; // Core
const DVN_ADDRESSES = [
    "0x282b3386571f7f794450d5789911a9804fa346b4", // LZ Labs
    "0xdd7b5e1db4aafd5c8ec3b764efb8ed265aa5445b", // Stargate
]; // Replace with actual addresses, must be in alphabetical order
const EXECUTOR_ADDRESS = "0x4208D6E27538189bB48E603D6123A94b8Abe0A0b";

async function main() {
    const [owner] = await ethers.getSigners();

    console.log("Setting up configurations..");

    // Configuration
    // UlnConfig controls verification threshold for incoming messages
    // Receive config enforces these settings have been applied to the DVNs and Executor
    // 0 values will be interpretted as defaults, so to apply NIL settings, use:
    // uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
    // uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
    const ulnConfig = {
        confirmations: 20, // Example value, replace with actual
        requiredDVNCount: 2, // Example value, replace with actual
        optionalDVNCount: 0, // Example value, replace with actual
        optionalDVNThreshold: 0, // Example value, replace with actual
        requiredDVNs: DVN_ADDRESSES, // Replace with actual addresses, must be in alphabetical order
        optionalDVNs: [], // Replace with actual addresses, must be in alphabetical order
    };

    const executorConfig = {
        maxMessageSize: 10000, // Example value, replace with actual
        executorAddress: EXECUTOR_ADDRESS, // Replace with the actual executor address
    };

    // ABI and Contract
    const endpointAbi = [
        "function setConfig(address oappAddress, address sendLibAddress, tuple(uint32 eid, uint32 configType, bytes config)[] setConfigParams) external",
    ];
    const endpointContract = new ethers.Contract(LZ_ENDPOINT_ADDRESS, endpointAbi, owner);

    // Encode UlnConfig using defaultAbiCoder
    const configTypeUlnStruct =
        "tuple(uint64 confirmations, uint8 requiredDVNCount, uint8 optionalDVNCount, uint8 optionalDVNThreshold, address[] requiredDVNs, address[] optionalDVNs)";
    const encodedUlnConfig = abiCoder.encode([configTypeUlnStruct], [ulnConfig]);

    // Encode ExecutorConfig using defaultAbiCoder
    const configTypeExecutorStruct = "tuple(uint32 maxMessageSize, address executorAddress)";
    const encodedExecutorConfig = abiCoder.encode([configTypeExecutorStruct], [executorConfig]);

    // Define the SetConfigParam structs
    const setConfigParamUln = {
        eid: SOURCE_ID,
        configType: 2, // ULN_CONFIG_TYPE
        config: encodedUlnConfig,
    };

    const setConfigParamExecutor = {
        eid: SOURCE_ID,
        configType: 1, // EXECUTOR_CONFIG_TYPE
        config: encodedExecutorConfig,
    };

    console.log("Sending Transaction..");
    const tx = await endpointContract.setConfig(
        OFT_ADDRESS,
        SEND_LIB_ADDRESS,
        [setConfigParamUln, setConfigParamExecutor] // Array of SetConfigParam structs
    );

    console.log("Transaction sent:", tx.hash);
    const receipt = await tx.wait();
    console.log("Transaction confirmed:", receipt.transactionHash);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
