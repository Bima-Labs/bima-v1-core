/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const LOCK_TO_TOKEN_RATIO = hre.ethers.parseUnits("1", 18);
        const TOKEN_LOCKER_DEPLOYMENT_MANAGER = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";

        const owner = hre.midl.wallet.getEVMAddress();
        console.log("Owner address:", owner);

        // Use the provider recommended by MIDL team
        const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        const deployerNonce = await provider.getTransactionCount(owner);
        console.log("Deployer nonce:", deployerNonce);

        // Predict IncentiveVoting address (needed for TokenLocker constructor, to be deployed in 012_deploy_IncentiveVoting.js)
        const incentiveVotingAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 1, // IncentiveVoting will be deployed in 012
        });
        console.log("Predicted IncentiveVoting address:", incentiveVotingAddress);

        // Predict BimaToken address (needed for TokenLocker constructor, to be deployed in 013_deploy_BimaToken.js)
        const bimaTokenAddress = hre.ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 2, // BimaToken will be deployed in 013
        });
        console.log("Predicted BimaToken address:", bimaTokenAddress);

        // Fetch previously deployed contract addresses
        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");

        // Deploy TokenLocker
        await hre.midl.deploy("TokenLocker", {
            args: [
                bimaCoreAddress.address,
                bimaTokenAddress,
                incentiveVotingAddress,
                TOKEN_LOCKER_DEPLOYMENT_MANAGER,
                LOCK_TO_TOKEN_RATIO,
            ],
        });

        console.log("Deploying TokenLocker...");
        await hre.midl.execute();

        console.log("_________________________________________________");
        const deployedAddress = await hre.midl.getDeployment("TokenLocker");
        console.log("TokenLocker Deployed Address:", deployedAddress.address);
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
