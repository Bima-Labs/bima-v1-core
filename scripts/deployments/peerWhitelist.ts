import { ethers } from "hardhat";

const SOURCE_OFT_ADDRESS = "0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c";

async function main() {
    const sourceOft = await ethers.getContractAt("DebtToken", SOURCE_OFT_ADDRESS);

    console.log("Whitelisting..");

    {
        const tx = await sourceOft.setPeer(
            30332,
            ethers.zeroPadValue("0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c", 32)
        );
        await tx.wait();
    }

    // {
    //     const tx = await sourceOft.setPeer(
    //         30329,
    //         ethers.zeroPadValue("0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c", 32)
    //     );
    //     await tx.wait();
    // }

    console.log("done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
