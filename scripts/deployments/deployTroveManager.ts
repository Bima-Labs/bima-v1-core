import { ethers } from "hardhat";

const ZERO_ADDRESS = ethers.ZeroAddress;

// FILL IN WITH YOUR TARGET ADDRESSES
// const COLLATERAL_ADDRESS = "";
const FACTORY_ADDRESS = "0x1C8d37EdA77132E851d41c93c77f1cbE8BFa3F87";
const PRICEFEED_ADDRESS = "0xaa7Feffe3a3edFd4e9D016e897A21693099F8b8d";
const BABELVAULT_ADDRESS = "0x2C80b4985924803Df71ff81D2159cEF516052669";

// Comment/Uncomment respective oracle deployments, based on the oracle we use
// const ORACLE_ADDRESS = ""; // If we use existing AggregatorV3Interface onchain oracle
const STORK_ORACLE_ADDRESS = "0xacC0a0cF13571d30B4b8637996F5D6D774d4fd62"; // If we use Stork oracle
const ENCODED_ASSET_ID = "0x7404e3d104ea7841c3d9e6fd20adfe99b4ad586bc08d8f3bd3afef894cf184de"; // If we use Stork oracle

async function main() {
  const priceFeed = await ethers.getContractAt("PriceFeed", PRICEFEED_ADDRESS);
  const factory = await ethers.getContractAt("Factory", FACTORY_ADDRESS);
  const babelVault = await ethers.getContractAt("BabelVault", BABELVAULT_ADDRESS);

  //? NOT NECESSARY IF WE USE A COLLATERAL TOKEN
  const mockedStBtcAddress = await deployMockCollateral();

  //! DO NOT USE MOCK ORACLE IF YOU ARE NOT DEPLOYING ON THE LOCAL NETWORK
  // const mockOracleAddress = await deployMockOracle();

  //! USE IF WE USE STORK ORACLE FOR THIS TROVE MANAGER
  const storkOracleWrapperAddress = await deployStorkOracleWrapper();

  console.log("troveManagerCount before: ", await factory.troveManagerCount());

  {
    const tx = await priceFeed.setOracle(
      mockedStBtcAddress,
      storkOracleWrapperAddress,
      BigInt("80000"),
      "0x00000000",
      BigInt("18"),
      false
    );
    await tx.wait();
    console.log("Oracle is set on PriceFeed contract!");
  }

  // For some reason, if we don't wait for some time, the next transaction will revert
  await new Promise((res) => setTimeout(res, 10000));

  {
    const tx = await factory.deployNewInstance(mockedStBtcAddress, PRICEFEED_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, {
      minuteDecayFactor: BigInt("999037758833783000"),
      redemptionFeeFloor: BigInt("5000000000000000"),
      maxRedemptionFee: BigInt("1000000000000000000"),
      borrowingFeeFloor: BigInt("0"),
      maxBorrowingFee: BigInt("0"),
      interestRateInBps: BigInt("0"),
      maxDebt: ethers.parseEther("1000000"),
      MCR: ethers.parseUnits("2", 18),
    });
    await tx.wait();
    console.log("New Trove Manager is deployed from Factory contract!");
  }

  const troveManagerCount = await factory.troveManagerCount();
  console.log("troveManagerCount after: ", troveManagerCount.toString());

  const troveManagerAddressFromFactory = await factory.troveManagers(BigInt(String(Number(troveManagerCount) - 1)));

  {
    const tx = await babelVault.registerReceiver(troveManagerAddressFromFactory, BigInt("2"));
    await tx.wait();
    console.log("Reciever has been registered!");
  }

  console.log("new Trove Manager address: ", troveManagerAddressFromFactory);
}

const deployMockCollateral = async () => {
  const mockedStBtcFactory = await ethers.getContractFactory("StakedBTC");
  const mockedStBtc = await mockedStBtcFactory.deploy();
  await mockedStBtc.waitForDeployment();
  const mockedStBtcAddress = await mockedStBtc.getAddress();
  console.log("MOCKED stBTC deployed!: ", mockedStBtcAddress);
  return mockedStBtcAddress;
};

const deployMockOracle = async () => {
  const mockOracleFactory = await ethers.getContractFactory("MockOracle");
  const mockOracle = await mockOracleFactory.deploy();
  await mockOracle.waitForDeployment();
  const mockOracleAddress = await mockOracle.getAddress();
  console.log("MockOracle deployed!: ", mockOracleAddress);
  return mockOracleAddress;
};

const deployStorkOracleWrapper = async () => {
  const storkOracleWrapperFactory = await ethers.getContractFactory("StorkOracleWrapper");
  const storkOracleWrapper = await storkOracleWrapperFactory.deploy(STORK_ORACLE_ADDRESS, ENCODED_ASSET_ID);
  await storkOracleWrapper.waitForDeployment();
  const storkOracleWrapperAddress = await storkOracleWrapper.getAddress();
  console.log("StorkOracleWrapper deployed!: ", storkOracleWrapperAddress);
  return storkOracleWrapperAddress;
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
