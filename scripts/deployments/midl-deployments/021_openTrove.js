/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const borrowerOperationsAddress = "0x20bdde9470B52729E910EFa9f2f7c2B6a5682a53";
        const bmBTCAddress = "0x99c2231DdaF2e65Ef49fCef333DbD05782eCd8Aa";
        const troveManagerAddress = "0x8916c27c451420E352CcaDF12DB0CA06aC08a31c";
        const borrowerAddress = "0xF5EEeCDd8b7790A6CA1021e019f96DBD9470F2f9";

        const amountInWei = BigInt(Math.floor(2 * 1e18));
        const percentage = 200; // Collateral ratio (200%)
        const lstPrice = 60000; // Price ($60,000, matches 1 bmBTC = 60,000 USBD)
        const normalizedPrice = Number(lstPrice);
        const percentageAmount =
            BigInt(Number(amountInWei) * normalizedPrice * 100) / BigInt(percentage) - BigInt(Math.floor(200 * 1e18)); // Adjust for gas compensation (200 USBD)

        console.log("Approving bmBTC...");
        await hre.midl.callContract("StakedBTC", "approve", {
            args: [borrowerOperationsAddress, amountInWei],
            to: bmBTCAddress,
            gas: 10000000n,
        });
        console.log("bmBTC Approved");

        console.log("Queuing open trove position...");
        await hre.midl.callContract("BorrowerOperations", "openTrove", {
            args: [
                troveManagerAddress, // Trove Manager address
                borrowerAddress, // Borrower address
                BigInt(Math.floor(1 * 1e18)), // maxFeePercentage (1 in Ether units)
                amountInWei, // Collateral amount (bmBTC)
                percentageAmount, // Debt amount (USBD to mint)
                "0x0000000000000000000000000000000000000000", // upperHint
                "0x0000000000000000000000000000000000000000", // lowerHint
            ],
            to: borrowerOperationsAddress,
            gas: 10000000n,
        });
        console.log("Open Position Queued");

        console.log("Executing transaction...");
        await hre.midl.execute({ skipEstimateGasMulti: true });
        console.log("Transaction executed successfully");
    } catch (error) {
        console.error("Error executing open trove:", error);
        throw error;
    }
}

// Export the function for Hardhat to use
module.exports = main;
module.exports.tags = ["main", "ReadTest"];

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
