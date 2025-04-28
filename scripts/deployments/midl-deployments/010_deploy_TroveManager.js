/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const GAS_COMPENSATION = hre.ethers.parseUnits("200", 18);

        const owner = hre.midl.wallet.getEVMAddress();
        console.log("Owner address:", owner);

        // Use the provider recommended by MIDL team
        const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        const deployerNonce = await provider.getTransactionCount(owner);
        console.log("Deployer nonce:", deployerNonce);

        // Predict BimaVault address (needed for TroveManager constructor, to be deployed in 014_deploy_BimaVault.js)
        const bimaVaultAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 4, // BimaVault will be deployed in 014
        });
        console.log("Predicted BimaVault address:", bimaVaultAddress);

        // Fetch previously deployed contract addresses
        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");
        const gasPoolAddress = await hre.midl.getDeployment("GasPool");
        const debtTokenAddress = await hre.midl.getDeployment("DebtToken");
        const borrowerOperationsAddress = await hre.midl.getDeployment("BorrowerOperations");
        const liquidationManagerAddress = await hre.midl.getDeployment("LiquidationManager");

        // Deploy TroveManager
        await hre.midl.deploy("TroveManager", {
            args: [
                bimaCoreAddress.address,
                gasPoolAddress.address,
                debtTokenAddress.address,
                borrowerOperationsAddress.address,
                bimaVaultAddress,
                liquidationManagerAddress.address,
                GAS_COMPENSATION,
            ],
        });

        console.log("Deploying TroveManager...");
        await hre.midl.execute();

        console.log("_________________________________________________");
        const deployedAddress = await hre.midl.getDeployment("TroveManager");
        console.log("TroveManager Deployed Address:", deployedAddress.address);
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
