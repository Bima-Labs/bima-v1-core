import { ethers } from "hardhat";
import { Options } from "@layerzerolabs/lz-v2-utilities";

const SOURCE_OFT_ADDRESS = "0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c";
const DEST_ID = 30371;

async function main() {
    const [owner] = await ethers.getSigners();

    console.log(`Deployer: ${owner.address}`);

    const sourceOft = await ethers.getContractAt("DebtToken", SOURCE_OFT_ADDRESS);

    const amountToSend = ethers.parseUnits("1", 18);

    console.log("Balance: ", ethers.formatUnits(await sourceOft.balanceOf(owner.address), 18));

    // build sendParams struct
    const sendParams = {
        dstEid: DEST_ID,
        to: ethers.zeroPadValue(owner.address, 32),
        amountLD: amountToSend,
        minAmountLD: amountToSend,
        extraOptions: Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString(),
        composeMsg: "0x",
        oftCmd: ethers.ZeroHash,
    };
    console.log("\nsendParams: ", sendParams);

    // get fee
    console.log("\n getting a fee..");
    const fee = await sourceOft.quoteSend(sendParams, false);
    console.log("fee: ", fee);

    // // send
    // console.log("\n sending transaction..");
    // const sendTx = await sourceOft.send(sendParams, fee, owner.address, { value: fee.nativeFee });
    // await sendTx.wait();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
