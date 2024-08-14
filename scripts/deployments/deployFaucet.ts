import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const FaucetDeployer = await ethers.getContractFactory("BimaFaucet");
  const faucet = await FaucetDeployer.deploy();

  await faucet.waitForDeployment();

  console.log("BimaFaucet contract deployed to:", await faucet.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
