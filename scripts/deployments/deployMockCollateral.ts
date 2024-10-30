import { ethers } from "hardhat";

async function main() {
  const mockedStBtcFactory = await ethers.getContractFactory("StakedBTC");

  const mockedStBtc = await mockedStBtcFactory.deploy();
  await mockedStBtc.waitForDeployment();

  const mockedStBtcAddress = await mockedStBtc.getAddress();

  console.log("MOCKED stBTC deployed!: ", mockedStBtcAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
