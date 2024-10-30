import { Provider, Signer, ZeroAddress, formatEther, parseEther } from "ethers";
import { ethers } from "hardhat";

import {
    BorrowerOperations__factory,
    TroveManager__factory,
    Factory__factory,
    BimaVault__factory,
    StakedBTC__factory,
} from "../typechain-types/index";
import { fetchPrice } from "./fetchData";

export const mintBUSD = async ({
    borrowerOperationsAddress,
    signer,
    signerAddress,
    provider,
    amountstBTC,
    percentage,
    troveManagerAddress,
    oracleAddress,
    collateralAddress,
}: {
    borrowerOperationsAddress: string;
    troveManagerAddress: string;
    signer: Signer;
    provider: Provider;
    signerAddress: string;
    amountstBTC: bigint;
    percentage: bigint;
    oracleAddress: string;
    collateralAddress: string;
}) => {
    //const signerAddress = await signer.getAddress();
    const borrowerOperationsContract = BorrowerOperations__factory.connect(borrowerOperationsAddress, signer);

    const troveManagerContract = await TroveManager__factory.connect(troveManagerAddress, signer);

    /** 
  const factoryContract = await Factory__factory.connect(
    troveManagerAddress,
    signer
  );

  const bimaVaultContract = await BimaVault__factory.connect(
    troveManagerAddress,
    signer
  );
*/
    const stBTC = await StakedBTC__factory.connect(collateralAddress, signer);

    /**
  if (!provider) {
    throw new Error("Provider not available");
  }
 */
    const price = await fetchPrice({
        oracleAddress,
        collateralAddress,
        signer: signer,
    });

    console.log("Price: ", price);
    if (!price) {
        console.log("Price not available");
        return null;
    }

    const normalizedPrice = price / 10n ** 8n;

    const percentageAmount = (amountstBTC * normalizedPrice * 100n) / percentage;

    // Prints eth balance

    //const balance = await provider.getBalance(signerAddress);
    //console.log("Balance: ", formatEther(balance));

    // Prints balance of stBTC
    const balanceOfUser1 = await stBTC.balanceOf(signerAddress);

    console.log("stBTC Balance: ", formatEther(balanceOfUser1));

    const result = await stBTC.approve(borrowerOperationsAddress, parseEther("50"));

    console.log(result);

    const depositedAmount = await troveManagerContract.getTroveStake(signerAddress);

    const debtAmount = await troveManagerContract.getTroveCollAndDebt(signerAddress);

    console.log("Debt Amount: ", formatEther(debtAmount[1]));

    if (depositedAmount === 0n) {
        console.log("AmountsBTC: ", formatEther(amountstBTC));
        console.log("Frust: ", formatEther(percentageAmount));

        console.log(troveManagerAddress);
        console.log("Signer address: ", signerAddress);

        try {
            const dataTx = await borrowerOperationsContract.openTrove(
                troveManagerAddress, // troveManagerAddress
                signerAddress,
                BigInt("1000000000000000000"),
                amountstBTC,
                percentageAmount,
                ZeroAddress,
                ZeroAddress
            );
        } catch (error) {
            console.log("Error opening trove - " + error);
            throw error;
        }
    } else {
        const increaseDecrease = amountstBTC - depositedAmount;

        const newAmounts = (amountstBTC * normalizedPrice * 100n) / percentage;

        const change = newAmounts - debtAmount[1];

        console.log({
            0: troveManagerAddress, // troveManagerAddress
            1: signerAddress, // borrower
            2: parseEther("0.01"), // maxFeePercentage
            3: increaseDecrease > 0n ? increaseDecrease : 0n, // collDeposit
            4: increaseDecrease < 0n ? -increaseDecrease : 0n, // collWithdrawal
            5: change >= 0n ? change : -change, // debtChange
            6: change >= 0n, //isDebtIncrease
            7: ZeroAddress,
            8: ZeroAddress,
        });

        return await borrowerOperationsContract.adjustTrove(
            troveManagerAddress, // troveManagerAddress
            signerAddress, // borrower
            parseEther("0.01"), // maxFeePercentage
            increaseDecrease > 0n ? increaseDecrease : 0n, // collDeposit
            increaseDecrease < 0n ? -increaseDecrease : 0n, // collWithdrawal
            change >= 0n ? change : -change, // debtChange
            change >= 0n, //isDebtIncrease
            ZeroAddress,
            ZeroAddress
        );
    }
};

async function main() {
    try {
        const [owner, user, user1] = await ethers.getSigners();

        const data = {
            ownerSigner: user1,
            borrowerOperationsAddress: "0x1364D82f5D47c7715eb20Ef1F5505E0ACD7b57d2",
            troveManagerAddress: "0x43F8267e93B9d898d9ef798Ad1Eec10D570A83aF",
            signer: user1,
            signerAddress: await user1.getAddress(),
            amountstBTC: ethers.parseEther("1"),
            percentage: 200n,
            provider: user1.provider,
            oracleAddress: "0xeC45264638883e1a8B92762B384D0Cb3A1eF8999", // Mock Aggregator address
            collateralAddress: "0x35a5ba4859d28600FaE30EeB0494B3AfdB459f08", //Stake BTC address
        };

        const tx = await mintBUSD(data);
        console.log("---", tx);
    } catch (error) {
        console.log("error:", error);
    }
}
/*
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

*/
// stBTCAddress deployed!:  0x35a5ba4859d28600FaE30EeB0494B3AfdB459f08
// MockAggregatorAddress deployed!:  0xeC45264638883e1a8B92762B384D0Cb3A1eF8999
// BimaCore deployed!:  0x9d57b30957905d9aB576F33046017a6a482C71FB
// PriceFeed deployed!:  0x54A34D363E983813195db729cc09DA4CF9661493
// FeeReceiver deployed!:  0x890fb3671DABb98Ba0EeddE1A08aE593A94F876A
// InterimAdmin deployed!:  0x474BCf5045c6C060c30321aDb472B3DD07a9eC2F
// Ownership transferred to interimAdmin!
// Gas Pool deployed!:  0xC65a00B40cb6170971d84766939889623cBbd5AE
// Factory deployed!:  0x6B7756244187f6488f4E313EBe981D6b73CA3F67
// LiquidationManager deployed!:  0x8bF8C8364034815E726500372E58FAF717eAbEA6
// DebtToken deployed!:  0x61cfFA814f9a2f203fAc90a44F7Ef83459901793
// BorrowerOperations deployed!:  0x1364D82f5D47c7715eb20Ef1F5505E0ACD7b57d2
// StabilityPool deployed!:  0x5EFaBeEFE69b8E31d0ac08bF761e06D23540FA9B
// TroveManager deployed!:  0xC97034C364EA03ba925CC04492bD6c1Ca35bC06A
// SortedTroves deployed!:  0x0799ec9F241848E91D0050F2051706ED4aA3DBcC
// TokenLocker deployed!:  0x95710d78d81e2778b869478F3e8fC0560Fe89823
// IncentiveVoting deployed!:  0xCD658CDC792f2A13fab3F7B9e09b882d6E7E5C32
// BimaToken deployed!:  0x41e4abC51371Dd77d885aea664CB71EBac675D27
// BimaVault deployed!:  0x1602570B11D8C4D61Ba1c8BAD55C0BB677822Ab0
// PriceFeed setOracle!
// Factory deployNewInstance!
// stBTC Trove Manager address:  0x43F8267e93B9d898d9ef798Ad1Eec10D570A83aF
