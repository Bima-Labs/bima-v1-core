import { BaseContract, ContractFactory } from "ethers";
import { ethers } from "hardhat";
import { BabelCore } from "../../typechain-types";

const DEBT_TOKEN_NAME = "US Bitcoin Dollar"; //! IMPORTANT
const DEBT_TOKEN_SYMBOL = "USBD"; //! IMPORTANT

const GAS_COMPENSATION = ethers.parseUnits("200", 18); //! 200 USBD
const MIN_NET_DEBT = ethers.parseUnits("1800", 18); //! 1800 USDB
const LOCK_TO_TOKEN_RATIO = ethers.parseUnits("1", 18); //! 1 BABEL

const LZ_ENDPOINT = ethers.ZeroAddress; //! IMPORTANT

async function deployCore() {
  const [owner] = await ethers.getSigners();

  const BABEL_OWNER_ADDRESS = owner.address; //! IMPORTANT
  const BABEL_GUARDIAN_ADDRESS = owner.address; //! IMPORTANT
  const TOKEN_LOCKER_DEPLOYMENT_MANAGER = owner.address; //! IMPORTANT
  const BABEL_VAULT_DEPLOYMENT_MANAGER = owner.address; //! IMPORTANT

  const factories = await getFactories();

  const [, mockAaggregatorAddress] = await deployContract(factories.MockAggregator, "MockAggregator");

  let deployerNonce = await ethers.provider.getTransactionCount(owner.address);

  // Disgusting hack to get the addresses of the contracts before deployment
  const babelCoreAddress = ethers.getCreateAddress({
    from: owner.address,
    nonce: deployerNonce + 1,
  });

  const priceFeedAddress = ethers.getCreateAddress({
    from: owner.address,
    nonce: deployerNonce + 2,
  });

  const [, deployedFeeReceiverAddress] = await deployContract(factories.FeeReceiver, "FeeReceiver", babelCoreAddress);

  const [babelCore, deployedBabelCoreAddress] = await deployContract(
    factories.BabelCore,
    "BabelCore",
    BABEL_OWNER_ADDRESS,
    BABEL_GUARDIAN_ADDRESS,
    priceFeedAddress,
    deployedFeeReceiverAddress
  );
  assertEq(babelCoreAddress, deployedBabelCoreAddress);

  const [, deployedPriceFeedAddress] = await deployContract(
    factories.PriceFeed,
    "PriceFeed",
    babelCoreAddress,
    mockAaggregatorAddress
  );
  assertEq(priceFeedAddress, deployedPriceFeedAddress);

  const [, interimAdminAddress] = await deployContract(factories.InterimAdmin, "InterimAdmin", babelCoreAddress);

  {
    const tx = await (babelCore as BabelCore).commitTransferOwnership(interimAdminAddress);
    await tx.wait();
    console.log("-- tx: Ownership transferred to interimAdmin!");
  }

  const [, gasPoolAddress] = await deployContract(factories.GasPool, "GasPool");

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

  const sortedTrovesAddress = ethers.getCreateAddress({
    from: owner.address,
    nonce: deployerNonce + 6,
  });

  const tokenLockerAddress = ethers.getCreateAddress({
    from: owner.address,
    nonce: deployerNonce + 7,
  });

  const incentiveVotingAddress = ethers.getCreateAddress({
    from: owner.address,
    nonce: deployerNonce + 8,
  });

  const babelTokenAddress = ethers.getCreateAddress({
    from: owner.address,
    nonce: deployerNonce + 9,
  });

  const babelVaultAddress = ethers.getCreateAddress({
    from: owner.address,
    nonce: deployerNonce + 10,
  });

  const [, deployedFactoryAddress] = await deployContract(
    factories.Factory,
    "Factory",
    babelCoreAddress,
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
    babelCoreAddress,
    LZ_ENDPOINT,
    factoryAddress,
    gasPoolAddress,
    GAS_COMPENSATION
  );
  assertEq(debtTokenAddress, deployedDebtTokenAddress);

  const [, deployedBorrowerOperationsAddress] = await deployContract(
    factories.BorrowerOperations,
    "BorrowerOperations",
    babelCoreAddress,
    debtTokenAddress,
    factoryAddress,
    MIN_NET_DEBT,
    GAS_COMPENSATION
  );
  assertEq(borrowerOperationsAddress, deployedBorrowerOperationsAddress);

  const [, deployedStabilityPoolAddress] = await deployContract(
    factories.StabilityPool,
    "StabilityPool",
    babelCoreAddress,
    debtTokenAddress,
    babelVaultAddress,
    factoryAddress,
    liqudiationManagerAddress
  );
  assertEq(stabilityPoolAddress, deployedStabilityPoolAddress);

  const [, deployedTroveManagerAddress] = await deployContract(
    factories.TroveManager,
    "TroveManager",
    babelCoreAddress,
    gasPoolAddress,
    debtTokenAddress,
    borrowerOperationsAddress,
    babelVaultAddress,
    liqudiationManagerAddress,
    GAS_COMPENSATION
  );
  assertEq(troveManagerAddress, deployedTroveManagerAddress);

  const [, deployedSortedTrovesAddress] = await deployContract(factories.SortedTroves, "SortedTroves");
  assertEq(sortedTrovesAddress, deployedSortedTrovesAddress);

  const [, deployedTokenLockerAddress] = await deployContract(
    factories.TokenLocker,
    "TokenLocker",
    babelCoreAddress,
    babelTokenAddress,
    incentiveVotingAddress,
    TOKEN_LOCKER_DEPLOYMENT_MANAGER, // Change this with gnosis safe for real deployment...
    LOCK_TO_TOKEN_RATIO
  );
  assertEq(tokenLockerAddress, deployedTokenLockerAddress);

  const [, deployedIncentiveVotingAddress] = await deployContract(
    factories.IncentiveVoting,
    "IncentiveVoting",
    babelCoreAddress,
    tokenLockerAddress,
    babelVaultAddress
  );
  assertEq(incentiveVotingAddress, deployedIncentiveVotingAddress);

  const [, deployedBabelTokenAddress] = await deployContract(
    factories.BabelToken,
    "BabelToken",
    babelVaultAddress,
    LZ_ENDPOINT,
    tokenLockerAddress
  );
  assertEq(babelTokenAddress, deployedBabelTokenAddress);

  const [, deployedBabelVaultAddress] = await deployContract(
    factories.BabelVault,
    "BabelVault",
    babelCoreAddress,
    babelTokenAddress,
    tokenLockerAddress,
    incentiveVotingAddress,
    stabilityPoolAddress,
    BABEL_VAULT_DEPLOYMENT_MANAGER
  );
  assertEq(babelVaultAddress, deployedBabelVaultAddress);
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
  BabelCore: await ethers.getContractFactory("BabelCore"),
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
  BabelToken: await ethers.getContractFactory("BabelToken"),
  BabelVault: await ethers.getContractFactory("BabelVault"),
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
