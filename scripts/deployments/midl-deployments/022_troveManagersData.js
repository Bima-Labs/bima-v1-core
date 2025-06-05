/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const borrowerOperationsAddress = "0x20bdde9470B52729E910EFa9f2f7c2B6a5682a53";
        const troveManagerAddress = "0x8916c27c451420E352CcaDF12DB0CA06aC08a31c";

        console.log(`Reading troveManagersData for TroveManager ${troveManagerAddress}...`);
        const result = await hre.midl.callContract("BorrowerOperations", "troveManagersData", {
            args: [troveManagerAddress],
            to: borrowerOperationsAddress,
            view: true,
        });
        console.log("troveManagersData:", result);
    } catch (error) {
        console.error("Error reading troveManagersData:", error);
        throw error;
    }
}

// Export the function for Hardhat to use
module.exports = main;
module.exports.tags = ["main", "ReadTroveManagersData"];

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
