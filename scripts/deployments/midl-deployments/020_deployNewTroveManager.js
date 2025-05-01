/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();

        console.log("\n________________________________\n");

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
        const bimaCoreAddress = (await hre.midl.getDeployment("BimaCore")).address;

        const bimaCore = await hre.ethers.getContractAt("BimaCore", bimaCoreAddress, signer);
        const priceFeed = await hre.ethers.getContractAt("PriceFeed", priceFeedAddress, signer);
        const factory = await hre.ethers.getContractAt("Factory", factoryAddress, signer);
        const bimaVault = await hre.ethers.getContractAt("BimaVault", bimaVaultAddress, signer);

        const bimaCoreOwner = await bimaCore.owner();
        console.log("BimaCore Owner:", bimaCoreOwner);
        if (bimaCoreOwner.toLowerCase() !== owner.toLowerCase()) {
            throw new Error(
                `Ownership mismatch: The MIDL wallet (${owner}) is not the owner of BimaCore. Current owner is ${bimaCoreOwner}. ` +
                    `Please transfer ownership of BimaCore to ${owner} by calling transferOwnership(${owner}) on BimaCore ` +
                    `from the current owner (${bimaCoreOwner}) using a wallet interface (e.g., Hardhat Console, MetaMask). ` +
                    `Then re-run this script.`
            );
        } else {
            console.log("Ownership verified: MIDL wallet is the owner of BimaCore.");
        }

        let priceFeedOwner;
        try {
            priceFeedOwner = await priceFeed.owner();
            console.log("PriceFeed Owner (if applicable):", priceFeedOwner);
            if (priceFeedOwner.toLowerCase() !== owner.toLowerCase()) {
                throw new Error(
                    `PriceFeed ownership mismatch: The MIDL wallet (${owner}) is not the owner of PriceFeed. Current owner is ${priceFeedOwner}. ` +
                        `Please transfer ownership of PriceFeed to ${owner} by calling transferOwnership(${owner}) on PriceFeed ` +
                        `from the current owner (${priceFeedOwner}) using a wallet interface (e.g., Hardhat Console, MetaMask). ` +
                        `Then re-run this script.`
                );
            } else {
                console.log("Ownership verified: MIDL wallet is the owner of PriceFeed (if applicable).");
            }
        } catch (error) {
            console.log("Note: PriceFeed does not have an 'owner' function; may have a different access control.");
        }

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

        // Step 1: Set Oracle on PriceFeed contract
        console.log("Setting Oracle on PriceFeed contract...");
        const setOracleTx = await priceFeed
            .connect(signer)
            .setOracle(
                collateralAddress,
                oracleAddress,
                ORACLE_HEARBEAT,
                SHARE_PRICE_SIGNATURE,
                SHARE_PRICE_DECIMALS,
                IS_BASE_CURRENCY_ETH_INDEXED
            );
        await setOracleTx.wait();
        console.log("Oracle is set on PriceFeed contract!");

        console.log("\n________________________________\n");

        // Step 2: Wait for 10 seconds to avoid transaction reversion
        console.log("Waiting for 10 seconds before the next transaction...");
        await new Promise((res) => setTimeout(res, 10000));

        // Step 3: Deploy new TroveManager via Factory contract
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

        // Step 4: Log updated troveManagerCount and fetch TroveManager address
        const troveManagerCount = await factory.troveManagerCount();
        console.log("troveManagerCount after:", troveManagerCount.toString());
        const troveManagerAddress = await factory.troveManagers(BigInt(String(Number(troveManagerCount) - 1)));
        console.log("New TroveManager Address:", troveManagerAddress);

        console.log("\n________________________________\n");

        // Step 5: Register TroveManager as receiver in BimaVault
        console.log("Registering TroveManager as receiver in BimaVault...");
        const registerTx = await bimaVault.registerReceiver(troveManagerAddress, REGISTERED_RECEIVER_COUNT);
        await registerTx.wait();
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
