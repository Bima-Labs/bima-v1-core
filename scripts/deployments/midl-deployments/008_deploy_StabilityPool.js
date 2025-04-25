/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

async function main(hre) {
    try {
        await hre.midl.initialize();

        const owner = hre.midl.wallet.getEVMAddress();
        const deployerNonce = await ethers.provider.getTransactionCount(owner);

        // Hardcode addresses
        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");
        const factoryAddress = await hre.midl.getDeployment("Factory");
        const liquidationManager = await hre.midl.getDeployment("LiquidationManager");

        // Predict addresses for not-yet-deployed contracts
        const debtTokenAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 1, // DebtToken is in script 009
        });
        const bimaVaultAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 6, // BimaVault is in script 014
        });

        console.log("All addresses:", {
            bimaCoreAddress: bimaCoreAddress.address,
            factoryAddress: factoryAddress.address,
            liquidationManager: liquidationManager.address,
            debtTokenAddress: debtTokenAddress,
            bimaVaultAddress: bimaVaultAddress,
        });
        // Deploy StabilityPool
        await hre.midl.deploy("StabilityPool", {
            args: [
                bimaCoreAddress.address,
                debtTokenAddress,
                bimaVaultAddress,
                factoryAddress.address,
                liquidationManager.address,
            ],
        });

        // await hre.midl.execute();
        // const stabilityPoolAddress = await hre.midl.getDeployment("StabilityPool");
        // console.log("StabilityPool Deployed Address:", stabilityPoolAddress.address);
    } catch (error) {
        console.error("Error initializing MIDL:", error);
        return;
    }
}

main(hre)
    .then(() => {})
    .catch((error) => {
        console.error("Error executing deployment script:", error);
    })
    .finally(() => {
        process.exit(0);
    });
