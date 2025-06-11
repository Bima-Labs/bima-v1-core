/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        // console.log zero address and mnemonic
        await hre.midl.initialize();
        const ZeroAddress = hre.ethers.ZeroAddress;
        console.log("Zero Address:", ZeroAddress);
        console.log("Mnemonic", hre.midl.wallet.mnemonic);
        console.log("Midl Owner EVM", hre.midl.wallet.getEVMAddress());
    } catch (e) {
        console.error("Error printing zero address:", e);
        throw e;
    }
}

// Export the function for Hardhat to use
module.exports = main;
module.exports.tags = ["main", "PrintZeroAddress"];

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
