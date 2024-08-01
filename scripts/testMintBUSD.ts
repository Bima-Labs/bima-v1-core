import { ethers } from "hardhat";
import { mintBUSD } from "./mintBUSD";

//npx hardhat run scripts/deployer.ts --network lorenzo_testnet

const ZERO_ADDRESS = ethers.ZeroAddress;

async function main() {
  const [owner, user0, user1] = await ethers.getSigners();

  const stBTC = await ethers.getContractAt("StakedBTC", "0x103337452FfA3bA9Ca82df11e0A545AA1a577714");

  await stBTC.transfer(user1.address, ethers.parseEther("2"));

  await stBTC.connect(user1).approve("0x2b1AFd6390034b02EDF826714fCbE96af0911852", ethers.parseEther("1000000"));

  await mintBUSD({
    borrowerOperationsAddress: "0x2b1AFd6390034b02EDF826714fCbE96af0911852",
    troveManagerAddress: "0x796B058649Ee8b72B851DE6Af4d3529019198803",
    signer: user1,
    signerAddress: await user1.getAddress(),
    amountstBTC: ethers.parseEther("1"),
    percentage: 200n,
    provider: user1.provider,
    oracleAddress: "0x6398131143791451aDfC74850379abbED284455e", // Mock Aggregator address
    collateralAddress: "0x103337452FfA3bA9Ca82df11e0A545AA1a577714", //Stake BTC address
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
