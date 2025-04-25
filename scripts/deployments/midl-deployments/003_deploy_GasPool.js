/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

async function main(hre) {
    try {
        await hre.midl.initialize();

        // Deploy GasPool
        await hre.midl.deploy("GasPool", {
            args: [],
        });

        await hre.midl.execute();
        const gasPoolAddress = await hre.midl.getDeployment("GasPool");
        console.log("GasPool Deployed Address:", gasPoolAddress.address);
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
