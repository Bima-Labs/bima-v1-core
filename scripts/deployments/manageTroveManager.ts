import { ethers } from "hardhat";

async function main() {
  const troveManagerAddress = "0x34fe901e61C87B1B221560BE45F4AB53303Dcc0e";
  const troveManager = await ethers.getContractAt(
    "TroveManager",
    troveManagerAddress
  );

  console.log("DebtToken: ", await troveManager.debtToken());
  console.log("CollateralToken: ", await troveManager.collateralToken());
  console.log("PriceFeed: ", await troveManager.priceFeed());
  console.log("MCR: ", await troveManager.MCR());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
