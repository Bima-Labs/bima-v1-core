import { ethers } from "hardhat";
import { Options } from "@layerzerolabs/lz-v2-utilities";

const SOURCE_OFT_ADDRESS = "0x6bedE1c6009a78c222D9BDb7974bb67847fdB68c";

async function main() {
    const sourceOft = await ethers.getContractAt("DebtToken", SOURCE_OFT_ADDRESS);

    // console.log(Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString());

    // message types:
    // uint16 internal constant SEND = 1; // a standard token transfer via send()
    // uint16 internal constant SEND_AND_CALL = 2; // a composed token transfer via send()

    console.log("Setting Enforced Options..");

    {
        const tx = await sourceOft.setEnforcedOptions([
            {
                eid: 30101,
                msgType: 1,
                options: Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString(),
            },
        ]);
        await tx.wait();
    }

    // {
    //     const tx = await sourceOft.setEnforcedOptions([
    //         {
    //             eid: 30329,
    //             msgType: 1,
    //             options: Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString(),
    //         },
    //     ]);
    //     await tx.wait();
    // }

    // {
    //     const tx = await sourceOft.setEnforcedOptions([
    //         {
    //             eid: 30153,
    //             msgType: 1,
    //             options: Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString(),
    //         },
    //     ]);
    //     await tx.wait();
    // }

    // {
    //     const tx = await sourceOft.setEnforcedOptions([
    //         {
    //             eid: 30332,
    //             msgType: 1,
    //             options: Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString(),
    //         },
    //     ]);
    //     await tx.wait();
    // }

    console.log("Done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
