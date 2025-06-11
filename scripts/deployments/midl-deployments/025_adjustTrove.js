/**
 * @param {import('hardhat/types').HardhatRuntimeEnvironment} hre
 */
async function main(hre) {
    try {
        await hre.midl.initialize();
        const bmBTCAddress = "0x4CDCa957FEc660d888478171045137619Eb1AF7F";

        const borrowerOperationsAddress = "0x20bdde9470B52729E910EFa9f2f7c2B6a5682a53";
        const troveManagerAddress = "0x431F44a506ACbaf28864f849CeeC22214BA84E43";
        const signerAddress = "0x5c747e3505aCD3fD66325e7214516401e066EFEB";
        const lstPrice = 95000;
        const amountstBTC = BigInt("2000000000000000000");
        const percentage = 200;
        const ZeroAddress = hre.ethers.ZeroAddress;

        console.log("Approving bmBTC...");
        await hre.midl.callContract("StakedBTC", "approve", {
            args: [borrowerOperationsAddress, amountstBTC],
            to: bmBTCAddress,
            gas: 10000000n,
        });
        console.log("bmBTC Approved");

        const normalizedPrice = Number(lstPrice);

        const increaseDecrease = amountstBTC;
        const newAmounts =
            BigInt(Number(amountstBTC) * normalizedPrice * 100) / BigInt(percentage) - hre.ethers.parseEther("200");
        const change = newAmounts;

        console.log({
            0: troveManagerAddress,
            1: signerAddress,
            2: hre.ethers.parseEther("1"),
            3: increaseDecrease > 0n ? increaseDecrease : 0n,
            4: increaseDecrease < 0n ? -increaseDecrease : 0n,
            5: change >= 0n ? change : -change,
            6: change >= 0n,
            7: ZeroAddress,
            8: ZeroAddress,
        });

        console.log("ALL PARAMS PASSING IN ADJUST TROVE", {
            troveManagerAddress,
            signerAddress,
            increaseDecrease,
            change,
        });

        console.log("Configuring adjustTrove...");
        await hre.midl.callContract("BorrowerOperations", "adjustTrove", {
            args: [
                troveManagerAddress,
                signerAddress,
                hre.ethers.parseEther("1"),
                increaseDecrease > 0n ? increaseDecrease : 0n,
                increaseDecrease < 0n ? -increaseDecrease : 0n,
                change >= 0n ? change : -change,
                change >= 0n,
                ZeroAddress,
                ZeroAddress,
            ],
            to: borrowerOperationsAddress,
            gas: BigInt("1000000"),
        });
        console.log("adjustTrove call queued");

        console.log("Executing transaction...");
        await hre.midl.execute();
        console.log("adjustTrove called successfully");
    } catch (e) {
        console.error("Error adjusting trove:", e);
        throw e;
    }
}

// Export the function for Hardhat to use
module.exports = main;
module.exports.tags = ["main", "AdjustTrove"];

// Execute the script if run directly
if (require.main === module) {
    const hre = require("hardhat");
    main(hre)
        .then(() => {
            console.log("Script completed successfully.");
        })
        .catch((error) => {
            console.error("Error executing script:", error);
        })
        .finally(() => {
            process.exit(0);
        });
}
