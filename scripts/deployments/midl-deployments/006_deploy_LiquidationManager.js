/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

const GAS_COMPENSATION = ethers.parseUnits("200", 18);

async function main(hre) {
    try {
        await hre.midl.initialize();

        const [owner] = await ethers.getSigners();
        const deployerNonce = await ethers.provider.getTransactionCount(owner.address);

        // Retrieve deployed addresses
        const { deployments } = hre;
        const factoryAddress = "0x16C05D5BbD83613Fb89c05fDc71975C965c978Fd";

        // Predict addresses for not-yet-deployed contracts
        const borrowerOperationsAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce + 2, // BorrowerOperations is in script 008
        });
        const stabilityPoolAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce + 3, // StabilityPool is in script 009
        });

        // Deploy LiquidationManager
        await hre.midl.deploy("LiquidationManager", {
            args: [stabilityPoolAddress, borrowerOperationsAddress, factoryAddress, GAS_COMPENSATION],
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
