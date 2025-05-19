import { ethers } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();

    const oft = await ethers.getContractAt("DebtToken", "0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c");

    console.log("Setting delegate");

    const tx = await oft.setDelegate(deployer.address);
    await tx.wait();

    console.log("Done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
