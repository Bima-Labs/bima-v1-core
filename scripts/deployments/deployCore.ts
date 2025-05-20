import { BaseContract, ContractFactory } from "ethers";
import { ethers } from "hardhat";
import hre from "hardhat";

const DEBT_TOKEN_NAME = "US Bitcoin Dollar"; //! IMPORTANT
const DEBT_TOKEN_SYMBOL = "USBD"; //! IMPORTANT

const GAS_COMPENSATION = ethers.parseUnits("200", 18); //! 200 USBD
const MIN_NET_DEBT = ethers.parseUnits("10", 18); //! 10 USDB
const LOCK_TO_TOKEN_RATIO = ethers.parseUnits("1", 18); //! 1 BIMA

const LZ_ENDPOINT = "0x6EDCE65403992e310A62460808c4b910D972f10f";//ethers.ZeroAddress; //! IMPORTANT

const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function deployCore() {
    const [owner] = await ethers.getSigners();

    const BIMA_OWNER_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5"; //! IMPORTANT
    const BIMA_GUARDIAN_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5"; //! IMPORTANT
    const LZ_DELEGATE_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5"; //! IMPORTANT
    const FEE_RECEIVER_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5"; //! IMPORTANT
    const TOKEN_LOCKER_DEPLOYMENT_MANAGER = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5"; //! IMPORTANT
    const BIMA_VAULT_DEPLOYMENT_MANAGER = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5"; //! IMPORTANT

    const factories = await getFactories();

    let deployerNonce = await ethers.provider.getTransactionCount(owner.address);

    // Disgusting hack to get the addresses of the contracts before deployment
    const bimaCoreAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce + 1,
    });

    const priceFeedAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce + 2,
    });

    const [, bimaWrappedCollateralFactoryAddress] = await deployContract(factories.BimaWrappedCollateralFactory, "BimaWrappedCollateralFactory", bimaCoreAddress);

    const [, deployedBimaCoreAddress] = await deployContract(
        factories.BimaCore,
        "BimaCore",
        BIMA_OWNER_ADDRESS,
        BIMA_GUARDIAN_ADDRESS,
        priceFeedAddress,
        FEE_RECEIVER_ADDRESS
    );
    assertEq(bimaCoreAddress, deployedBimaCoreAddress);

    const [, deployedPriceFeedAddress] = await deployContract(factories.PriceFeed, "PriceFeed", bimaCoreAddress);
    assertEq(priceFeedAddress, deployedPriceFeedAddress);

    const [, gasPoolAddress] = await deployContract(factories.GasPool, "GasPool");

    const [, sortedTrovesAddress] = await deployContract(factories.SortedTroves, "SortedTroves");

    deployerNonce = await ethers.provider.getTransactionCount(owner.address);

    // Disgusting hack to get the addresses of the contracts before deployment
    const factoryAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce,
    });

    const liqudiationManagerAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce + 1,
    });

    const debtTokenAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce + 2,
    });

    const borrowerOperationsAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce + 3,
    });

    const stabilityPoolAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce + 4,
    });

    const troveManagerAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce + 5,
    });

    const tokenLockerAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce + 6,
    });

    const incentiveVotingAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce + 7,
    });

    const bimaTokenAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce + 8,
    });

    const bimaVaultAddress = ethers.getCreateAddress({
        from: owner.address,
        nonce: deployerNonce + 9,
    });

    const [, deployedFactoryAddress] = await deployContract(
        factories.Factory,
        "Factory",
        bimaCoreAddress,
        debtTokenAddress,
        stabilityPoolAddress,
        borrowerOperationsAddress,
        sortedTrovesAddress,
        troveManagerAddress,
        liqudiationManagerAddress
    );
    assertEq(factoryAddress, deployedFactoryAddress);

    const [, deployedLiquidationManagerAddress] = await deployContract(
        factories.LiquidationManager,
        "LiquidationManager",
        stabilityPoolAddress,
        borrowerOperationsAddress,
        factoryAddress,
        GAS_COMPENSATION
    );
    assertEq(liqudiationManagerAddress, deployedLiquidationManagerAddress);

    const [, deployedDebtTokenAddress] = await deployContract(
        factories.DebtToken,
        "DebtToken",
        DEBT_TOKEN_NAME,
        DEBT_TOKEN_SYMBOL,
        stabilityPoolAddress,
        borrowerOperationsAddress,
        bimaCoreAddress,
        LZ_ENDPOINT,
        factoryAddress,
        gasPoolAddress,
        GAS_COMPENSATION,
        LZ_DELEGATE_ADDRESS
    );
    assertEq(debtTokenAddress, deployedDebtTokenAddress);

    const [, deployedBorrowerOperationsAddress] = await deployContract(
        factories.BorrowerOperations,
        "BorrowerOperations",
        bimaCoreAddress,
        debtTokenAddress,
        factoryAddress,
        MIN_NET_DEBT,
        GAS_COMPENSATION
    );
    assertEq(borrowerOperationsAddress, deployedBorrowerOperationsAddress);

    const [, deployedStabilityPoolAddress] = await deployContract(
        factories.StabilityPool,
        "StabilityPool",
        bimaCoreAddress,
        debtTokenAddress,
        bimaVaultAddress,
        factoryAddress,
        liqudiationManagerAddress
    );
    assertEq(stabilityPoolAddress, deployedStabilityPoolAddress);

    const [, deployedTroveManagerAddress] = await deployContract(
        factories.TroveManager,
        "TroveManager",
        bimaCoreAddress,
        gasPoolAddress,
        debtTokenAddress,
        borrowerOperationsAddress,
        bimaVaultAddress,
        liqudiationManagerAddress,
        GAS_COMPENSATION
    );
    assertEq(troveManagerAddress, deployedTroveManagerAddress);

    const [, deployedTokenLockerAddress] = await deployContract(
        factories.TokenLocker,
        "TokenLocker",
        bimaCoreAddress,
        bimaTokenAddress,
        incentiveVotingAddress,
        TOKEN_LOCKER_DEPLOYMENT_MANAGER, // Change this with gnosis safe for real deployment...
        LOCK_TO_TOKEN_RATIO
    );
    assertEq(tokenLockerAddress, deployedTokenLockerAddress);

    const [, deployedIncentiveVotingAddress] = await deployContract(
        factories.IncentiveVoting,
        "IncentiveVoting",
        bimaCoreAddress,
        tokenLockerAddress,
        bimaVaultAddress
    );
    assertEq(incentiveVotingAddress, deployedIncentiveVotingAddress);

    const [, deployedBimaTokenAddress] = await deployContract(
        factories.BimaToken,
        "BimaToken",
        bimaVaultAddress,
        LZ_ENDPOINT,
        tokenLockerAddress,
        LZ_DELEGATE_ADDRESS
    );
    assertEq(bimaTokenAddress, deployedBimaTokenAddress);

    const [, deployedBimaVaultAddress] = await deployContract(
        factories.BimaVault,
        "BimaVault",
        bimaCoreAddress,
        bimaTokenAddress,
        tokenLockerAddress,
        incentiveVotingAddress,
        stabilityPoolAddress,
        BIMA_VAULT_DEPLOYMENT_MANAGER
    );
    assertEq(bimaVaultAddress, deployedBimaVaultAddress);

    // ========== DEPLOYING HELPER CONTRACTS ========== //

    const [, multiCollateralHintHelpersAddress] = await deployContract(
        factories.MultiCollateralHintHelpers,
        "MultiCollateralHintHelpers",
        borrowerOperationsAddress,
        GAS_COMPENSATION
    );

    const [, multiTroveGetterAddress] = await deployContract(factories.MultiTroveGetter, "MultiTroveGetter");

    const [, troveManagerGettersAddress]= await deployContract(factories.TroveManagerGetters, "TroveManagerGetters", factoryAddress);

    // ========== DEPLOYING A BURNER CONTRACT ========== //

    const [, burenrContractAddress] = await deployContract(factories.BimaBurner, "BimaBurner");

        /**
     * Verify the contracts
     */
     await verifyContract(
        bimaWrappedCollateralFactoryAddress,
        "contracts/wrappers/BimaWrappedCollateralFactory.sol:BimaWrappedCollateralFactory",
        [bimaCoreAddress]
    );
    await verifyContract(
        deployedBimaCoreAddress,
        "contracts/core/BimaCore.sol:BimaCore",
        [
            BIMA_OWNER_ADDRESS,
            BIMA_GUARDIAN_ADDRESS,
            priceFeedAddress,
            FEE_RECEIVER_ADDRESS
        ]
    );
    await verifyContract(
        deployedPriceFeedAddress,
        "contracts/core/PriceFeed.sol:PriceFeed",
        [bimaCoreAddress]
    );
    await verifyContract(
        gasPoolAddress,
        "contracts/core/GasPool.sol:GasPool",
        []
    );
    await verifyContract(
        sortedTrovesAddress,
        "contracts/core/SortedTroves.sol:SortedTroves",
        []
    );
    await verifyContract(
        deployedFactoryAddress,
        "contracts/core/Factory.sol:Factory",
        [
            bimaCoreAddress,
            debtTokenAddress,
            stabilityPoolAddress,
            borrowerOperationsAddress,
            sortedTrovesAddress,
            troveManagerAddress,
            liqudiationManagerAddress
        ]
    );
    await verifyContract(
        deployedLiquidationManagerAddress,
        "contracts/core/LiquidationManager.sol:LiquidationManager",
        [
            stabilityPoolAddress,
            borrowerOperationsAddress,
            factoryAddress,
            GAS_COMPENSATION
        ]
    );
    await verifyContract(
        deployedDebtTokenAddress,
        "contracts/core/DebtToken.sol:DebtToken",
        [
            DEBT_TOKEN_NAME,
            DEBT_TOKEN_SYMBOL,
            stabilityPoolAddress,
            borrowerOperationsAddress,
            bimaCoreAddress,
            LZ_ENDPOINT,
            factoryAddress,
            gasPoolAddress,
            GAS_COMPENSATION,
            LZ_DELEGATE_ADDRESS
        ]
    );
    await verifyContract(
        deployedBorrowerOperationsAddress,
        "contracts/core/BorrowerOperations.sol:BorrowerOperations",
        [
            bimaCoreAddress,
            debtTokenAddress,
            factoryAddress,
            MIN_NET_DEBT,
            GAS_COMPENSATION
        ]
    );
    await verifyContract(
        deployedStabilityPoolAddress,
        "contracts/core/StabilityPool.sol:StabilityPool",
        [
            bimaCoreAddress,
            debtTokenAddress,
            bimaVaultAddress,
            factoryAddress,
            liqudiationManagerAddress
        ]
    );
    await verifyContract(
        deployedTroveManagerAddress,
        "contracts/core/TroveManager.sol:TroveManager",
        [
            bimaCoreAddress,
            gasPoolAddress,
            debtTokenAddress,
            borrowerOperationsAddress,
            bimaVaultAddress,
            liqudiationManagerAddress,
            GAS_COMPENSATION
        ]
    );
    await verifyContract(
        deployedTokenLockerAddress,
        "contracts/dao/TokenLocker.sol:TokenLocker",
        [
            bimaCoreAddress,
            bimaTokenAddress,
            incentiveVotingAddress,
            TOKEN_LOCKER_DEPLOYMENT_MANAGER,
            LOCK_TO_TOKEN_RATIO
        ]
    );
    await verifyContract(
        deployedIncentiveVotingAddress,
        "contracts/dao/IncentiveVoting.sol:IncentiveVoting",
        [
            bimaCoreAddress,
            tokenLockerAddress,
            bimaVaultAddress
        ]
    );
    await verifyContract(
        deployedBimaTokenAddress,
        "contracts/dao/BimaToken.sol:BimaToken",
        [
            bimaVaultAddress,
            LZ_ENDPOINT,
            tokenLockerAddress,
            LZ_DELEGATE_ADDRESS
        ]
    );
    await verifyContract(
        deployedBimaVaultAddress,
        "contracts/dao/Vault.sol:BimaVault",
        [
            bimaCoreAddress,
            bimaTokenAddress,
            tokenLockerAddress,
            incentiveVotingAddress,
            stabilityPoolAddress,
            BIMA_VAULT_DEPLOYMENT_MANAGER
        ]
    );
    await verifyContract(
        multiCollateralHintHelpersAddress,
        "contracts/core/helpers/MultiCollateralHintHelpers.sol:MultiCollateralHintHelpers",
        [
            borrowerOperationsAddress,
            GAS_COMPENSATION
        ]
    );
    await verifyContract(
        multiTroveGetterAddress,
        "contracts/core/helpers/MultiTroveGetter.sol:MultiTroveGetter",
        []
    );
    await verifyContract(
        troveManagerGettersAddress,
        "contracts/core/helpers/TroveManagerGetters.sol:TroveManagerGetters",
        [factoryAddress]
    );

    await verifyContract(
        burenrContractAddress,
        "contracts/BimaBurner.sol:BimaBurner",
        []
    );
    console.log("All contracts deployed and verified successfully!");

    
}

