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

        // Predict BimaVault address (needed for StabilityPool constructor, to be deployed in 014_deploy_BimaVault.js)
        const bimaVaultAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 5, // BimaVault will be deployed in 014
        });
        console.log("Predicted BimaVault address:", bimaVaultAddress);

        // Fetch previously deployed contract addresses
        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");
        const debtTokenAddress = await hre.midl.getDeployment("DebtToken");
        const factoryAddress = await hre.midl.getDeployment("Factory");
        const liquidationManagerAddress = await hre.midl.getDeployment("LiquidationManager");

        // Deploy StabilityPool
        await hre.midl.deploy("StabilityPool", {
            args: [
                bimaCoreAddress.address,
                debtTokenAddress.address,
                bimaVaultAddress,
                factoryAddress.address,
                liquidationManagerAddress.address,
            ],
        });

        console.log("Deploying StabilityPool...");
        await hre.midl.execute();

        console.log("_________________________________________________");
        const deployedAddress = await hre.midl.getDeployment("StabilityPool");
        console.log("StabilityPool Deployed Address:", deployedAddress.address);
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
