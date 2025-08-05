/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();
        const config = await hre.midl.getConfig();
        console.log("config", config);
        const owner = hre.midl.getEVMAddress(); // 0xF5EEeCDd8b7790A6CA1021e019f96DBD9470F2f9
        console.log("owner", owner);
        // console.log("Owner address:", owner);

        // // const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        // const provider = new hre.ethers.JsonRpcProvider("https://rpc.regtest.midl.xyz");
        // const deployerNonce = await provider.getTransactionCount(owner);
        // console.log("Deployer nonce:", deployerNonce);

        // Predict BimaCore address (to be deployed in the next script)
        // const bimaCoreAddress = hre.ethers.getCreateAddress({
        //     from: owner,
        //     nonce: deployerNonce + 1,
        // });
        // console.log("Predicted BimaCore address:", bimaCoreAddress);

        // // Deploy BimaWrappedCollateralFactory
        // await hre.midl.deploy("BimaWrappedCollateralFactory", {
        //     args: [bimaCoreAddress],
        // });

        // console.log("Deploying BimaWrappedCollateralFactory...");
        // await hre.midl.execute();

        // console.log("_________________________________________________");
        // const deployedAddress = await hre.midl.getDeployment("BimaWrappedCollateralFactory");
        // console.log("BimaWrappedCollateralFactory Deployed Address:", deployedAddress.address);
    } catch (error) {
        console.error("Error initializing MIDL:", error);
        throw error;
    }
}

main(hre);
