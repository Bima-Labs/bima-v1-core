/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const GAS_COMPENSATION = hre.ethers.parseUnits("200", 18);
        const MIN_NET_DEBT = hre.ethers.parseUnits("10", 18);

        const owner = hre.midl.wallet.getEVMAddress();
        console.log("Owner address:", owner);

        // Use the provider recommended by MIDL team
        const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        const deployerNonce = await provider.getTransactionCount(owner);
        console.log("Deployer nonce:", deployerNonce);

        // Fetch previously deployed contract addresses
        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");
        const debtTokenAddress = await hre.midl.getDeployment("DebtToken");
        const factoryAddress = await hre.midl.getDeployment("Factory");

        // Deploy BorrowerOperations (no future addresses needed in args)
        await hre.midl.deploy("BorrowerOperations", {
            args: [
                bimaCoreAddress.address,
                debtTokenAddress.address,
                factoryAddress.address,
                MIN_NET_DEBT,
                GAS_COMPENSATION,
            ],
        });

        console.log("Deploying BorrowerOperations...");
        await hre.midl.execute();

        console.log("_________________________________________________");
        const deployedAddress = await hre.midl.getDeployment("BorrowerOperations");
        console.log("BorrowerOperations Deployed Address:", deployedAddress.address);
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
