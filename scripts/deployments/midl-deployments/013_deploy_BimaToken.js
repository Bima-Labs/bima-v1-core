/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const owner = hre.midl.wallet.getEVMAddress();
        console.log("Owner address:", owner);

        // Use the provider recommended by MIDL team
        const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        const deployerNonce = await provider.getTransactionCount(owner);
        console.log("Deployer nonce:", deployerNonce);

        // Predict BimaVault address (needed for BimaToken constructor, to be deployed in 014_deploy_BimaVault.js)
        const bimaVaultAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 1, // BimaVault will be deployed in 014
        });
        console.log("Predicted BimaVault address:", bimaVaultAddress);

        // Fetch previously deployed contract addresses
        const tokenLockerAddress = await hre.midl.getDeployment("TokenLocker");

        // Deploy BimaToken (updated constructor without lzEndpoint and lzDelegate)
        await hre.midl.deploy("BimaToken", {
            args: [bimaVaultAddress, tokenLockerAddress.address],
        });

        console.log("Deploying BimaToken...");
        await hre.midl.execute();

        console.log("_________________________________________________");
        const deployedAddress = await hre.midl.getDeployment("BimaToken");
        console.log("BimaToken Deployed Address:", deployedAddress.address);
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
