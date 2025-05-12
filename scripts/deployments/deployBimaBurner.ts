import { ethers } from "hardhat";

async function main() {
    const f = await ethers.getContractFactory("BimaBurner");

    const c = await f.deploy();
    await c.waitForDeployment();

    const address = await c.getAddress();

    console.log("BimaBurner deployed!: ", address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
