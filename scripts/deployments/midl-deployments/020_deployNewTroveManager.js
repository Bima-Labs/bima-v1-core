/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const owner = hre.midl.wallet.getEVMAddress();
        console.log("Owner address:", owner);

        // Use the provider recommended by MIDL team
        const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        const deployerNonce = await provider.getTransactionCount(owner);
        console.log("Deployer nonce:", deployerNonce);

        // Fetch deployed contract addresses
        const collateralAddress = (await hre.midl.getDeployment("StakedBTC")).address; // Deployed in 018
        const factoryAddress = (await hre.midl.getDeployment("Factory")).address; // Deployed in 005
        const priceFeedAddress = (await hre.midl.getDeployment("PriceFeed")).address; // Deployed in 002
        const bimaVaultAddress = (await hre.midl.getDeployment("BimaVault")).address; // Deployed in 014
        const oracleAddress = (await hre.midl.getDeployment("MockOracle")).address; // Deployed in 019

        console.log("Collateral (StakedBTC) Address:", collateralAddress);
        console.log("Factory Address:", factoryAddress);
        console.log("PriceFeed Address:", priceFeedAddress);
        console.log("BimaVault Address:", bimaVaultAddress);
        console.log("Oracle Address:", oracleAddress);

        // Constants from the original script
        const ORACLE_HEARBEAT = BigInt("3600");
        const SHARE_PRICE_SIGNATURE = "0x00000000";
        const SHARE_PRICE_DECIMALS = BigInt("18");
        const IS_BASE_CURRENCY_ETH_INDEXED = false;

        const CUSTOM_TROVE_MANAGER_IMPL_ADDRESS = hre.ethers.ZeroAddress;
        const CUSTOM_SORTED_TROVES_IMPL_ADDRESS = hre.ethers.ZeroAddress;

        const MINUTE_DECAY_FACTOR = BigInt("999037758833783000");
        const REDEMPTION_FEE_FLOOR = hre.ethers.parseEther("0.005"); // 0.5%
        const MAX_REDEMPTION_FEE = hre.ethers.parseEther("1"); // 100%
        const BORROWING_FEE_FLOOR = hre.ethers.parseEther("0.01"); // 1%
        const MAX_BORROWING_FEE = hre.ethers.parseEther("0.03"); // 3%
        const INTEREST_RATE_IN_BPS = BigInt("0"); // 0%
        const MAX_DEBT = hre.ethers.parseEther("10000000000"); // 10b
        const MCR = hre.ethers.parseUnits("1.5", 18); // 150%

        const REGISTERED_RECEIVER_COUNT = BigInt("2");

        // Get contract instances using ethers (for interaction)
        const priceFeed = await hre.ethers.getContractAt("PriceFeed", priceFeedAddress);
        const factory = await hre.ethers.getContractAt("Factory", factoryAddress);
        const bimaVault = await hre.ethers.getContractAt("BimaVault", bimaVaultAddress);

        // Log initial troveManagerCount
        const initialTroveManagerCount = await factory.troveManagerCount();
        console.log("troveManagerCount before:", initialTroveManagerCount.toString());

        // Step 1: Set Oracle on PriceFeed
        console.log("Setting Oracle on PriceFeed contract...");
        const setOracleTx = await priceFeed.setOracle(
            collateralAddress,
            oracleAddress,
            ORACLE_HEARBEAT,
            SHARE_PRICE_SIGNATURE,
            SHARE_PRICE_DECIMALS,
            IS_BASE_CURRENCY_ETH_INDEXED
        );
        await setOracleTx.wait();
        console.log("Oracle is set on PriceFeed contract!");

        // Wait for 10 seconds as per the original script to avoid transaction reversion
        console.log("Waiting for 10 seconds before the next transaction...");
        await new Promise((res) => setTimeout(res, 10000));

        // Step 2: Deploy new TroveManager instance via Factory
        console.log("Deploying new TroveManager via Factory contract...");
        const deployTx = await factory.deployNewInstance(
            collateralAddress,
            priceFeedAddress,
            CUSTOM_TROVE_MANAGER_IMPL_ADDRESS,
            CUSTOM_SORTED_TROVES_IMPL_ADDRESS,
            {
                minuteDecayFactor: MINUTE_DECAY_FACTOR,
                redemptionFeeFloor: REDEMPTION_FEE_FLOOR,
                maxRedemptionFee: MAX_REDEMPTION_FEE,
                borrowingFeeFloor: BORROWING_FEE_FLOOR,
                maxBorrowingFee: MAX_BORROWING_FEE,
                interestRateInBps: INTEREST_RATE_IN_BPS,
                maxDebt: MAX_DEBT,
                MCR: MCR,
            }
        );
        await deployTx.wait();
        console.log("New TroveManager is deployed from Factory contract!");

        // Log updated troveManagerCount
        const troveManagerCount = await factory.troveManagerCount();
        console.log("troveManagerCount after:", troveManagerCount.toString());

        // Fetch the new TroveManager address
        const troveManagerAddress = await factory.troveManagers(BigInt(String(Number(troveManagerCount) - 1)));
        console.log("New TroveManager Address:", troveManagerAddress);

        // Step 3: Register the new TroveManager as a receiver in BimaVault
        console.log("Registering TroveManager as receiver in BimaVault...");
        const registerTx = await bimaVault.registerReceiver(troveManagerAddress, REGISTERED_RECEIVER_COUNT);
        await registerTx.wait();
        console.log("Receiver has been registered!");

        console.log("_________________________________________________");
        console.log("Deployment and configuration completed successfully!");
    } catch (error) {
        console.error("Error executing script:", error);
        throw error;
    }
}

// Export the function for Hardhat to use
module.exports = main;

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
