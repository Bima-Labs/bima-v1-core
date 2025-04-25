/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

async function main(hre) {
    try {
        await hre.midl.initialize();

        // Deploy SortedTroves
        await hre.midl.deploy("SortedTroves", {
            args: [],
        });

        await hre.midl.execute();

        const sortedTrovesAddress = await hre.midl.getDeployment("SortedTroves");
        console.log("SortedTroves Deployed Address:", sortedTrovesAddress.address);
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
