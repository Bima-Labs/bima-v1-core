/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const owner = hre.midl.wallet.getEVMAddress(); // 0xF5EEeCDd8b7790A6CA1021e019f96DBD9470F2f9
        console.log("Owner address:", owner);

        // Use the provider recommended by MIDL team
        const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        const deployerNonce = await provider.getTransactionCount(owner);
        console.log("Deployer nonce:", deployerNonce);

        // Predict BimaCore address (to be deployed in the next script)
        const bimaCoreAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 1,
        });
        console.log("Predicted BimaCore address:", bimaCoreAddress);

        // Deploy BimaWrappedCollateralFactory
        await hre.midl.deploy("BimaWrappedCollateralFactory", {
            args: [bimaCoreAddress],
        });

        console.log("Deploying BimaWrappedCollateralFactory...");
        await hre.midl.execute();

        console.log("_________________________________________________");
        const deployedAddress = await hre.midl.getDeployment("BimaWrappedCollateralFactory");
        console.log("BimaWrappedCollateralFactory Deployed Address:", deployedAddress.address);
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
