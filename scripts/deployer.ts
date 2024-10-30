import { ethers } from "hardhat";

//npx hardhat run scripts/deployer.ts --network lorenzo_testnet

const ZERO_ADDRESS = ethers.ZeroAddress;

async function main() {
    const [owner, otherAccount] = await ethers.getSigners();

    // Factories

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

    // Deployments

    const stBTC = await ERC20Deployer.deploy();
    await stBTC.waitForDeployment();
    const stBTCAddress = await stBTC.getAddress();
    console.log("stBTCAddress deployed!: ", stBTCAddress);

    const mockAaggregator = await MockAggregatorDeployer.deploy();
    await mockAaggregator.waitForDeployment();
    const mockAaggregatorAddress = await mockAaggregator.getAddress();
    console.log("MockAggregatorAddress deployed!: ", mockAaggregatorAddress);

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

    const bimaCore = await BimaCoreDeployer.deploy(owner.address, owner.address, priceFeedAddress, owner.address);
    await bimaCore.waitForDeployment();
    console.log("BimaCore deployed!: ", bimaCoreAddress);

    const priceFeed = await PriceFeedDeployer.deploy(bimaCoreAddress, mockAaggregatorAddress);
    await priceFeed.waitForDeployment();
    console.log("PriceFeed deployed!: ", priceFeedAddress);

    const feeReceiver = await FeeReceiverDeployer.deploy(bimaCoreAddress);
    await feeReceiver.waitForDeployment();
    console.log("FeeReceiver deployed!: ", await feeReceiver.getAddress());

    const interimAdmin = await InterimAdminDeployer.deploy(bimaCoreAddress);
    await interimAdmin.waitForDeployment();
    const interimAdminAddress = await interimAdmin.getAddress();
    console.log("InterimAdmin deployed!: ", interimAdminAddress);

    {
        const tx = await bimaCore.commitTransferOwnership(interimAdminAddress);
        await tx.wait();
        console.log("Ownership transferred to interimAdmin!");
    }

    const gasPool = await GasPoolDeployer.deploy();
    await gasPool.waitForDeployment();
    const gasPoolAddress = await gasPool.getAddress();
    console.log("Gas Pool deployed!: ", gasPoolAddress);

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
    await factory.waitForDeployment();
    console.log("Factory deployed!: ", factoryAddress);

    const liqudiationManager = await LiqudiationManagerDeployer.deploy(
        stabilityPoolAddress,
        borrowerOperationsAddress,
        factoryAddress,
        BigInt("200000000000000000000") // gas compensation
    );
    await liqudiationManager.waitForDeployment();
    console.log("LiquidationManager deployed!: ", liqudiationManagerAddress);

    const debtToken = await DebtTokenDeployer.deploy(
        "US Bitcoin Dollar", //mkUSD or ULTRA name
        "USBD", // symbol
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
    await debtToken.waitForDeployment();
    console.log("DebtToken deployed!: ", debtTokenAddress);

    const borrowerOperations = await BorrowerOperationsDeployer.deploy(
        bimaCoreAddress,
        debtTokenAddress,
        factoryAddress,
        BigInt("1800000000000000000000"), // 1800 USDB
        BigInt("200000000000000000000")
    );
    await borrowerOperations.waitForDeployment();
    console.log("BorrowerOperations deployed!: ", borrowerOperationsAddress);

    const stabilityPool = await StabilityPoolDeployer.deploy(
        bimaCoreAddress,
        debtTokenAddress,
        bimaVaultAddress,
        factoryAddress,
        liqudiationManagerAddress
    );
    await stabilityPool.waitForDeployment();
    console.log("StabilityPool deployed!: ", stabilityPoolAddress);

    const troveManager = await TroveManagerDeployer.deploy(
        bimaCoreAddress,
        gasPoolAddress,
        debtTokenAddress,
        borrowerOperationsAddress,
        bimaVaultAddress,
        liqudiationManagerAddress,
        BigInt("200000000000000000000")
    );
    await troveManager.waitForDeployment();
    console.log("TroveManager deployed!: ", troveManagerAddress);

    const sortedTroves = await SortedTrovesDeployer.deploy();
    await sortedTroves.waitForDeployment();
    console.log("SortedTroves deployed!: ", sortedTrovesAddress);

    const tokenLocker = await TokenLockerDeployer.deploy(
        bimaCoreAddress,
        bimaTokenAddress,
        incentiveVotingAddress,
        owner.address, // Change this with gnosis safe for real deployment...
        BigInt("1000000000000000000") // 1 BIMA
    );
    await tokenLocker.waitForDeployment();
    console.log("TokenLocker deployed!: ", tokenLockerAddress);

    const incentiveVoting = await IncentiveVotingDeployer.deploy(bimaCoreAddress, tokenLockerAddress, bimaVaultAddress);
    await incentiveVoting.waitForDeployment();
    console.log("IncentiveVoting deployed!: ", incentiveVotingAddress);

    const bimaToken = await BimaTokenDeployer.deploy(
        bimaVaultAddress,
        // lzApp endpoint address
        // We currently don't have this address. If we can deploy LzApp as example we can later use this
        ZERO_ADDRESS,
        tokenLockerAddress
    );
    await bimaToken.waitForDeployment();
    console.log("BimaToken deployed!: ", bimaTokenAddress);

    const bimaVault = await BimaVaultDeployer.deploy(
        bimaCoreAddress,
        bimaTokenAddress,
        tokenLockerAddress,
        incentiveVotingAddress,
        stabilityPoolAddress,
        liqudiationManagerAddress
    );
    await bimaVault.waitForDeployment();
    console.log("BimaVault deployed!: ", bimaVaultAddress);

    {
        const tx = await priceFeed.setOracle(
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
        await tx.wait();
        console.log("PriceFeed setOracle!");
    }

    {
        const tx = await factory.deployNewInstance(stBTCAddress, priceFeedAddress, ZERO_ADDRESS, ZERO_ADDRESS, {
            minuteDecayFactor: BigInt("999037758833783000"),
            redemptionFeeFloor: BigInt("5000000000000000"),
            maxRedemptionFee: BigInt("1000000000000000000"),
            borrowingFeeFloor: BigInt("0"),
            maxBorrowingFee: BigInt("0"),
            interestRateInBps: BigInt("0"),
            maxDebt: ethers.parseEther("1000000"), // 1M USD
            MCR: ethers.parseUnits("2", 18), // 2e18 = 200%
        });
        await tx.wait();
        console.log("Factory deployNewInstance!");
    }

    // const troveManagerCount = await factory.troveManagerCount();

    const troveManagerAddressFromFactory = await factory.troveManagers(BigInt("0"));

    {
        const tx = await bimaVault.registerReceiver(troveManagerAddressFromFactory, BigInt("2"));
        await tx.wait();
    }

    console.log("stBTC Trove Manager address: ", troveManagerAddressFromFactory);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
