import { getUint } from "ethers";
import { ethers } from "hardhat";

async function main() {
  const COLLETRAL_TOKEN_ADDRESS = ""; // Add the address of the bmBTC contract
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const FaucetDeployer = await ethers.getContractFactory("BimaFaucet");
  const faucet = await FaucetDeployer.deploy();

  await faucet.waitForDeployment();

  console.log("BimaFaucet contract deployed to:", await faucet.getAddress());
  console.log("trasfering 10000 bmBTC to faucet contract...");

  const collateralToken = await ethers.getContractAt("StakedBTC", COLLETRAL_TOKEN_ADDRESS);
  await collateralToken.transfer(faucet.getAddress(), ethers.parseEther("10000"));
  console.log("10000 bmBTC transfered to faucet contract ");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
