import { ethers } from "hardhat";

const ZERO_ADDRESS = ethers.ZeroAddress;

// FILL IN WITH YOUR TARGET ADDRESSES
const COLLATERAL_ADDRESS = "";
const FACTORY_ADDRESS = "";
const PRICEFEED_ADDRESS = "";
const BABELVAULT_ADDRESS = "";
const ORACLE_ADDRESS = "";

async function main() {
  const priceFeed = await ethers.getContractAt("PriceFeed", PRICEFEED_ADDRESS);
  const factory = await ethers.getContractAt("Factory", FACTORY_ADDRESS);
  const babelVault = await ethers.getContractAt("BabelVault", BABELVAULT_ADDRESS);

  //? NOT NECESSARY IF WE USE A COLLATERAL TOKEN
  // const mockedStBtcAddress = await deployMockCollateral();

  //! DO NOT USE MOCK ORACLE IF YOU ARE NOT DEPLOYING ON THE LOCAL NETWORK
  // const mockOracleAddress = await deployMockOracle();

  console.log("troveManagerCount before: ", await factory.troveManagerCount());

  {
    const tx = await priceFeed.setOracle(
      COLLATERAL_ADDRESS,
      ORACLE_ADDRESS,
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
    const tx = await factory.deployNewInstance(COLLATERAL_ADDRESS, PRICEFEED_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, {
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

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
