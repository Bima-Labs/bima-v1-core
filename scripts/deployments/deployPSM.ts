import { ethers } from "hardhat";

async function main() {
    const bimaPsmFactory = await ethers.getContractFactory("BimaPSM");

    const bimaPsm = await bimaPsmFactory.deploy(
        "0x0B446824fc53b7898DCcAE72743Ac4c1AD3c2Af7",
        "0x9a64371655872B16395342B0C7A27C16d9eaC78e",
        "0x94b96A5686dCcF7e9a351f10DAF17AE08587a928"
    );
    await bimaPsm.waitForDeployment();

    const bimaPsmAddress = await bimaPsm.getAddress();

    console.log("BimaPSM deployed!: ", bimaPsmAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
