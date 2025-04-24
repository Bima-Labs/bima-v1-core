/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
const { ethers } = require("hardhat");

const DEBT_TOKEN_NAME = "US Bitcoin Dollar";
const DEBT_TOKEN_SYMBOL = "USBD";
const GAS_COMPENSATION = ethers.parseUnits("200", 18);
const LZ_ENDPOINT = ethers.ZeroAddress;
const LZ_DELEGATE_ADDRESS = "0xaCA5d659364636284041b8D3ACAD8a57f6E7B8A5";

async function main(hre) {
    try {
        await hre.midl.initialize();
        const [owner] = await ethers.getSigners();
        const deployerNonce = await ethers.provider.getTransactionCount(owner.address);

        // Hardcode addresses
        const bimaCoreAddress = "0x8fdE16d9d1A87Dfb699a493Fa45451d63a3E722D";
        const factoryAddress = "0x16C05D5BbD83613Fb89c05fDc71975C965c978Fd";
        const gasPoolAddress = "0x3D8ac11452B97C52266ea79D611b02Ea0E226CD0";
        const borrowerOperationsAddress = "0x5e91C25C94C76bEAe13AC08560e3ce7a0CcaA1BC";
        const stabilityPoolAddress = "0xE2984407d457433F1F472B44dA4b49cA8142f546";

        // Deploy DebtToken
        await hre.midl.deploy("DebtToken", {
            args: [
                DEBT_TOKEN_NAME,
                DEBT_TOKEN_SYMBOL,
                stabilityPoolAddress,
                borrowerOperationsAddress,
                bimaCoreAddress,
                LZ_ENDPOINT,
                factoryAddress,
                gasPoolAddress,
                GAS_COMPENSATION,
                LZ_DELEGATE_ADDRESS,
            ],
        });

        await hre.midl.execute({ skipEstimateGasMulti: true });
    } catch (error) {
        console.error("Error initializing MIDL:", error);
        return;
    }
}

main(hre)
    .then(() => {})
    .catch((error) => {
        console.error("Error executing deployment script:", error);
    })
    .finally(() => {
        process.exit(0);
    });
