import { ethers } from "hardhat";

//npx hardhat run scripts/deployer.ts --network lorenzo_testnet

const ZERO_ADDRESS = ethers.ZeroAddress;

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}


async function main() {
  const [owner, otherAccount] = await ethers.getSigners();

  const ERC20Deployer = await ethers.getContractFactory("StakedBTC");

  const MockAggregatorDeployer = await ethers.getContractFactory("MockOracle");
  const BabelCoreDeployer = await ethers.getContractFactory("BabelCore");

  const PriceFeedDeployer = await ethers.getContractFactory("PriceFeed");
  const FeeReceiverDeployer = await ethers.getContractFactory("FeeReceiver");
  const InterimAdminDeployer = await ethers.getContractFactory("InterimAdmin");

  const GasPoolDeployer = await ethers.getContractFactory("GasPool");
  const FactoryDeployer = await ethers.getContractFactory("Factory");

  const LiqudiationManagerDeployer = await ethers.getContractFactory(
    "LiquidationManager"
  );
  const BorrowerOperationsDeployer = await ethers.getContractFactory(
    "BorrowerOperations"
  );
  const DebtTokenDeployer = await ethers.getContractFactory("DebtToken");

  const StabilityPoolDeployer = await ethers.getContractFactory(
    "StabilityPool"
  );
  const TroveManagerDeployer = await ethers.getContractFactory("TroveManager");

  const SortedTrovesDeployer = await ethers.getContractFactory("SortedTroves");

  const TokenLockerDeployer = await ethers.getContractFactory("TokenLocker");

  const IncentiveVotingDeployer = await ethers.getContractFactory(
    "IncentiveVoting"
  );

  const BabelTokenDeployer = await ethers.getContractFactory("BabelToken");

  const BabelVaultDeployer = await ethers.getContractFactory("BabelVault");

  const stBTC = await ERC20Deployer.deploy();

  const stBTCAddress = await stBTC.getAddress();

  console.log("stBTCAddress deployed!: ", stBTCAddress);
  await sleep(10000);
  const mockAaggregator = await MockAggregatorDeployer.deploy();
  const mockAaggregatorAddress = await mockAaggregator.getAddress();
  console.log("MockAggregatorAddress deployed!: ", mockAaggregatorAddress);
  await sleep(10000);
  let deployerNonce = await ethers.provider.getTransactionCount(owner.address);

  // Disgusting hack to get the addresses of the contracts before deployment
  const babelCoreAddress = ethers.getCreateAddress({
    from: owner.address,
    nonce: deployerNonce,
  });
  console.log("BabelCoreAddress deployed!: ", babelCoreAddress);
  

  const priceFeedAddress = ethers.getCreateAddress({
    from: owner.address,
    nonce: deployerNonce + 1,
  });
  console.log("PriceFeedAddress deployed!: ", priceFeedAddress);
  
  const babelCore = await BabelCoreDeployer.deploy(
    owner.address,
    owner.address,
    priceFeedAddress,
    owner.address
  );
  await sleep(10000);
  console.log("BabelCore deployed!: ", babelCoreAddress);

  const priceFeed = await PriceFeedDeployer.deploy(
    babelCoreAddress,
    mockAaggregatorAddress
  );

  console.log("PriceFeed deployed!: ", priceFeedAddress);


  const feeReceiver = await FeeReceiverDeployer.deploy(babelCoreAddress);
  await sleep(10000);
  console.log("FeeReceiver deployed!: ", await feeReceiver.getAddress());


  const interimAdmin = await InterimAdminDeployer.deploy(babelCoreAddress);
  await sleep(10000);
  console.log("InterimAdmin deployed!: ", await interimAdmin.getAddress());

  await babelCore.commitTransferOwnership(await interimAdmin.getAddress());

  console.log("Ownership transferred to interimAdmin!");

  await babelCore.commitTransferOwnership(await interimAdmin.getAddress());

  const gasPool = await GasPoolDeployer.deploy();

  await sleep(10000);

  console.log("Gas Pool deployed!: ", await gasPool.getAddress());

  const gasPoolAddress = await gasPool.getAddress();

  deployerNonce = await ethers.provider.getTransactionCount(owner.address);

  // // Disgusting hack to get the addresses of the contracts before deployment
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

  // // This crates TroveManagers
  const factory = await FactoryDeployer.deploy(
    babelCoreAddress,
    debtTokenAddress,
    stabilityPoolAddress,
    borrowerOperationsAddress,
    sortedTrovesAddress,
    troveManagerAddress,
    liqudiationManagerAddress
  );
  console.log("Factory deployed!: ", factoryAddress);
  await sleep(10000);
  const liqudiationManager = await LiqudiationManagerDeployer.deploy(
    stabilityPoolAddress,
    borrowerOperationsAddress,
    factoryAddress,
    BigInt("200000000000000000000") // gas compensation
  );

  console.log("LiquidationManager deployed!: ", liqudiationManagerAddress);
  await sleep(10000);
  const debtToken = await DebtTokenDeployer.deploy(
    "USDB", //mkUSD or ULTRA name
    "USDB", // symbol
    stabilityPoolAddress,
    borrowerOperationsAddress,
    babelCoreAddress,
    // lzApp endpoint address
    // We currently don't have this address. If we can deploy LzApp as example we can later use this
    ZERO_ADDRESS,
    factoryAddress,
    gasPoolAddress,
    BigInt("200000000000000000000") // gas compensation
  );

  console.log("DebtToken deployed!: ", debtTokenAddress);
  await sleep(10000);
  const borrowerOperations = await BorrowerOperationsDeployer.deploy(
    babelCoreAddress,
    debtTokenAddress,
    factoryAddress,
    BigInt("1800000000000000000000"), // 1800 USDB
    BigInt("200000000000000000000")
  );

  console.log("BorrowerOperations deployed!: ", borrowerOperationsAddress);
  await sleep(10000);
  const stabilityPool = await StabilityPoolDeployer.deploy(
    babelCoreAddress,
    debtTokenAddress,
    babelVaultAddress,
    factoryAddress,
    liqudiationManagerAddress
  );

  console.log("StabilityPool deployed!: ", stabilityPoolAddress);
  await sleep(10000);
  const troveManager = await TroveManagerDeployer.deploy(
    babelCoreAddress,
    gasPoolAddress,
    debtTokenAddress,
    borrowerOperationsAddress,
    babelVaultAddress,
    liqudiationManagerAddress,
    BigInt("200000000000000000000")
  );

  console.log("TroveManager deployed!: ", troveManagerAddress);
  await sleep(10000);
  const sortedTroves = await SortedTrovesDeployer.deploy();
  await sleep(10000);
  console.log("SortedTroves deployed!: ", sortedTrovesAddress);

  const tokenLocker = await TokenLockerDeployer.deploy(
    babelCoreAddress,
    babelTokenAddress,
    incentiveVotingAddress,
    owner.address, // Change this with gnosis safe for real deployment...
    BigInt("1000000000000000000") // 1 BABEL
  );
  console.log("TokenLocker deployed!: ", tokenLockerAddress);
  await sleep(10000);

  const incentiveVoting = await IncentiveVotingDeployer.deploy(
    babelCoreAddress,
    tokenLockerAddress,
    babelVaultAddress
  );
  console.log("IncentiveVoting deployed!: ", incentiveVotingAddress);
  await sleep(10000);
  const babelToken = await BabelTokenDeployer.deploy(
    babelVaultAddress,
    // lzApp endpoint address
    // We currently don't have this address. If we can deploy LzApp as example we can later use this
    ZERO_ADDRESS,
    tokenLockerAddress
  );

  console.log("BabelToken deployed!: ", babelTokenAddress);
  await sleep(10000);
  const babelVault = await BabelVaultDeployer.deploy(
    babelCoreAddress,
    babelTokenAddress,
    tokenLockerAddress,
    incentiveVotingAddress,
    stabilityPoolAddress,
    liqudiationManagerAddress
  );

  console.log("BabelVault deployed!: ", babelVaultAddress);
  await sleep(10000);
  await priceFeed.setOracle(
    stBTCAddress,
    await mockAaggregator.getAddress(),
    BigInt("80000"), // seconds
    // We can add function data to convert prices if needed
    // The protocol uses this function to calculate wrapped values of tokens
    // For example if stETH is worth 1.0 ETH and wstETH is worth 0.8 ETH
    // We can call convert 1 wstETH to stETH function on wstETH contract
    // With this info we can calculate value of derivatives in different protocols
    // wstETH is not part of Babel Finance so they use this to get specific prices of other protocols
    // It only allows bytes4 function signatures
    // For more info read https://github.com/ethers-io/ethers.js/issues/44
    "0x00000000", // Read pure data assume stBTC is 1:1 with BTC :)
    BigInt("18"),
    false // Is it equivalent to ETH or default coin of the chain. On polygon if you set this to true it'll work with matic.
  );
  console.log("PriceFeed setOracle!");
  await sleep(10000);
  await factory.deployNewInstance(
    stBTCAddress,
    priceFeedAddress,
    ZERO_ADDRESS,
    ZERO_ADDRESS,
    {
      minuteDecayFactor: BigInt("999037758833783000"),
      redemptionFeeFloor: BigInt("5000000000000000"),
      maxRedemptionFee: BigInt("1000000000000000000"),
      borrowingFeeFloor: BigInt("0"),
      maxBorrowingFee: BigInt("0"),
      interestRateInBps: BigInt("0"),
      maxDebt: ethers.parseEther("1000000"), // 1M USD
      MCR: ethers.parseUnits("2", 18), // 2e18 = 200%
    }
  );
  console.log("Factory deployNewInstance!");
  await sleep(10000);

  const troveManagerCount = await factory.troveManagerCount();
  const troveManagerAddressFromFactory = await factory.troveManagers(
    BigInt("0")
  );

  await babelVault.registerReceiver(
    troveManagerAddressFromFactory,
    BigInt("2")
  );

  await sleep(10000);
  console.log("stBTC Trove Manager address: ", troveManagerAddressFromFactory);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
