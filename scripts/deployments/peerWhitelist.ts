import { ethers } from "hardhat";

const ARB_SEPOLIA_OFT_ADDRESS = "0xA02b9C28D949243772087d4993FB3A486dF98359";
const BITLAYER_TESTNET_OFT_ADDRESS = "0xC0dC5053349B6f5B3f94622ad5846771C09fA6dE";

async function main() {
    const arbSepoliaOft = await ethers.getContractAt("OFT", ARB_SEPOLIA_OFT_ADDRESS);
    const bitlayerTestnetOft = await ethers.getContractAt("OFT", BITLAYER_TESTNET_OFT_ADDRESS);

    const arbSepoliaEid = 40231;
    const bitlayerTestnetEid = 40320;

    console.log("whitelisting..");

    // const tx = await arbSepoliaOft.setPeer(bitlayerTestnetEid, ethers.zeroPadValue(BITLAYER_TESTNET_OFT_ADDRESS, 32));
    // await tx.wait();

    const tx = await bitlayerTestnetOft.setPeer(arbSepoliaEid, ethers.zeroPadValue(ARB_SEPOLIA_OFT_ADDRESS, 32));
    await tx.wait();

    console.log("done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
