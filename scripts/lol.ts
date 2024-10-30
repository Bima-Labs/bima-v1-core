import { ethers } from "hardhat";

//npx hardhat run scripts/deployer.ts --network lorenzo_testnet

const ZERO_ADDRESS = ethers.ZeroAddress;

async function main() {
    const [owner, otherAccount] = await ethers.getSigners();

    const factory = await ethers.getContractAt("Factory", "0x687b2B84Da662d900481a66FB851B91186497606");

    const bimaVault = await ethers.getContractAt("BimaVault", "0xA5475feACD19d5365112AAA258264C2eAE435905");

    const resulty = await factory.deployNewInstance(
        "0x103337452FfA3bA9Ca82df11e0A545AA1a577714",
        "0xEC44704E117074722b24733Ca39EA6e032b21b3b",
        ZERO_ADDRESS,
        ZERO_ADDRESS,
        {
            minuteDecayFactor: BigInt("999037758833783000"),
            redemptionFeeFloor: BigInt("5000000000000000"),
            maxRedemptionFee: BigInt("1000000000000000000"),
            borrowingFeeFloor: BigInt("0"),
            maxBorrowingFee: BigInt("0"),
            interestRateInBps: BigInt("0"),
            maxDebt: ethers.parseEther("1000000"), // 1M USD
            MCR: BigInt("1200000000000000000"),
        }
    );

    console.log("Factory deployed at: ", resulty);
    const troveManagerCount = await factory.troveManagerCount();

    console.log("Trove Manager count: ", troveManagerCount.toString());

    const troveManagerAddressFromFactory = await factory.troveManagers(BigInt("0"));

    console.log("Trove Manager address: ", troveManagerAddressFromFactory);

    await bimaVault.registerReceiver(troveManagerAddressFromFactory, BigInt("2"));

    console.log("stBTC Trove Manager address: ", troveManagerAddressFromFactory);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
