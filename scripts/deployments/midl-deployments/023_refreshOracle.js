/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const mockOracleAddress = "0x0A03bdcf188C242f4CB53AeFE38AE39560a70D01";

        // Verify the deployer address (optional, for debugging)
        const deployerAddress = hre.midl.wallet.getEVMAddress();
        console.log("Deployer address:", deployerAddress);

        console.log(`Refreshing MockOracle at address: ${mockOracleAddress}...`);
        await hre.midl.callContract("MockOracle", "refresh", {
            args: [],
            to: mockOracleAddress,
            gas: 1000000n, // Adjust gas limit if needed
        });
        console.log("refresh() function queued");

        console.log("Executing transaction...");
        await hre.midl.execute();
        console.log("refresh() function called successfully");

        console.log("Reading latestRoundData...");
        const [roundId, answer, startedAt, updatedAt, answeredInRound] = await hre.midl.callContract(
            "MockOracle",
            "latestRoundData",
            {
                args: [],
                to: mockOracleAddress,
                view: true, // Indicate this is a view call
            }
        );
        console.log("Updated round data after refresh:");
        console.log(`Round ID: ${roundId}`);
        console.log(`Answer: ${answer}`);
        console.log(`Started At: ${startedAt}`);
        console.log(`Updated At: ${updatedAt}`);
        console.log(`Answered In Round: ${answeredInRound}`);
    } catch (error) {
        console.error("Error refreshing MockOracle:", error);
        throw error;
    }
}

// Export the function for Hardhat to use
module.exports = main;
module.exports.tags = ["main", "RefreshMockOracle"];

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
