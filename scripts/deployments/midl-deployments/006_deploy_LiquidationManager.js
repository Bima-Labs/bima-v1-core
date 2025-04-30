/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const GAS_COMPENSATION = hre.ethers.parseUnits("200", 18);
        console.log("GAS_COMPENSATION:", GAS_COMPENSATION.toString());
        const owner = hre.midl.wallet.getEVMAddress();
        console.log("Owner address:", owner);

        // Use the provider recommended by MIDL team
        const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        const deployerNonce = await provider.getTransactionCount(owner);
        console.log("Deployer nonce:", deployerNonce);

        // Predict BorrowerOperations address (needed for LiquidationManager constructor, to be deployed in 008_deploy_BorrowerOperations.js)
        const borrowerOperationsAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 2, // BorrowerOperations will be deployed in 008
        });
        console.log("Predicted BorrowerOperations address:", borrowerOperationsAddress);

        // Predict StabilityPool address (needed for LiquidationManager constructor, to be deployed in 009_deploy_StabilityPool.js)
        const stabilityPoolAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 3, // StabilityPool will be deployed in 009
        });
        console.log("Predicted StabilityPool address:", stabilityPoolAddress);

        // Fetch previously deployed contract addresses
        const factoryAddress = await hre.midl.getDeployment("Factory");

        // Deploy LiquidationManager
        await hre.midl.deploy("LiquidationManager", {
            args: [stabilityPoolAddress, borrowerOperationsAddress, factoryAddress.address, GAS_COMPENSATION],
        });

        console.log("Deploying LiquidationManager...");
        await hre.midl.execute();

        console.log("_________________________________________________");
        const deployedAddress = await hre.midl.getDeployment("LiquidationManager");
        console.log("LiquidationManager Deployed Address:", deployedAddress.address);
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
