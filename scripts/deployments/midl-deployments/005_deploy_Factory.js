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

        // Predict LiquidationManager address (needed for Factory constructor, to be deployed in 006_deploy_LiquidationManager.js)
        const liquidationManagerAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 1, // LiquidationManager will be deployed in 006
        });
        console.log("Predicted LiquidationManager address:", liquidationManagerAddress);

        // Predict DebtToken address (needed for Factory constructor, to be deployed in 007_deploy_DebtToken.js)
        const debtTokenAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 2, // DebtToken will be deployed in 007
        });
        console.log("Predicted DebtToken address:", debtTokenAddress);

        // Predict BorrowerOperations address (needed for Factory constructor, to be deployed in 008_deploy_BorrowerOperations.js)
        const borrowerOperationsAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 3, // BorrowerOperations will be deployed in 008
        });
        console.log("Predicted BorrowerOperations address:", borrowerOperationsAddress);

        // Predict StabilityPool address (needed for Factory constructor, to be deployed in 009_deploy_StabilityPool.js)
        const stabilityPoolAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 4, // StabilityPool will be deployed in 009
        });
        console.log("Predicted StabilityPool address:", stabilityPoolAddress);

        // Predict TroveManager address (needed for Factory constructor, to be deployed in 010_deploy_TroveManager.js)
        const troveManagerAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 5, // TroveManager will be deployed in 010
        });
        console.log("Predicted TroveManager address:", troveManagerAddress);

        // Fetch previously deployed contract addresses
        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");
        const sortedTrovesAddress = await hre.midl.getDeployment("SortedTroves");

        // Deploy Factory
        await hre.midl.deploy("Factory", {
            args: [
                bimaCoreAddress.address,
                debtTokenAddress,
                stabilityPoolAddress,
                borrowerOperationsAddress,
                sortedTrovesAddress.address,
                troveManagerAddress,
                liquidationManagerAddress,
            ],
        });

        console.log("Deploying Factory...");
        await hre.midl.execute();

        console.log("_________________________________________________");
        const deployedAddress = await hre.midl.getDeployment("Factory");
        console.log("Factory Deployed Address:", deployedAddress.address);
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
