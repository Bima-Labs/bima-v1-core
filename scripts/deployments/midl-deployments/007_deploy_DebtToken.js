/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const DEBT_TOKEN_NAME = "US Bitcoin Dollar";
        const DEBT_TOKEN_SYMBOL = "USBD";
        const GAS_COMPENSATION = hre.ethers.parseUnits("200", 18);
        console.log("Gas compensation:", GAS_COMPENSATION.toString());
        console.log("DebtToken name:", DEBT_TOKEN_NAME);
        console.log("DebtToken symbol:", DEBT_TOKEN_SYMBOL);
        const owner = hre.midl.wallet.getEVMAddress();
        console.log("Owner address:", owner);

        // Use the provider recommended by MIDL team
        const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        const deployerNonce = await provider.getTransactionCount(owner);
        console.log("Deployer nonce:", deployerNonce);

        // Predict BorrowerOperations address (needed for DebtToken constructor, to be deployed in 008_deploy_BorrowerOperations.js)
        const borrowerOperationsAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 1, // BorrowerOperations will be deployed in 008
        });
        console.log("Predicted BorrowerOperations address:", borrowerOperationsAddress);

        // Predict StabilityPool address (needed for DebtToken constructor, to be deployed in 009_deploy_StabilityPool.js)
        const stabilityPoolAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 2, // StabilityPool will be deployed in 009
        });
        console.log("Predicted StabilityPool address:", stabilityPoolAddress);

        // Fetch previously deployed contract addresses
        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");
        const factoryAddress = await hre.midl.getDeployment("Factory");
        const gasPoolAddress = await hre.midl.getDeployment("GasPool");

        // Deploy DebtToken (updated constructor without lzEndpoint and lzDelegate)
        await hre.midl.deploy("DebtToken", {
            args: [
                DEBT_TOKEN_NAME,
                DEBT_TOKEN_SYMBOL,
                stabilityPoolAddress,
                borrowerOperationsAddress,
                bimaCoreAddress.address,
                factoryAddress.address,
                gasPoolAddress.address,
                GAS_COMPENSATION,
            ],
        });

        console.log("Deploying DebtToken...");
        await hre.midl.execute();

        console.log("_________________________________________________");
        const deployedAddress = await hre.midl.getDeployment("DebtToken");
        console.log("DebtToken Deployed Address:", deployedAddress.address);
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
