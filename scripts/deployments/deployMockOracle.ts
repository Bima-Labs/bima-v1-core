import { ethers } from "hardhat";

async function main() {
  const mockOracleFactory = await ethers.getContractFactory("MockOracle");

  const mockOracle = await mockOracleFactory.deploy();
  await mockOracle.waitForDeployment();

  const mockOracleAddress = await mockOracle.getAddress();

  console.log("MockOracle deployed!: ", mockOracleAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
