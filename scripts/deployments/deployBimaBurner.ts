import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {
    const f = await ethers.getContractFactory("BimaBurner");

    const c = await f.deploy();
    await c.waitForDeployment();

    const address = await c.getAddress();

    console.log("BimaBurner deployed!: ", address);
    
    /**
     * Verify the contract
     */
    await new Promise(resolve => setTimeout(resolve, 10000));
    await hre.run("verify:verify", {
    address: address,
    contract: "contracts/BimaBurner.sol:BimaBurner",
  });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
