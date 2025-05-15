import { ethers } from "hardhat";

const BIMA_CORE = "0x227E9323D692578Ca3dF92b87d06625Df22380Ab";
const USBD = "0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c";
const UNDERLYING = "0x6c3ea9036406852006290770BEdFcAbA0e23A0e8";

async function main() {
    const f = await ethers.getContractFactory("BimaPSM");

    const c = await f.deploy(BIMA_CORE, USBD, UNDERLYING);

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
