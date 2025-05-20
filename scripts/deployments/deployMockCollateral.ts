import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {
  const mockedStBtcFactory = await ethers.getContractFactory("StakedBTC");

  const mockedStBtc = await mockedStBtcFactory.deploy();
  await mockedStBtc.waitForDeployment();

  const mockedStBtcAddress = await mockedStBtc.getAddress();

  console.log("MOCKED stBTC deployed!: ", mockedStBtcAddress);
  
  await new Promise(resolve => setTimeout(resolve, 10000));
  
  await hre.run("verify:verify", {
    address: mockedStBtcAddress,
    contract: "contracts/mock/StakedBTC.sol:StakedBTC",
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
