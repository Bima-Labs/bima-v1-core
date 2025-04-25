/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

const GAS_COMPENSATION = ethers.parseUnits("200", 18);

async function main(hre) {
    try {
        await hre.midl.initialize();

        const owner = hre.midl.wallet.getEVMAddress();
        const deployerNonce = await ethers.provider.getTransactionCount(owner);

        const factoryAddress = await hre.midl.getDeployment("Factory");

        // Predict addresses for not-yet-deployed contracts
        const borrowerOperationsAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 1, // BorrowerOperations is in script 007
        });
        const stabilityPoolAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 2, // StabilityPool is in script 008
        });

        // Deploy LiquidationManager
        await hre.midl.deploy("LiquidationManager", {
            args: [stabilityPoolAddress, borrowerOperationsAddress, factoryAddress.address, GAS_COMPENSATION],
        });

        await hre.midl.execute();
        const liquidationManagerAddress = await hre.midl.getDeployment("LiquidationManager");
        console.log("LiquidationManager Deployed Address:", liquidationManagerAddress.address);
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
