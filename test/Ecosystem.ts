import { expect } from "chai";
import { ethers } from "hardhat";
import { fetchGeneralData } from "../scripts/fetchData";
import { formatEther, parseEther } from "ethers";
import { mintBUSD } from "../scripts/mintBUSD";

const ZERO_ADDRESS = ethers.ZeroAddress;

describe("Ecosystem", function () {
    describe("Deployments", function () {
        it("Should deploy BimaCore and PriceFeed", async function () {
            const [owner, otherAccount] = await ethers.getSigners();

            const ERC20Deployer = await ethers.getContractFactory("StakedBTC");

            const MockAggregatorDeployer = await ethers.getContractFactory("MockOracle");
            const BimaCoreDeployer = await ethers.getContractFactory("BimaCore");

            const PriceFeedDeployer = await ethers.getContractFactory("PriceFeed");
            const FeeReceiverDeployer = await ethers.getContractFactory("FeeReceiver");
            const InterimAdminDeployer = await ethers.getContractFactory("InterimAdmin");

            const GasPoolDeployer = await ethers.getContractFactory("GasPool");
            const FactoryDeployer = await ethers.getContractFactory("Factory");

            const LiqudiationManagerDeployer = await ethers.getContractFactory("LiquidationManager");
            const BorrowerOperationsDeployer = await ethers.getContractFactory("BorrowerOperations");
            const DebtTokenDeployer = await ethers.getContractFactory("DebtToken");

            const StabilityPoolDeployer = await ethers.getContractFactory("StabilityPool");
            const TroveManagerDeployer = await ethers.getContractFactory("TroveManager");

            const SortedTrovesDeployer = await ethers.getContractFactory("SortedTroves");

            const TokenLockerDeployer = await ethers.getContractFactory("TokenLocker");

            const IncentiveVotingDeployer = await ethers.getContractFactory("IncentiveVoting");

            const BimaTokenDeployer = await ethers.getContractFactory("BimaToken");

            const BimaVaultDeployer = await ethers.getContractFactory("BimaVault");

            const stBTC = await ERC20Deployer.deploy();

            const stBTCAddress = await stBTC.getAddress();

            const mockAaggregator = await MockAggregatorDeployer.deploy();

            let deployerNonce = await ethers.provider.getTransactionCount(owner.address);

            // Disgusting hack to get the addresses of the contracts before deployment
            const bimaCoreAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce,
            });

            const priceFeedAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 1,
            });

            const bimaCore = await BimaCoreDeployer.deploy(
                owner.address,
                owner.address,
                priceFeedAddress,
                owner.address
            );

            console.log("BimaCore deployed!");

            const priceFeed = await PriceFeedDeployer.deploy(bimaCoreAddress, await mockAaggregator.getAddress());

            console.log("PriceFeed deployed!");

            const feeReceiver = await FeeReceiverDeployer.deploy(bimaCoreAddress);

            console.log("FeeReceiver deployed!");

            const interimAdmin = await InterimAdminDeployer.deploy(bimaCoreAddress);

            console.log("InterimAdmin deployed!");

            await bimaCore.commitTransferOwnership(await interimAdmin.getAddress());

            console.log("Ownership transferred to interimAdmin!");

            await bimaCore.commitTransferOwnership(await interimAdmin.getAddress());

            const gasPool = await GasPoolDeployer.deploy();

            console.log("Gas Pool deployed! ");

            const gasPoolAddress = await gasPool.getAddress();

            deployerNonce = await ethers.provider.getTransactionCount(owner.address);

            // Disgusting hack to get the addresses of the contracts before deployment
            const factoryAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce,
            });

            const liqudiationManagerAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 1,
            });

            const debtTokenAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 2,
            });

            const borrowerOperationsAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 3,
            });

            const stabilityPoolAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 4,
            });

            const troveManagerAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 5,
            });

            const sortedTrovesAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 6,
            });

            const tokenLockerAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 7,
            });

            const incentiveVotingAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 8,
            });

            const bimaTokenAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 9,
            });

            const bimaVaultAddress = ethers.getCreateAddress({
                from: owner.address,
                nonce: deployerNonce + 10,
            });

            // This crates TroveManagers
            const factory = await FactoryDeployer.deploy(
                bimaCoreAddress,
                debtTokenAddress,
                stabilityPoolAddress,
                borrowerOperationsAddress,
                sortedTrovesAddress,
                troveManagerAddress,
                liqudiationManagerAddress
            );
            console.log("Factory deployed!");

            const liqudiationManager = await LiqudiationManagerDeployer.deploy(
                stabilityPoolAddress,
                borrowerOperationsAddress,
                factoryAddress,
                BigInt("200000000000000000000") // gas compensation
            );

            console.log("LiquidationManager deployed!");

            const debtToken = await DebtTokenDeployer.deploy(
                "BUSD", //mkUSD or ULTRA name
                "BUSD", // symbol
                stabilityPoolAddress,
                borrowerOperationsAddress,
                bimaCoreAddress,
                // lzApp endpoint address
                // We currently don't have this address. If we can deploy LzApp as example we can later use this
                ZERO_ADDRESS,
                factoryAddress,
                gasPoolAddress,
                BigInt("200000000000000000000") // gas compensation
            );

            console.log("DebtToken deployed!");

            const borrowerOperations = await BorrowerOperationsDeployer.deploy(
                bimaCoreAddress,
                debtTokenAddress,
                factoryAddress,
                BigInt("1800000000000000000000"), // 1800 BUSD
                BigInt("0")
            );

            console.log("BorrowerOperations deployed!");

            const stabilityPool = await StabilityPoolDeployer.deploy(
                bimaCoreAddress,
                debtTokenAddress,
                bimaVaultAddress,
                factoryAddress,
                liqudiationManagerAddress
            );

            console.log("StabilityPool deployed!");

            const troveManager = await TroveManagerDeployer.deploy(
                bimaCoreAddress,
                gasPoolAddress,
                debtTokenAddress,
                borrowerOperationsAddress,
                bimaVaultAddress,
                liqudiationManagerAddress,
                BigInt("200000000000000000000")
            );

            console.log("TroveManager deployed!");

            const sortedTroves = await SortedTrovesDeployer.deploy();

            console.log("SortedTroves deployed!");

            const tokenLocker = await TokenLockerDeployer.deploy(
                bimaCoreAddress,
                bimaTokenAddress,
                incentiveVotingAddress,
                owner.address, // Change this with gnosis safe for real deployment...
                BigInt("1000000000000000000") // 1 BIMA
            );
            console.log("TokenLocker deployed!");

            const incentiveVoting = await IncentiveVotingDeployer.deploy(
                bimaCoreAddress,
                tokenLockerAddress,
                bimaVaultAddress
            );
            console.log("IncentiveVoting deployed!");

            const bimaToken = await BimaTokenDeployer.deploy(
                bimaVaultAddress,
                // lzApp endpoint address
                // We currently don't have this address. If we can deploy LzApp as example we can later use this
                ZERO_ADDRESS,
                tokenLockerAddress
            );

            console.log("BimaToken deployed!");

            const bimaVault = await BimaVaultDeployer.deploy(
                bimaCoreAddress,
                bimaTokenAddress,
                tokenLockerAddress,
                incentiveVotingAddress,
                stabilityPoolAddress,
                liqudiationManagerAddress
            );

            console.log("BimaVault deployed!");

            await priceFeed.setOracle(
                stBTCAddress,
                await mockAaggregator.getAddress(),
                BigInt("80000"), // seconds
                // We can add function data to convert prices if needed
                // The protocol uses this function to calculate wrapped values of tokens
                // For example if stETH is worth 1.0 ETH and wstETH is worth 0.8 ETH
                // We can call convert 1 wstETH to stETH function on wstETH contract
                // With this info we can calculate value of derivatives in different protocols
                // wstETH is not part of Bima Finance so they use this to get specific prices of other protocols
                // It only allows bytes4 function signatures
                // For more info read https://github.com/ethers-io/ethers.js/issues/44
                "0x00000000", // Read pure data assume stBTC is 1:1 with BTC :)
                BigInt("18"),
                false // Is it equivalent to ETH or default coin of the chain. On polygon if you set this to true it'll work with matic.
            );
            console.log("PriceFeed setOracle!");

            await factory.deployNewInstance(stBTCAddress, priceFeedAddress, ZERO_ADDRESS, ZERO_ADDRESS, {
                minuteDecayFactor: BigInt("999037758833783000"),
                redemptionFeeFloor: BigInt("5000000000000000"),
                maxRedemptionFee: BigInt("1000000000000000000"),
                borrowingFeeFloor: BigInt("0"),
                maxBorrowingFee: BigInt("0"),
                interestRateInBps: BigInt("0"),
                maxDebt: ethers.parseEther("1000000"), // 1M USD
                MCR: ethers.parseUnits("2", 18), // 200%
            });

            console.log("Factory deployNewInstance!");

            const troveManagerCount = await factory.troveManagerCount();
            const troveManagerAddressFromFactory = await factory.troveManagers(BigInt("0"));
            await bimaVault.registerReceiver(troveManagerAddressFromFactory, BigInt("2"));

            await stBTC.approve(borrowerOperationsAddress, BigInt("50000000000000000000"));

            await mintBUSD({
                amountstBTC: parseEther("1"),
                borrowerOperationsAddress: borrowerOperationsAddress,
                signer: owner,
                signerAddress: owner.address,
                collateralAddress: stBTCAddress,
                oracleAddress: await mockAaggregator.getAddress(),
                percentage: 300n,
                provider: owner.provider,
                troveManagerAddress: troveManagerAddressFromFactory,
            });

            await mintBUSD({
                amountstBTC: parseEther("2"),
                borrowerOperationsAddress: borrowerOperationsAddress,
                signer: owner,
                signerAddress: owner.address,
                collateralAddress: stBTCAddress,
                oracleAddress: await mockAaggregator.getAddress(),
                percentage: 400n,
                provider: owner.provider,
                troveManagerAddress: troveManagerAddressFromFactory,
            });

            await mintBUSD({
                amountstBTC: parseEther("1"),
                borrowerOperationsAddress: borrowerOperationsAddress,
                signer: owner,
                signerAddress: owner.address,
                collateralAddress: stBTCAddress,
                oracleAddress: await mockAaggregator.getAddress(),
                percentage: 400n,
                provider: owner.provider,
                troveManagerAddress: troveManagerAddressFromFactory,
            });

            /**
            await borrowerOperations.openTrove(
              troveManagerAddressFromFactory, // This manager is created on factory with deploy new instance
              owner.address, // receiver address
              BigInt("10000000000000000"), // Maximum Fee percentage 1%
              ethers.parseEther("1"), // Transferred amount 1 BTC
              ethers.parseEther("35000"), // Receive 30000 BUSD
              ZERO_ADDRESS,
              ZERO_ADDRESS
            );
       */
            const troveManagerFromFactory = await ethers.getContractAt("TroveManager", troveManagerAddressFromFactory);

            const count = await troveManagerFromFactory.getTroveOwnersCount();

            console.log("Count: ", count);

            const troveOwner = await troveManagerFromFactory.getTroveFromTroveOwnersArray(0);

            console.log("Trove Owner: ", troveOwner);

            const troveStatus = await troveManagerFromFactory.getTroveStake(otherAccount.address);
            console.log("Trove status: ", formatEther(troveStatus));
            await stBTC.transfer(otherAccount, ethers.parseEther("1"));

            await stBTC.connect(otherAccount).approve(borrowerOperationsAddress, ethers.parseEther("1"));

            /**
            await borrowerOperations.connect(otherAccount).openTrove(
              troveManagerAddressFromFactory, // This manager is created on factory with deploy new instance
              otherAccount.address, // receiver address
              ethers.parseEther("0.01"), // Maximum Fee percentage 1%
              ethers.parseEther("1"), // Transferred amount 1 BTC
              ethers.parseEther("44600"), // Receive 30000 BUSD
              ZERO_ADDRESS,
              ZERO_ADDRESS
            );
       */
            const troveStatusOtherAccount = await troveManagerFromFactory.getTroveStake(otherAccount.address);
            console.log("Trove status other account: ", formatEther(troveStatusOtherAccount));

            const res = await fetchGeneralData({
                provider: owner.provider,
                troveManagerAddress: troveManagerAddressFromFactory,
            });

            if (!res) {
                throw new Error("Failed to fetch general data");
            }

            const prettierRes = {
                totalCollateral: formatEther(res.totalCollateral),
                totalDebt: formatEther(res.totalDebt),
                mcr: formatEther(res.mcr),
                mintFee: formatEther(res.mintFee),
                borrowInterestRate: formatEther(res.borrowInterestRate),
                redemptionRate: formatEther(res.redemptionRate),
                totalStakes: formatEther(res.totalStakes),
                rewardRate: formatEther(res.rewardRate),
                rewardIntegral: formatEther(res.rewardIntegral),
                totalActiveDebt: formatEther(res.totalActiveDebt),
                totalActiveCollateral: formatEther(res.totalActiveCollateral),
                maxSystemDebt: formatEther(res.maxSystemDebt),
            };

            console.log(prettierRes);

            const balance = await debtToken.balanceOf(owner.address);

            expect(await bimaCore.getAddress()).to.equal(bimaCoreAddress);
            expect(await priceFeed.getAddress()).to.equal(priceFeedAddress);
            expect(balance).to.equal(ethers.parseEther("15000"));
        });
    });
});
