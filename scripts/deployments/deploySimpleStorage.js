/**
 *
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    /**
     * Initializes MIDL hardhat deploy SDK
     */
    try {
        await hre.midl.initialize();

        /**
         * Add the deploy contract transaction intention
         */
        await hre.midl.deploy("SimpleStorage", {
            args: ["Hello from MIDL!"],
        });

        /**
         * Sends the BTC transaction and EVM transaction to the network
         */
        await hre.midl.execute();

        console.log("SimpleStorage deployed successfully!");
    } catch (error) {
        console.error("Error initializing MIDL:", error);
        return;
    }
}

main(hre)
    .then(() => {
        console.log("Deployment script executed successfully!");
    })
    .catch((error) => {
        console.error("Error executing deployment script:", error);
    })
    .finally(() => {
        process.exit(0);
    });
