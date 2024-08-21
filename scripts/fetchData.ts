import { Provider, Signer } from "ethers";
import { ethers } from "hardhat";

import { MockOracle__factory, PriceFeed__factory, TroveManager__factory } from "../typechain-types/index";

//import  pLimit from "p-limit";

export const fetchGeneralData = async ({
  troveManagerAddress,
  provider,
}: {
  troveManagerAddress: string;
  provider: Provider;
}) => {
  const troveManagerContract = TroveManager__factory.connect(troveManagerAddress, provider);

  try {
    const [
      totalCollateral,
      totalDebt,
      mcr,
      mintFee,
      borrowInterestRate,
      redemptionRate,
      totalStakes,
      rewardRate,
      rewardIntegral,
      totalActiveDebt,
      totalActiveCollateral,
      //currentPrice,
      maxSystemDebt,
    ] = await Promise.all([
      troveManagerContract.getEntireSystemColl(),
      troveManagerContract.getEntireSystemDebt(),
      troveManagerContract.MCR(),
      troveManagerContract.redemptionFeeFloor(),
      troveManagerContract.interestRate(),
      troveManagerContract.getRedemptionRate(),
      troveManagerContract.totalStakes(),
      troveManagerContract.rewardRate(),
      troveManagerContract.rewardIntegral(),
      troveManagerContract.getTotalActiveDebt(),
      troveManagerContract.getTotalActiveCollateral(),
      //troveManagerContract.fetchPrice(),
      troveManagerContract.maxSystemDebt(),
    ]);

    return {
      totalCollateral,
      totalDebt,
      mcr,
      mintFee,
      borrowInterestRate,
      redemptionRate,
      totalStakes,
      rewardRate,
      rewardIntegral,
      totalActiveDebt,
      totalActiveCollateral,
      //currentPrice,
      maxSystemDebt,
    };
  } catch (err) {
    console.error(err);
    return null;
  }
};

export const fetchPrice = async ({
  oracleAddress,
  collateralAddress,
  signer,
}: {
  oracleAddress: string;
  collateralAddress: string;
  signer: Signer;
}) => {
  try {
    const oracleContract = MockOracle__factory.connect(oracleAddress, signer);

    const result = await oracleContract.latestRoundData();
    return result[1];
  } catch (err) {
    console.log(err);
    return null;
  }
};

/** 
async function main() {
  const provider = await ethers.getDefaultProvider(
    "https://rpc-testnet.lorenzo-protocol.xyz"
  );
  const contractData = await fetchGeneralData({
    troveManagerAddress: "0x63B73344AA6797a2B580ae1A7556b7200FFb82F5",
    provider,
  });

  console.log(contractData);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

  */
