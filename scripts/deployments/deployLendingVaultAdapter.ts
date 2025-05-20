import { ethers } from "hardhat";
import hre from "hardhat";

const BIMA_CORE_ADDRESS = "0x6E01276499Aea83401e7EcA30AAfCa110684c899";
const DEBT_TOKEN_ADDRESS = "0x141A7d7410de9f8Ac2314616fBdBfC78D6a619D5";
const VAULT_ADDRESS = "0xb7671483F19e1d87fDAdA7760C384dB3D360c29e";

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
    
    await new Promise(resolve => setTimeout(resolve, 10000));
    
    await hre.run("verify:verify", {
    address: lendingVaultAdapterAddress,
    contract: "contracts/adapters/LendingVaultAdapter.sol:LendingVaultAdapter",
    constructorArguments: [BIMA_CORE_ADDRESS, DEBT_TOKEN_ADDRESS, VAULT_ADDRESS],
  });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
