import { BaseContract, ContractFactory } from "ethers";
import { ethers } from "hardhat";
import { BabelCore } from "../../typechain-types";

const ZERO_ADDRESS = ethers.ZeroAddress;

async function deployCore() {
  const [owner] = await ethers.getSigners();

  const factories = await getFactories();

  const [, mockAaggregatorAddress] = await deployContract(factories.MockAggregator, "MockAggregator");

  let deployerNonce = await ethers.provider.getTransactionCount(owner.address);

  // Disgusting hack to get the addresses of the contracts before deployment
  const babelCoreAddress = ethers.getCreateAddress({
    from: owner.address,
    nonce: deployerNonce,
  });

  const priceFeedAddress = ethers.getCreateAddress({
    from: owner.address,
    nonce: deployerNonce + 1,
  });

  const [babelCore] = await deployContract(
    factories.BabelCore,
    "BabelCore",
    owner.address,
    owner.address,
    priceFeedAddress,
    owner.address
  );

  await deployContract(factories.PriceFeed, "PriceFeed", babelCoreAddress, mockAaggregatorAddress);

  await deployContract(factories.FeeReceiver, "FeeReceiver", babelCoreAddress);

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

  await deployContract(
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

  await deployContract(
    factories.LiquidationManager,
    "LiquidationManager",
    stabilityPoolAddress,
    borrowerOperationsAddress,
    factoryAddress,
    ethers.parseUnits("200", 18) // BigInt("200000000000000000000") gas compensation
  );

  await deployContract(
    factories.DebtToken,
    "DebtToken",
    "US Bitcoin Dollar", //mkUSD or ULTRA name
    "USBD", // symbol
    stabilityPoolAddress,
    borrowerOperationsAddress,
    babelCoreAddress,
    // lzApp endpoint address
    // We currently don't have this address. If we can deploy LzApp as example we can later use this
    ZERO_ADDRESS,
    factoryAddress,
    gasPoolAddress,
    ethers.parseUnits("200", 18) // BigInt("200000000000000000000") // gas compensation
  );

  await deployContract(
    factories.BorrowerOperations,
    "BorrowerOperations",
    babelCoreAddress,
    debtTokenAddress,
    factoryAddress,
    ethers.parseUnits("1800", 18), // BigInt("1800 000000000000000000"), // 1800 USDB
    ethers.parseUnits("200", 18) // BigInt("200000000000000000000")
  );

  await deployContract(
    factories.StabilityPool,
    "StabilityPool",
    babelCoreAddress,
    debtTokenAddress,
    babelVaultAddress,
    factoryAddress,
    liqudiationManagerAddress
  );

  await deployContract(
    factories.TroveManager,
    "TroveManager",
    babelCoreAddress,
    gasPoolAddress,
    debtTokenAddress,
    borrowerOperationsAddress,
    babelVaultAddress,
    liqudiationManagerAddress,
    ethers.parseUnits("200", 18) // BigInt("200000000000000000000")
  );

  await deployContract(factories.SortedTroves, "SortedTroves");

  await deployContract(
    factories.TokenLocker,
    "TokenLocker",
    babelCoreAddress,
    babelTokenAddress,
    incentiveVotingAddress,
    owner.address, // Change this with gnosis safe for real deployment...
    ethers.parseUnits("1", 18) // BigInt("1000000000000000000") // 1 BABEL
  );

  await deployContract(
    factories.IncentiveVoting,
    "IncentiveVoting",
    babelCoreAddress,
    tokenLockerAddress,
    babelVaultAddress
  );

  await deployContract(
    factories.BabelToken,
    "BabelToken",
    babelVaultAddress,
    // lzApp endpoint address
    // We currently don't have this address. If we can deploy LzApp as example we can later use this
    ZERO_ADDRESS,
    tokenLockerAddress
  );

  await deployContract(
    factories.BabelVault,
    "BabelVault",
    babelCoreAddress,
    babelTokenAddress,
    tokenLockerAddress,
    incentiveVotingAddress,
    stabilityPoolAddress,
    liqudiationManagerAddress
  );
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
