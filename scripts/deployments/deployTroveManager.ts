import { ethers } from "hardhat";

// Contract Addresses
const COLLATERAL_ADDRESS = ""; //! IMPORTANT
const FACTORY_ADDRESS = ""; //! IMPORTANT
const PRICEFEED_ADDRESS = ""; //! IMPORTANT
const BIMAVAULT_ADDRESS = ""; //! IMPORTANT
const ORACLE_ADDRESS = ""; //! IMPORTANT

// PriceFeed config for the Oracle
const ORACLE_HEARBEAT = BigInt("80000"); //! IMPORTANT
const SHARE_PRICE_SIGNATURE = "0x00000000"; //! IMPORTANT
const SHARE_PRICE_DECIMALS = BigInt("18"); //! IMPORTANT
const IS_BASE_CURRENCY_ETH_INDEXED = false; //! IMPORTANT

// TroveManager config
const CUSTOM_TROVE_MANAGER_IMPL_ADDRESS = ethers.ZeroAddress; //! IMPORTANT
const CUSTOM_SORTED_TROVES_IMPL_ADDRESS = ethers.ZeroAddress; //! IMPORTANT

const MINUTE_DECAY_FACTOR = BigInt("999037758833783000"); //! IMPORTANT
const REDEMPTION_FEE_FLOOR = ethers.parseEther("0.005"); //! 0.5% IMPORTANT
const MAX_REDEMPTION_FEE = ethers.parseEther("1"); //! 100% IMPORTANT
const BORROWING_FEE_FLOOR = ethers.parseEther("0.005"); //! 0.5% IMPORTANT
const MAX_BORROWING_FEE = ethers.parseEther("0.05"); //! 5% IMPORTANT
const INTEREST_RATE_IN_BPS = BigInt("100"); //! 1% IMPORTANT
const MAX_DEBT = ethers.parseEther("1000000"); //! IMPORTANT
const MCR = ethers.parseUnits("2", 18); //! IMPORTANT

// Receiver
const REGISTERED_RECEIVER_COUNT = BigInt("2"); //! IMPORTANT

async function main() {
    const priceFeed = await ethers.getContractAt("PriceFeed", PRICEFEED_ADDRESS);
    const factory = await ethers.getContractAt("Factory", FACTORY_ADDRESS);
    const bimaVault = await ethers.getContractAt("BimaVault", BIMAVAULT_ADDRESS);

    console.log("troveManagerCount before: ", await factory.troveManagerCount());

    {
        const tx = await priceFeed.setOracle(
            COLLATERAL_ADDRESS,
            ORACLE_ADDRESS,
            ORACLE_HEARBEAT,
            SHARE_PRICE_SIGNATURE,
            SHARE_PRICE_DECIMALS,
            IS_BASE_CURRENCY_ETH_INDEXED
        );
        await tx.wait();
        console.log("Oracle is set on PriceFeed contract!");
    }

    // For some reason, if we don't wait for some time, the next transaction will revert
    await new Promise((res) => setTimeout(res, 10000));

    {
        const tx = await factory.deployNewInstance(
            COLLATERAL_ADDRESS,
            PRICEFEED_ADDRESS,
            CUSTOM_TROVE_MANAGER_IMPL_ADDRESS,
            CUSTOM_SORTED_TROVES_IMPL_ADDRESS,
            {
                minuteDecayFactor: MINUTE_DECAY_FACTOR,
                redemptionFeeFloor: REDEMPTION_FEE_FLOOR,
                maxRedemptionFee: MAX_REDEMPTION_FEE,
                borrowingFeeFloor: BORROWING_FEE_FLOOR,
                maxBorrowingFee: MAX_BORROWING_FEE,
                interestRateInBps: INTEREST_RATE_IN_BPS,
                maxDebt: MAX_DEBT,
                MCR: MCR,
            }
        );
        await tx.wait();
        console.log("New Trove Manager is deployed from Factory contract!");
    }

    const troveManagerCount = await factory.troveManagerCount();
    console.log("troveManagerCount after: ", troveManagerCount.toString());

    const troveManagerAddressFromFactory = await factory.troveManagers(BigInt(String(Number(troveManagerCount) - 1)));

    {
        const tx = await bimaVault.registerReceiver(troveManagerAddressFromFactory, REGISTERED_RECEIVER_COUNT);
        await tx.wait();
        console.log("Reciever has been registered!");
    }

    console.log("new Trove Manager address: ", troveManagerAddressFromFactory);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
