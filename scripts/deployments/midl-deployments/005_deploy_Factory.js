/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

async function main(hre) {
    try {
        await hre.midl.initialize();

        const owner = hre.midl.wallet.getEVMAddress();
        const deployerNonce = await ethers.provider.getTransactionCount(owner);

        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");
        const sortedTrovesAddress = await hre.midl.getDeployment("SortedTroves");
        // Predict addresses for not-yet-deployed contracts
        const debtTokenAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 4, // DebtToken is in script 009
        });
        const borrowerOperationsAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 2, // BorrowerOperations is in script 007
        });
        const stabilityPoolAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 3, // StabilityPool is in script 008
        });
        const troveManagerAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 5, // TroveManager is in script 010
        });
        const liquidationManagerAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 1, // LiquidationManager is in script 006
        });

        // Deploy Factory
        await hre.midl.deploy("Factory", {
            args: [
                bimaCoreAddress.address,
                debtTokenAddress,
                stabilityPoolAddress,
                borrowerOperationsAddress,
                sortedTrovesAddress.address,
                troveManagerAddress,
                liquidationManagerAddress,
            ],
        });

        await hre.midl.execute();

        const factoryAddress = await hre.midl.getDeployment("Factory");
        console.log("Factory Deployed Address:", factoryAddress.address);
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
