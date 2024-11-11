import { ethers } from "hardhat";

const GAS_COMPENSATION = ethers.parseUnits("200", 18); //! 200 USBD
const FACTORY_ADDRESS = ""; //! IMPORTANT
const BORROWEROPERATIONS_ADDRESS = ""; //! IMPORTANT

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const MultiCollateralHintHelpersFactory = await ethers.getContractFactory("MultiCollateralHintHelpers");
    const MultiTroveGetterFactory = await ethers.getContractFactory("MultiTroveGetter");
    const TroveManagerGettersFactory = await ethers.getContractFactory("TroveManagerGetters");

    const multiCollateralHintHelpers = await MultiCollateralHintHelpersFactory.deploy(
        BORROWEROPERATIONS_ADDRESS,
        GAS_COMPENSATION
    );

    await multiCollateralHintHelpers.waitForDeployment();

    console.log("multiCollateralHintHelpers contract deployed to:", await multiCollateralHintHelpers.getAddress());

    const multiTroveGetter = await MultiTroveGetterFactory.deploy();

    await multiTroveGetter.waitForDeployment();

    console.log("multiTroveGetter contract deployed to:", await multiTroveGetter.getAddress());

    const troveManagerGetters = await TroveManagerGettersFactory.deploy(FACTORY_ADDRESS);

    await troveManagerGetters.waitForDeployment();

    console.log("troveManagerGetters contract deployed to:", await troveManagerGetters.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
