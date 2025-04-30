/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const owner = hre.midl.wallet.getEVMAddress();
        console.log("Owner address:", owner);

        // Use the provider recommended by MIDL team
        const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        const deployerNonce = await provider.getTransactionCount(owner);
        console.log("Deployer nonce:", deployerNonce);

        // Fetch previously deployed contract addresses
        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");
        const bimaTokenAddress = await hre.midl.getDeployment("BimaToken");
        const tokenLockerAddress = await hre.midl.getDeployment("TokenLocker");
        const incentiveVotingAddress = await hre.midl.getDeployment("IncentiveVoting");
        const stabilityPoolAddress = await hre.midl.getDeployment("StabilityPool");

        // Deploy BimaVault (no future addresses needed in args)
        await hre.midl.deploy("BimaVault", {
            args: [
                bimaCoreAddress.address,
                bimaTokenAddress.address,
                tokenLockerAddress.address,
                incentiveVotingAddress.address,
                stabilityPoolAddress.address,
                owner,
            ],
        });

        console.log("Deploying BimaVault...");
        await hre.midl.execute();

        console.log("_________________________________________________");
        const deployedAddress = await hre.midl.getDeployment("BimaVault");
        console.log("BimaVault Deployed Address:", deployedAddress.address);
    } catch (error) {
        console.error("Error initializing MIDL:", error);
        throw error;
    }
}

// Export the function for Hardhat to use
module.exports = main;

// Execute the script if run directly
if (require.main === module) {
    const hre = require("hardhat");
    main(hre)
        .then(() => {
            console.log("Script completed successfully.");
        })
        .catch((error) => {
            console.error("Error executing deployment script:", error);
        })
        .finally(() => {
            process.exit(0);
        });
}
