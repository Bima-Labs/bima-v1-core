/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

const DEBT_TOKEN_NAME = "US Bitcoin Dollar"; // ! IMPORTANT
const DEBT_TOKEN_SYMBOL = "USBD"; // ! IMPORTANT

const GAS_COMPENSATION = ethers.parseUnits("200", 18); // ! 200 USBD
const MIN_NET_DEBT = ethers.parseUnits("10", 18); // ! 10 USDB
const LOCK_TO_TOKEN_RATIO = ethers.parseUnits("1", 18); // ! 1 BIMA

const LZ_ENDPOINT = ethers.ZeroAddress; // ! IMPORTANT

async function main(hre) {
    /**
     * Initializes MIDL hardhat deploy SDK
     */
    try {
        await hre.midl.initialize();

        const [owner] = await ethers.getSigners();

        // ! IMPORTANT: Replace with actual MIDL-safe addresses for production
        const BIMA_OWNER_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";
        const BIMA_GUARDIAN_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";
        const LZ_DELEGATE_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";
        const FEE_RECEIVER_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";
        const TOKEN_LOCKER_DEPLOYMENT_MANAGER = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";
        const BIMA_VAULT_DEPLOYMENT_MANAGER = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";

        let deployerNonce = await ethers.provider.getTransactionCount(owner.address);

        // Predict contract addresses for interdependencies
        const predictedAddresses = {
            bimaCore: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 1,
            }),
            priceFeed: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 2,
            }),
            gasPool: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 3,
            }),
            sortedTroves: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 4,
            }),
        };

        /**
         * Add the deploy contract transaction intentions
         */
        // Deploy BimaWrappedCollateralFactory
        await hre.midl.deploy("BimaWrappedCollateralFactory", {
            args: [predictedAddresses.bimaCore],
        });

        // Deploy BimaCore
        await hre.midl.deploy("BimaCore", {
            args: [BIMA_OWNER_ADDRESS, BIMA_GUARDIAN_ADDRESS, predictedAddresses.priceFeed, FEE_RECEIVER_ADDRESS],
        });

        // Deploy PriceFeed
        await hre.midl.deploy("PriceFeed", {
            args: [predictedAddresses.bimaCore],
        });

        // Deploy GasPool
        await hre.midl.deploy("GasPool", {
            args: [],
        });

        // Deploy SortedTroves
        await hre.midl.deploy("SortedTroves", {
            args: [],
        });

        deployerNonce = await ethers.provider.getTransactionCount(owner.address);

        // Predict remaining contract addresses
        const predictedAddresses2 = {
            factory: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce,
            }),
            liquidationManager: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 1,
            }),
            debtToken: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 2,
            }),
            borrowerOperations: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 3,
            }),
            stabilityPool: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 4,
            }),
            troveManager: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 5,
            }),
            tokenLocker: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 6,
            }),
            incentiveVoting: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 7,
            }),
            bimaToken: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 8,
            }),
            bimaVault: ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 9,
            }),
        };

        // Deploy Factory
        await hre.midl.deploy("Factory", {
            args: [
                predictedAddresses.bimaCore,
                predictedAddresses2.debtToken,
                predictedAddresses2.stabilityPool,
                predictedAddresses2.borrowerOperations,
                predictedAddresses.sortedTroves,
                predictedAddresses2.troveManager,
                predictedAddresses2.liquidationManager,
            ],
        });

        // Deploy LiquidationManager
        await hre.midl.deploy("LiquidationManager", {
            args: [
                predictedAddresses2.stabilityPool,
                predictedAddresses2.borrowerOperations,
                predictedAddresses2.factory,
                GAS_COMPENSATION,
            ],
        });

        // Deploy DebtToken
        await hre.midl.deploy("DebtToken", {
            args: [
                DEBT_TOKEN_NAME,
                DEBT_TOKEN_SYMBOL,
                predictedAddresses2.stabilityPool,
                predictedAddresses2.borrowerOperations,
                predictedAddresses.bimaCore,
                LZ_ENDPOINT,
                predictedAddresses2.factory,
                predictedAddresses.gasPool,
                GAS_COMPENSATION,
                LZ_DELEGATE_ADDRESS,
            ],
        });

        // Deploy BorrowerOperations
        await hre.midl.deploy("BorrowerOperations", {
            args: [
                predictedAddresses.bimaCore,
                predictedAddresses2.debtToken,
                predictedAddresses2.factory,
                MIN_NET_DEBT,
                GAS_COMPENSATION,
            ],
        });

        // Deploy StabilityPool
        await hre.midl.deploy("StabilityPool", {
            args: [
                predictedAddresses.bimaCore,
                predictedAddresses2.debtToken,
                predictedAddresses2.bimaVault,
                predictedAddresses2.factory,
                predictedAddresses2.liquidationManager,
            ],
        });

        // Deploy TroveManager
        await hre.midl.deploy("TroveManager", {
            args: [
                predictedAddresses.bimaCore,
                predictedAddresses.gasPool,
                predictedAddresses2.debtToken,
                predictedAddresses2.borrowerOperations,
                predictedAddresses2.bimaVault,
                predictedAddresses2.liquidationManager,
                GAS_COMPENSATION,
            ],
        });

        // Deploy TokenLocker
        await hre.midl.deploy("TokenLocker", {
            args: [
                predictedAddresses.bimaCore,
                predictedAddresses2.bimaToken,
                predictedAddresses2.incentiveVoting,
                TOKEN_LOCKER_DEPLOYMENT_MANAGER,
                LOCK_TO_TOKEN_RATIO,
            ],
        });

        // Deploy IncentiveVoting
        await hre.midl.deploy("IncentiveVoting", {
            args: [predictedAddresses.bimaCore, predictedAddresses2.tokenLocker, predictedAddresses2.bimaVault],
        });

        // Deploy BimaToken
        await hre.midl.deploy("BimaToken", {
            args: [predictedAddresses2.bimaVault, LZ_ENDPOINT, predictedAddresses2.tokenLocker, LZ_DELEGATE_ADDRESS],
        });

        // Deploy BimaVault
        await hre.midl.deploy("BimaVault", {
            args: [
                predictedAddresses.bimaCore,
                predictedAddresses2.bimaToken,
                predictedAddresses2.tokenLocker,
                predictedAddresses2.incentiveVoting,
                predictedAddresses2.stabilityPool,
                BIMA_VAULT_DEPLOYMENT_MANAGER,
            ],
        });

        // Deploy Helper Contracts
        await hre.midl.deploy("MultiCollateralHintHelpers", {
            args: [predictedAddresses2.borrowerOperations, GAS_COMPENSATION],
        });

        await hre.midl.deploy("MultiTroveGetter", {
            args: [],
        });

        await hre.midl.deploy("TroveManagerGetters", {
            args: [predictedAddresses2.factory],
        });

        /**
         * Sends the BTC transaction and EVM transaction to the network
         */
        await hre.midl.execute();

        /**
         * Verify deployed addresses post-execution
         */
        const { deployments } = hre;
        const deployedAddresses = {
            bimaCore: (await deployments.get("BimaCore")).address,
            priceFeed: (await deployments.get("PriceFeed")).address,
            gasPool: (await deployments.get("GasPool")).address,
            sortedTroves: (await deployments.get("SortedTroves")).address,
            factory: (await deployments.get("Factory")).address,
            liquidationManager: (await deployments.get("LiquidationManager")).address,
            debtToken: (await deployments.get("DebtToken")).address,
            borrowerOperations: (await deployments.get("BorrowerOperations")).address,
            stabilityPool: (await deployments.get("StabilityPool")).address,
            troveManager: (await deployments.get("TroveManager")).address,
            tokenLocker: (await deployments.get("TokenLocker")).address,
            incentiveVoting: (await deployments.get("IncentiveVoting")).address,
            bimaToken: (await deployments.get("BimaToken")).address,
            bimaVault: (await deployments.get("BimaVault")).address,
        };

        // Verify predicted addresses
        assertEq(predictedAddresses.bimaCore, deployedAddresses.bimaCore);
        assertEq(predictedAddresses.priceFeed, deployedAddresses.priceFeed);
        assertEq(predictedAddresses.gasPool, deployedAddresses.gasPool);
        assertEq(predictedAddresses.sortedTroves, deployedAddresses.sortedTroves);
        assertEq(predictedAddresses2.factory, deployedAddresses.factory);
        assertEq(predictedAddresses2.liquidationManager, deployedAddresses.liquidationManager);
        assertEq(predictedAddresses2.debtToken, deployedAddresses.debtToken);
        assertEq(predictedAddresses2.borrowerOperations, deployedAddresses.borrowerOperations);
        assertEq(predictedAddresses2.stabilityPool, deployedAddresses.stabilityPool);
        assertEq(predictedAddresses2.troveManager, deployedAddresses.troveManager);
        assertEq(predictedAddresses2.tokenLocker, deployedAddresses.tokenLocker);
        assertEq(predictedAddresses2.incentiveVoting, deployedAddresses.incentiveVoting);
        assertEq(predictedAddresses2.bimaToken, deployedAddresses.bimaToken);
        assertEq(predictedAddresses2.bimaVault, deployedAddresses.bimaVault);
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
