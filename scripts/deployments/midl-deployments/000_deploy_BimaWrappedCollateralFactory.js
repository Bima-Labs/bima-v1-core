/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

async function main(hre) {
    try {
        await hre.midl.initialize();

        const [owner] = await ethers.getSigners();
        const deployerNonce = await ethers.provider.getTransactionCount(owner.address);

        // Predict BimaCore address (deployed in next script)
        const bimaCoreAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce + 1,
        });

        // Deploy BimaWrappedCollateralFactory
        await hre.midl.deploy("BimaWrappedCollateralFactory", {
            args: [bimaCoreAddress],
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
