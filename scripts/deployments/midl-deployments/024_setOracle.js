/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const priceFeedAddress = "0x3ebC5c1dF3EE95f92dF86094c32F293F15998016";
        const collateralAddress = "0x99c2231DdaF2e65Ef49fCef333DbD05782eCd8Aa";
        const oracleAddress = "0x97d40286D7C450a13F86c2cf13e7651911239901";
        const ORACLE_HEARBEAT = BigInt("315576000");
        const SHARE_PRICE_SIGNATURE = "0x00000000";
        const SHARE_PRICE_DECIMALS = BigInt("18");
        const IS_BASE_CURRENCY_ETH_INDEXED = false;

        // Verify the deployer address (optional, for debugging)
        const deployerAddress = hre.midl.wallet.getEVMAddress();
        console.log("Deployer address:", deployerAddress);

        console.log("Setting Oracle on PriceFeed contract...");
        await hre.midl.callContract("PriceFeed", "setOracle", {
            address: priceFeedAddress,
            args: [
                collateralAddress,
                oracleAddress,
                ORACLE_HEARBEAT,
                SHARE_PRICE_SIGNATURE,
                SHARE_PRICE_DECIMALS,
                IS_BASE_CURRENCY_ETH_INDEXED,
            ],
            gas: BigInt(1000000),
        });
        console.log("setOracle call queued");

        console.log("Executing transaction...");
        await hre.midl.execute();
        console.log("setOracle called successfully");
    } catch (error) {
        console.error("Error setting oracle:", error);
        throw error;
    }
}

// Export the function for Hardhat to use
module.exports = main;
module.exports.tags = ["main", "SetOracle"];

// Execute the script if run directly
if (require.main === module) {
    const hre = require("hardhat");
    main(hre)
        .then(() => {
            console.log("Script completed successfully.");
        })
        .catch((error) => {
            console.error("Error executing script:", error);
        })
        .finally(() => {
            process.exit(0);
        });
}
