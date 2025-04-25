/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

const GAS_COMPENSATION = ethers.parseUnits("200", 18);
const MIN_NET_DEBT = ethers.parseUnits("10", 18); //! 10 USDB
async function main(hre) {
    try {
        await hre.midl.initialize();

        const owner = hre.midl.wallet.getEVMAddress();
        const deployerNonce = await ethers.provider.getTransactionCount(owner);
        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");
        const factoryAddress = await hre.midl.getDeployment("Factory");

        const debtTokenAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 2, // DebtToken is in script 009
        });

        // Deploy BorrowerOperations
        await hre.midl.deploy("BorrowerOperations", {
            args: [bimaCoreAddress.address, debtTokenAddress, factoryAddress.address, MIN_NET_DEBT, GAS_COMPENSATION],
        });

        await hre.midl.execute();
        const borrowerOperationsAddress = await hre.midl.getDeployment("BorrowerOperations");
        console.log("BorrowerOperations Deployed Address:", borrowerOperationsAddress.address);
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
