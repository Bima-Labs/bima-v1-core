import { ethers } from "hardhat";

//npx hardhat run scripts/deployer.ts --network lorenzo_testnet

const ZERO_ADDRESS = ethers.ZeroAddress;

async function main() {
  const [owner, otherAccount] = await ethers.getSigners();

  const collateralAddress = "";
  const aggregatorAddress = "";

  const priceFeedAddress = "";
  const priceFeed = await ethers.getContractAt("PriceFeed", priceFeedAddress);

  const factoryAddress = "";
  const factory = await ethers.getContractAt("Factory", factoryAddress);

  const babelVaultAddress = "";
  const babelVault = await ethers.getContractAt(
    "BabelVault",
    babelVaultAddress
  );

  {
    const tx = await priceFeed.setOracle(
      collateralAddress,
      aggregatorAddress,
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
    await tx.wait();
    console.log("PriceFeed setOracle!");
  }

  {
    const tx = await factory.deployNewInstance(
      collateralAddress,
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
    await tx.wait();
    console.log("Factory deployNewInstance!");
  }

  const troveManagerCount = await factory.troveManagerCount();

  const troveManagerAddressFromFactory = await factory.troveManagers(
    BigInt(String(Number(troveManagerCount) - 1))
  );

  {
    const tx = await babelVault.registerReceiver(
      troveManagerAddressFromFactory,
      BigInt("2")
    );
    await tx.wait();
  }

  console.log("new Trove Manager address: ", troveManagerAddressFromFactory);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
