import { BaseContract, ContractFactory } from "ethers";
import { ethers } from "hardhat";

const DEBT_TOKEN_NAME = "US Bitcoin Dollar"; //! IMPORTANT
const DEBT_TOKEN_SYMBOL = "USBD"; //! IMPORTANT

const GAS_COMPENSATION = ethers.parseUnits("200", 18); //! 200 USBD
const MIN_NET_DEBT = ethers.parseUnits("1800", 18); //! 1800 USDB
const LOCK_TO_TOKEN_RATIO = ethers.parseUnits("1", 18); //! 1 BIMA

const LZ_ENDPOINT = ethers.ZeroAddress; //! IMPORTANT

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

    await deployContract(factories.BimaWrappedCollateralFactory, "BimaWrappedCollateralFactory", bimaCoreAddress);

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

    await deployContract(
        factories.MultiCollateralHintHelpers,
        "MultiCollateralHintHelpers",
        borrowerOperationsAddress,
        GAS_COMPENSATION
    );

    await deployContract(factories.MultiTroveGetter, "MultiTroveGetter");

    await deployContract(factories.TroveManagerGetters, "TroveManagerGetters", factoryAddress);
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

const assertEq = (a: string, b: string) => {
    if (a !== b) throw new Error(`Expected ${a} to equal ${b}`);
};