deployCore()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

const getFactories = async () => ({
    MockStakedBTC: await ethers.getContractFactory("StakedBTC"),
    MockAggregator: await ethers.getContractFactory("MockOracle"),
    BimaCore: await ethers.getContractFactory("BimaCore"),
    PriceFeed: await ethers.getContractFactory("PriceFeed"),
    FeeReceiver: await ethers.getContractFactory("FeeReceiver"),
    InterimAdmin: await ethers.getContractFactory("InterimAdmin"),
    GasPool: await ethers.getContractFactory("GasPool"),
    Factory: await ethers.getContractFactory("Factory"),
    LiquidationManager: await ethers.getContractFactory("LiquidationManager"),
    BorrowerOperations: await ethers.getContractFactory("BorrowerOperations"),
    DebtToken: await ethers.getContractFactory("DebtToken"),
    StabilityPool: await ethers.getContractFactory("StabilityPool"),
    TroveManager: await ethers.getContractFactory("TroveManager"),
    SortedTroves: await ethers.getContractFactory("SortedTroves"),
    TokenLocker: await ethers.getContractFactory("TokenLocker"),
    IncentiveVoting: await ethers.getContractFactory("IncentiveVoting"),
    BimaToken: await ethers.getContractFactory("BimaToken"),
    BimaVault: await ethers.getContractFactory("BimaVault"),
    BimaWrappedCollateralFactory: await ethers.getContractFactory("BimaWrappedCollateralFactory"),
    MultiCollateralHintHelpers: await ethers.getContractFactory("MultiCollateralHintHelpers"),
    MultiTroveGetter: await ethers.getContractFactory("MultiTroveGetter"),
    TroveManagerGetters: await ethers.getContractFactory("TroveManagerGetters"),
    BimaBurner: await ethers.getContractFactory("BimaBurner"),
});

const deployContract = async (
    deployer: ContractFactory,
    contractName: string,
    ...args: any[]
): Promise<[BaseContract, string]> => {
    const contract = await deployer.deploy(...args);
    await contract.waitForDeployment();
    const address = await contract.getAddress();
    console.log(`${contractName} deployed!: `, address);
    return [contract, address];
};

/**
 * Verifies the contract 
 */
const verifyContract = async (
    address: string,
    contractPath: string,
    constructorArguments: any[]
) => {
    console.log(`Verifying ${contractPath} at ${address}...`);
    try {
        await hre.run("verify:verify", {
            address: address,
            contract: contractPath,
            constructorArguments: constructorArguments,
        });
        console.log(`${contractPath} verified successfully!`);
    } catch (error: any) {
        if (error.message.includes("Already Verified")) {
            console.log(`${contractPath} already verified!`);
        } else {
            console.error(`Error verifying ${contractPath}:`, error);
        }
    }
    await delay(3000);
};

const assertEq = (a: string, b: string) => {
    if (a !== b) throw new Error(`Expected ${a} to equal ${b}`);
};
