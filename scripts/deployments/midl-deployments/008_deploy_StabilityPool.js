/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

async function main(hre) {
    try {
        await hre.midl.initialize();

        const [owner] = await ethers.getSigners();
        const deployerNonce = await ethers.provider.getTransactionCount(owner.address);

        // Hardcode addresses
        const bimaCoreAddress = "0x8fdE16d9d1A87Dfb699a493Fa45451d63a3E722D";
        const factoryAddress = "0x16C05D5BbD83613Fb89c05fDc71975C965c978Fd";
        const liquidationManagerAddress = "0xD5Ab94196584defAa17eb417b26F98c525a48223";

        // Predict addresses for not-yet-deployed contracts
        const debtTokenAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce + 1, // DebtToken is in script 009
        });
        const bimaVaultAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce + 6, // BimaVault is in script 014
        });

        // Deploy StabilityPool
        await hre.midl.deploy("StabilityPool", {
            args: [bimaCoreAddress, debtTokenAddress, bimaVaultAddress, factoryAddress, liquidationManagerAddress],
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
