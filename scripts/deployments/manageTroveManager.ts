import { parseUnits } from "ethers";
import { ethers } from "hardhat";

const ZERO_ADDRESS = ethers.ZeroAddress;

const TROVEMANAGER_ADDRESS = "0x6a0B26AbfC8eAE9D737537e534F9d2c9eb0C4944";
const BORROWEROPERATIONS_ADDRESS = "0x0169148d7e9F7c415f4a3565383c803093A4C36A";

async function main() {
  const [owner] = await ethers.getSigners();

  const {
    troveManager,
    borrowerOperations,
    debtToken,
    collateralToken,
    priceFeed,
  } = await getContracts();

  console.log("TroveManager DT: ", await troveManager.debtToken());
  // console.log("CollateralToken: ", await troveManager.collateralToken());
  // console.log("PriceFeed: ", await troveManager.priceFeed());
  // console.log("MCR: ", await troveManager.MCR());

  // console.log("BorrowerOperations DT: ", await borrowerOperations.debtToken());

  // {
  //   const tx = await borrowerOperations.getTCR();
  //   await tx.wait();
  //   console.log("TCR: ", tx.value);
  // }

  // console.log(
  //   "Entire System Collateral: ",
  //   await troveManager.getEntireSystemColl()
  // );
  // console.log("Entire System Debt: ", await troveManager.getEntireSystemDebt());
  // console.log("Debt Token Total Supply: ", await debtToken.totalSupply());

  // console.log(
  //   "my troves nominal ICR: ",
  //   await troveManager.getNominalICR(owner.address)
  // );
  // console.log(
  //   "my troves current ICR: ",
  //   await troveManager.getCurrentICR(
  //     owner.address,
  //     ethers.parseUnits("60000", 8)
  //   )
  // );

  // console.log(
  //   "My stBTC balance: ",
  //   await collateralToken.balanceOf(owner.address)
  // );

  // {
  //   const tx = await priceFeed.fetchPrice(collateralTokenAddress);
  //   await tx.wait();
  //   console.log("stBTC price: ", tx.value);
  // }

  // {
  //   const tx = await troveManager.getEntireSystemBalances();
  //   await tx.wait();
  //   console.log(tx.);
  // }

  // {
  //   console.log("APPROVING COLLATERAL TOKENS to BORROW OPERATIONS..");
  //   const tx2 = await collateralToken.approve(
  //     BORROWEROPERATIONS_ADDRESS,
  //     parseUnits("1", 18)
  //   );
  //   await tx2.wait();
  //   console.log("COLLATERAL TOKENS APPROVED!");
  // }
  // // Open Trove
  // {
  //   console.log("OPENING A TROVE..");
  //   const tx = await borrowerOperations.openTrove(
  //     TROVEMANAGER_ADDRESS,
  //     owner.address,
  //     parseUnits("1", 18),
  //     parseUnits("1", 18),
  //     parseUnits("44500", 18),
  //     ZERO_ADDRESS,
  //     ZERO_ADDRESS
  //   );
  //   await tx.wait();
  //   console.log("TROVE OPENED!");
  // }
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

const getContracts = async () => {
  const troveManager = await ethers.getContractAt(
    "TroveManager",
    TROVEMANAGER_ADDRESS
  );
  const borrowerOperations = await ethers.getContractAt(
    "BorrowerOperations",
    BORROWEROPERATIONS_ADDRESS
  );
  const debtToken = await ethers.getContractAt(
    "DebtToken",
    await troveManager.debtToken()
  );
  const collateralTokenAddress = await troveManager.collateralToken();
  const collateralToken = await ethers.getContractAt(
    "StakedBTC",
    collateralTokenAddress
  );
  const priceFeed = await ethers.getContractAt(
    "PriceFeed",
    await troveManager.priceFeed()
  );
  return {
    troveManager,
    borrowerOperations,
    debtToken,
    collateralToken,
    priceFeed,
  };
};
