import { ethers } from "hardhat";
import { Options } from "@layerzerolabs/lz-v2-utilities";

const ARBITRUM_OFT_ADDRESS = "0x099DfC1131CaB9e04A88dB03F36ae057E3b1e878";
const POLYGON_OFT_ADDRESS = "0x099DfC1131CaB9e04A88dB03F36ae057E3b1e878";

async function main() {
    const [owner] = await ethers.getSigners();

    const arbitrumOft = await ethers.getContractAt("OFT", ARBITRUM_OFT_ADDRESS);
    const polygonOft = await ethers.getContractAt("OFT", POLYGON_OFT_ADDRESS);

    const arbitrumEid = 30110;
    const polygonEid = 30109;

    // console.log("whitelisting..");

    // const tx = await arbitrumOft.setPeer(polygonEid, ethers.zeroPadValue(POLYGON_OFT_ADDRESS, 32));
    // await tx.wait();

    // const tx = await polygonOft.setPeer(arbitrumEid, ethers.zeroPadValue(ARBITRUM_OFT_ADDRESS, 32));
    // await tx.wait();

    console.log("done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
