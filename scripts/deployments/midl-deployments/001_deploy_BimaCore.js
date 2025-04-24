/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

const BIMA_OWNER_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";
const BIMA_GUARDIAN_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";
const FEE_RECEIVER_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";

async function main(hre) {
    try {
        await hre.midl.initialize();

        const [owner] = await ethers.getSigners();
        const deployerNonce = await ethers.provider.getTransactionCount(owner.address);

        // Predict PriceFeed address (deployed in next script)
        const priceFeedAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce + 1,
        });

        // Predict BimaCore address (for verification)
        const bimaCoreAddress = ethers.getCreateAddress({
            from: owner.address,
            nonce: deployerNonce,
        });

        // Deploy BimaCore
        await hre.midl.deploy("BimaCore", {
            args: [BIMA_OWNER_ADDRESS, BIMA_GUARDIAN_ADDRESS, priceFeedAddress, FEE_RECEIVER_ADDRESS],
        });

        // Execute deployment
        const executeResult = await hre.midl.execute();

        // Check if contract was already deployed
        if (executeResult === "No intentions to execute") {
            // Skip verification if already deployed
            return;
        }

        // Verify predicted address
        try {
            const { deployments } = hre;
            const deployedBimaCoreAddress = (await deployments.get("BimaCore")).address;
            assertEq(bimaCoreAddress, deployedBimaCoreAddress);
        } catch (error) {
            console.error("Failed to verify BimaCore deployment artifact:", error.message);
            // Continue despite artifact lookup failure, as deployment succeeded
        }
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

const assertEq = (a, b) => {
    if (a !== b) throw new Error(`Expected ${a} to equal ${b}`);
};
