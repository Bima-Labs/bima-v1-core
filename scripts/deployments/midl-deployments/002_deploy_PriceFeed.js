/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

async function main(hre) {
    try {
        await hre.midl.initialize();

        // Retrieve BimaCore address
        let bimaCoreAddress;
        try {
            const { deployments } = hre;
            bimaCoreAddress = (await deployments.get("BimaCore")).address;
        } catch (error) {
            console.error("Failed to retrieve BimaCore deployment artifact:", error.message);
            // Fallback to hardcoded address from logs (temporary workaround)
            bimaCoreAddress = "0x8fdE16d9d1A87Dfb699a493Fa45451d63a3E722D";
        }

        // Deploy PriceFeed
        await hre.midl.deploy("PriceFeed", {
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
