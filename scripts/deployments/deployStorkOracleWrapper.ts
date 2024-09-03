import { ethers } from "hardhat";

const STORK_CONTRACT_ADDRESS = ""; // address for Stork contract
const ENCODED_ASSET_ID = "0x7404e3d104ea7841c3d9e6fd20adfe99b4ad586bc08d8f3bd3afef894cf184de"; // id for BTCUSD

async function main() {
  const storkOracleWrapperFactory = await ethers.getContractFactory("StorkOracleWrapper");

  const storkOracleWrapper = await storkOracleWrapperFactory.deploy(STORK_CONTRACT_ADDRESS, ENCODED_ASSET_ID);

  await storkOracleWrapper.waitForDeployment();

  const storkOracleWrapperAddress = await storkOracleWrapper.getAddress();

  console.log("StorkOracleWrapper deployed!: ", storkOracleWrapperAddress);

  const latestRoundData = await storkOracleWrapper.latestRoundData();

  console.log("roundId: ", String(latestRoundData.roundId));
  console.log("answer: ", String(latestRoundData.answer));
  console.log("updatedAt: ", String(latestRoundData.updatedAt));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
