import { ethers } from "hardhat";

const BIMA_CORE_ADDRESS = "";
const DEBT_TOKEN_ADDRESS = "";
const VAULT_ADDRESS = "";

async function main() {
    const lendingVaultAdapterFactory = await ethers.getContractFactory("LendingVaultAdapter");

    const lendingVaultAdapter = await lendingVaultAdapterFactory.deploy(
        BIMA_CORE_ADDRESS,
        DEBT_TOKEN_ADDRESS,
        VAULT_ADDRESS
    );

    await lendingVaultAdapter.waitForDeployment();

    const lendingVaultAdapterAddress = await lendingVaultAdapter.getAddress();

    console.log("LendingVaultAdapter deployed!: ", lendingVaultAdapterAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
