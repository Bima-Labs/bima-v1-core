/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */

async function main(hre) {
    try {
        await hre.midl.initialize();

        const owner = hre.midl.wallet.getEVMAddress(); //0xF5EEeCDd8b7790A6CA1021e019f96DBD9470F2f9

        console.log("Owner address:", owner);
        const deployerNonce = await ethers.provider.getTransactionCount(owner);

        // Predict BimaCore address (deployed in next script)
        const bimaCoreAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 1,
        });

        // Deploy BimaWrappedCollateralFactory
        await hre.midl.deploy("BimaWrappedCollateralFactory", {
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
