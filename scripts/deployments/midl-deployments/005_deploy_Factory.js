/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

async function main(hre) {
    try {
        await hre.midl.initialize();

        const [owner] = await ethers.getSigners();
        const deployerNonce = await ethers.provider.getTransactionCount(owner.address);

        // Retrieve deployed addresses
        const { deployments } = hre;
        const bimaCoreAddress = "0x8fdE16d9d1A87Dfb699a493Fa45451d63a3E722D";
        const sortedTrovesAddress = "0xf08C945ad422809D29F599f6F4839cf8003bC051";

        // Predict addresses for not-yet-deployed contracts
        const debtTokenAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce + 2, // DebtToken is in script 007
        });
        const borrowerOperationsAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce + 3, // BorrowerOperations is in script 008
        });
        const stabilityPoolAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce + 4, // StabilityPool is in script 009
        });
        const troveManagerAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce + 5, // TroveManager is in script 010
        });
        const liquidationManagerAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce + 1, // LiquidationManager is in script 006
        });

        // Deploy Factory
        await hre.midl.deploy("Factory", {
            args: [
                bimaCoreAddress,
                debtTokenAddress,
                stabilityPoolAddress,
                borrowerOperationsAddress,
                sortedTrovesAddress,
                troveManagerAddress,
                liquidationManagerAddress,
            ],
        });

        await hre.midl.execute();
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
