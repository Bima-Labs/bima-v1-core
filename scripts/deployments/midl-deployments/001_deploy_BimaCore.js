/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        // const BIMA_OWNER_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";
        // const BIMA_GUARDIAN_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";
        // const FEE_RECEIVER_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";

        const owner = hre.midl.wallet.getEVMAddress();
        console.log("Owner address:", owner);

        // Use the provider recommended by MIDL team
        const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        const deployerNonce = await provider.getTransactionCount(owner);
        console.log("Deployer nonce:", deployerNonce);

        // Predict PriceFeed address (to be deployed in the next script: 002_deploy_PriceFeed.js)
        const priceFeedAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 1, // PriceFeed will be deployed in 002
        });
        console.log("Predicted PriceFeed address:", priceFeedAddress);

        // Deploy BimaCore
        await hre.midl.deploy("BimaCore", {
            args: [owner, owner, priceFeedAddress, owner],
        });

        console.log("Deploying BimaCore...");
        await hre.midl.execute();

        console.log("_________________________________________________");
        const deployedAddress = await hre.midl.getDeployment("BimaCore");
        console.log("BimaCore Deployed Address:", deployedAddress.address);
    } catch (error) {
        console.error("Error initializing MIDL:", error);
        throw error;
    }
}

// Export the function for Hardhat to use
module.exports = main;

// Execute the script if run directly
if (require.main === module) {
    const hre = require("hardhat");
    main(hre)
        .then(() => {
            console.log("Script completed successfully.");
        })
        .catch((error) => {
            console.error("Error executing deployment script:", error);
        })
        .finally(() => {
            process.exit(0);
        });
}
