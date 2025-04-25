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

        // const [owner] = await ethers.getSigners();
        const owner = hre.midl.wallet.getEVMAddress(); //0xF5EEeCDd8b7790A6CA1021e019f96DBD9470F2f9
        console.log("Owner address:", owner);
        const deployerNonce = await ethers.provider.getTransactionCount(owner);

        // Predict PriceFeed address (deployed in next script)
        const priceFeedAddress = ethers.getCreateAddress({
            from: owner,
            nonce: deployerNonce + 1,
        });
        // Deploy BimaCore
        await hre.midl.deploy("BimaCore", {
            args: [BIMA_OWNER_ADDRESS, BIMA_GUARDIAN_ADDRESS, priceFeedAddress, FEE_RECEIVER_ADDRESS],
        });

        const bimaCoreAddress = await hre.midl.getDeployment("BimaCore");
        console.log("BimaCore Deployed Address:", bimaCoreAddress);
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

const assertEq = (a, b) => {
    if (a !== b) throw new Error(`Expected ${a} to equal ${b}`);
};
