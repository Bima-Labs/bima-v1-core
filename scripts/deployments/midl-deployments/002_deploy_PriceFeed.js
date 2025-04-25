/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

async function main(hre) {
    try {
        await hre.midl.initialize();

        // Retrieve BimaCore address
        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");

        console.log("BimaCore Deployed Address:", bimaCoreAddress.address);

        // Deploy PriceFeed
        await hre.midl.deploy("PriceFeed", {
            args: [bimaCoreAddress.address],
        });

        await hre.midl.execute();

        const priceFeedAddress = await hre.midl.getDeployment("PriceFeed");
        console.log("PriceFeed Deployed Address:", priceFeedAddress.address);
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
