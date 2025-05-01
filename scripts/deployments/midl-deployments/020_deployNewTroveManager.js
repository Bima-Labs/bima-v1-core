/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        const owner = hre.midl.wallet.getEVMAddress();
        const signer = await hre.ethers.getSigner(owner);
        console.log("Owner address (MIDL wallet):", owner);

        const provider = new hre.ethers.JsonRpcProvider("https://evm-rpc.regtest.midl.xyz");
        const deployerNonce = await provider.getTransactionCount(owner);
        console.log("Deployer nonce:", deployerNonce);
        console.log("Signer:", signer.address);

        const collateralAddress = (await hre.midl.getDeployment("StakedBTC")).address;
        const factoryAddress = (await hre.midl.getDeployment("Factory")).address;
        const priceFeedAddress = (await hre.midl.getDeployment("PriceFeed")).address;
        const bimaVaultAddress = (await hre.midl.getDeployment("BimaVault")).address;
        const oracleAddress = (await hre.midl.getDeployment("MockOracle")).address;
        const factory = await hre.ethers.getContractAt("Factory", factoryAddress, signer);

        console.log("\n________\n");

        const ORACLE_HEARBEAT = BigInt("3600");
        const SHARE_PRICE_SIGNATURE = "0x00000000";
        const SHARE_PRICE_DECIMALS = BigInt("18");
        const IS_BASE_CURRENCY_ETH_INDEXED = false;

        const CUSTOM_TROVE_MANAGER_IMPL_ADDRESS = hre.ethers.ZeroAddress;
        const CUSTOM_SORTED_TROVES_IMPL_ADDRESS = hre.ethers.ZeroAddress;

        const MINUTE_DECAY_FACTOR = BigInt("999037758833783000");
        const REDEMPTION_FEE_FLOOR = hre.ethers.parseEther("0.005");
        const MAX_REDEMPTION_FEE = hre.ethers.parseEther("1");
        const BORROWING_FEE_FLOOR = hre.ethers.parseEther("0.01");
        const MAX_BORROWING_FEE = hre.ethers.parseEther("0.03");
        const INTEREST_RATE_IN_BPS = BigInt("0");
        const MAX_DEBT = hre.ethers.parseEther("100000000000");
        const MCR = hre.ethers.parseUnits("1.5", 18);

        const REGISTERED_RECEIVER_COUNT = BigInt("2");

        const initialTroveManagerCount = await factory.troveManagerCount();
        console.log("troveManagerCount before:", initialTroveManagerCount.toString());

        // Step 1: Queue setOracle on PriceFeed contract using midl.callContract
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

        // Execute the queued transaction
        await hre.midl.execute({ skipEstimateGasMulti: true });
        console.log("Oracle is set on PriceFeed contract!");

        console.log("\n________________________________\n");

        // Step 2: Wait for 10 seconds to avoid transaction reversion
        console.log("Waiting for 10 seconds before the next transaction...");
        await new Promise((res) => setTimeout(res, 10000));

        // Step 3: Queue deployNewInstance on Factory contract using midl.callContract
        console.log("Deploying new TroveManager via Factory contract...");
        await hre.midl.callContract("Factory", "deployNewInstance", {
            address: factoryAddress,
            args: [
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
                },
            ],
            gas: BigInt(1000000),
        });
        console.log("deployNewInstance call queued");

        // Execute the queued transaction
        await hre.midl.execute({ skipEstimateGasMulti: true });
        console.log("New TroveManager is deployed from Factory contract!");

        // Step 4: Log updated troveManagerCount and fetch TroveManager address
        const troveManagerCount = await factory.troveManagerCount();
        console.log("troveManagerCount after:", troveManagerCount.toString());
        const troveManagerAddress = await factory.troveManagers(BigInt(String(Number(troveManagerCount) - 1)));
        console.log("New TroveManager Address:", troveManagerAddress);

        console.log("\n________________________________\n");

        // Step 5: Queue registerReceiver on BimaVault contract using midl.callContract
        console.log("Registering TroveManager as receiver in BimaVault...");
        await hre.midl.callContract("BimaVault", "registerReceiver", {
            address: bimaVaultAddress,
            args: [troveManagerAddress, REGISTERED_RECEIVER_COUNT],
            gas: BigInt(1000000),
        });
        console.log("registerReceiver call queued");

        // Execute the queued transaction
        await hre.midl.execute({ skipEstimateGasMulti: true });
        console.log("Receiver has been registered!");

        console.log("\n________________________________\n");

        // Step 6: Log successful completion
        console.log("Deployment and configuration completed successfully!");
    } catch (error) {
        console.error("Error executing script:", error);
        throw error;
    }
}

module.exports = main;

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
