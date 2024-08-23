// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// mocks
import {MockOracle} from "../../contracts/MockOracle.sol";
import {StakedBTC} from "../../contracts/StakedBTC.sol";

// interfaces
import {IDebtToken} from "../../contracts/interfaces/IDebtToken.sol";
import {IStabilityPool} from "../../contracts/interfaces/IStabilityPool.sol";
import {IBorrowerOperations} from "../../contracts/interfaces/IBorrowerOperations.sol";
import {ILiquidationManager} from "../../contracts/interfaces/ILiquidationManager.sol";
import {IBabelVault} from "../../contracts/interfaces/IVault.sol";
import {IBabelToken} from "../../contracts/interfaces/IBabelToken.sol";
import {IIncentiveVoting} from "../../contracts/interfaces/IIncentiveVoting.sol";
import {ITokenLocker} from "../../contracts/interfaces/ITokenLocker.sol";
import {IEmissionSchedule} from "../../contracts/interfaces/IEmissionSchedule.sol";
import {IBoostCalculator} from "../../contracts/interfaces/IBoostCalculator.sol";

// core
import {BabelCore} from "../../contracts/core/BabelCore.sol";
import {PriceFeed} from "../../contracts/core/PriceFeed.sol";
import {Factory, IFactory} from "../../contracts/core/Factory.sol";
import {LiquidationManager} from "../../contracts/core/LiquidationManager.sol";
import {DebtToken} from "../../contracts/core/DebtToken.sol";
import {BorrowerOperations} from "../../contracts/core/BorrowerOperations.sol";
import {StabilityPool} from "../../contracts/core/StabilityPool.sol";
import {TroveManager} from "../../contracts/core/TroveManager.sol";
import {SortedTroves} from "../../contracts/core/SortedTroves.sol";

// dao
import {FeeReceiver} from "../../contracts/dao/FeeReceiver.sol";
import {InterimAdmin} from "../../contracts/dao/InterimAdmin.sol";
import {TokenLocker} from "../../contracts/dao/TokenLocker.sol";
import {IncentiveVoting} from "../../contracts/dao/IncentiveVoting.sol";
import {BabelToken} from "../../contracts/dao/BabelToken.sol";
import {BabelVault} from "../../contracts/dao/Vault.sol";
import {EmissionSchedule} from "../../contracts/dao/EmissionSchedule.sol";
import {BoostCalculator} from "../../contracts/dao/BoostCalculator.sol";

// foundry
import {Test} from "forge-std/Test.sol";

struct Users {
    address owner;
    address guardian;
    address user1;
    address user2;
    address gasPool;
}

struct DeployAddresses {
    uint256 nonce;
    address core;
    address priceFeed;
    address feeReceiver;
    address factory;
    address liquidationMgr;
    address debtToken;
    address borrowerOps;
    address stabilityPool;
    address troveMgr;
    address tokenLocker;
    address incentiveVoting;
    address babelToken;
    address babelVault;
}

contract TestSetup is Test {
    // test helpers
    Users internal users;
    MockOracle mockOracle;
    StakedBTC stakedBTC;

    // core contracts
    BabelCore internal babelCore;
    PriceFeed internal priceFeed;
    Factory internal factory;
    LiquidationManager internal liquidationMgr;
    DebtToken internal debtToken;
    BorrowerOperations internal borrowerOps;
    StabilityPool internal stabilityPool;
    TroveManager internal troveMgr;
    SortedTroves internal sortedTroves;

    // dao contracts
    FeeReceiver internal feeReceiver;
    InterimAdmin internal interimAdmin;
    TokenLocker internal tokenLocker;
    IncentiveVoting internal incentiveVoting;
    BabelToken internal babelToken;
    BabelVault internal babelVault;
    EmissionSchedule internal emissionSchedule;
    BoostCalculator  internal boostCalc;

    // constants
    uint256 internal constant INIT_GAS_COMPENSATION = 200e18;
    uint256 internal constant INIT_MIN_NET_DEBT = 1800e18;
    uint256 internal constant INIT_LOCK_TO_TOKEN_RATIO = 1e18;
    address internal constant ZERO_ADDRESS = address(0);

    uint256 internal constant INIT_BS_GRACE_WEEKS = 1;
    uint64 internal constant INIT_ES_LOCK_WEEKS = 4;
    uint64 internal constant INIT_ES_LOCK_DECAY_WEEKS = 1;
    uint64 internal constant INIT_ES_WEEKLY_PCT = 2500; // 25%
    uint256 internal constant INIT_BAB_TKN_TOTAL_SUPPLY = type(uint32).max*INIT_LOCK_TO_TOKEN_RATIO;
    uint64 internal constant INIT_VLT_LOCK_WEEKS = 2;


    function setUp() public virtual {
        // prevent Foundry from setting block.timestamp = 1 which can cause
        // errors in this protocol
        vm.warp(1659973223);

        // set addresses used by tests
        users.owner = address(0x1111);
        users.guardian = address(0x2222);
        users.user1 = address(0x3333);
        users.user2 = address(0x4444);
        users.gasPool = address(0x5555);

        // contract constructors are inter-dependent so need to precalculate
        // some addresses to correctly initialize immutable storage variables
        DeployAddresses memory addresses;

        // owner creates everything
        vm.startPrank(users.owner);

        // mocks
        mockOracle = new MockOracle();
        stakedBTC = new StakedBTC();
        ++addresses.nonce;

        addresses.core = vm.computeCreateAddress(users.owner, ++addresses.nonce);
        addresses.priceFeed = vm.computeCreateAddress(users.owner, ++addresses.nonce);
        addresses.feeReceiver = vm.computeCreateAddress(users.owner, ++addresses.nonce);

        // create and configure contracts in the required dependency order
        //
        // Core
        babelCore = new BabelCore(users.owner, users.guardian, addresses.priceFeed, addresses.feeReceiver);
        assertEq(addresses.core, address(babelCore));
        
        // PriceFeed
        priceFeed = new PriceFeed(addresses.core, address(mockOracle));
        assertEq(addresses.priceFeed, address(priceFeed));
        priceFeed.setOracle(address(stakedBTC),
                            address(mockOracle),
                            80000, // heartbeat,
                            bytes4(0x00000000), // Read pure data assume stBTC is 1:1 with BTC :)
                            18, // sharePriceDecimals
                            false //_isEthIndexed
                            );

        // FeeReceiver
        feeReceiver = new FeeReceiver(addresses.core); ++addresses.nonce;
        assertEq(addresses.feeReceiver, address(feeReceiver));

        // InterimAdmin
        interimAdmin = new InterimAdmin(addresses.core);
        // not sure why ++addresses.nonce is not required here but it works without it

        // SortedTroves
        sortedTroves = new SortedTroves();
        ++addresses.nonce;

        addresses.factory = vm.computeCreateAddress(users.owner, ++addresses.nonce);
        addresses.liquidationMgr = vm.computeCreateAddress(users.owner, ++addresses.nonce);
        addresses.debtToken = vm.computeCreateAddress(users.owner, ++addresses.nonce);
        addresses.borrowerOps = vm.computeCreateAddress(users.owner, ++addresses.nonce);
        addresses.stabilityPool = vm.computeCreateAddress(users.owner, ++addresses.nonce);
        addresses.troveMgr = vm.computeCreateAddress(users.owner, ++addresses.nonce);
        addresses.tokenLocker = vm.computeCreateAddress(users.owner, ++addresses.nonce);
        addresses.incentiveVoting = vm.computeCreateAddress(users.owner, ++addresses.nonce);
        addresses.babelToken = vm.computeCreateAddress(users.owner, ++addresses.nonce);
        addresses.babelVault = vm.computeCreateAddress(users.owner, ++addresses.nonce);

        // Factory
        factory = new Factory(addresses.core, 
                              IDebtToken(addresses.debtToken),
                              IStabilityPool(addresses.stabilityPool),
                              IBorrowerOperations(addresses.borrowerOps),
                              address(sortedTroves),
                              addresses.troveMgr,
                              ILiquidationManager(addresses.liquidationMgr));
        assertEq(addresses.factory, address(factory));

        // LiquidationManager
        liquidationMgr = new LiquidationManager(IStabilityPool(addresses.stabilityPool),
                                                IBorrowerOperations(addresses.borrowerOps),
                                                addresses.factory,
                                                INIT_GAS_COMPENSATION);
        assertEq(addresses.liquidationMgr, address(liquidationMgr));

        // DebtToken
        debtToken = new DebtToken("BUSD", "BUSD",
                                  addresses.stabilityPool,
                                  addresses.borrowerOps,
                                  babelCore,
                                  ZERO_ADDRESS, // LayerZero endpoint
                                  addresses.factory,
                                  users.gasPool,
                                  INIT_GAS_COMPENSATION);
        assertEq(addresses.debtToken, address(debtToken));

        // BorrowerOperations
        borrowerOps = new BorrowerOperations(addresses.core,
                                             addresses.debtToken,
                                             addresses.factory,
                                             INIT_MIN_NET_DEBT,
                                             INIT_GAS_COMPENSATION);
        assertEq(addresses.borrowerOps, address(borrowerOps));

        // StabilityPool
        stabilityPool = new StabilityPool(addresses.core,
                                          IDebtToken(addresses.debtToken),
                                          IBabelVault(addresses.babelVault),
                                          addresses.factory,
                                          addresses.liquidationMgr);
        assertEq(addresses.stabilityPool, address(stabilityPool));

        // TroveManager
        troveMgr = new TroveManager(addresses.core,
                                    users.gasPool,
                                    addresses.debtToken,
                                    addresses.borrowerOps,
                                    addresses.babelVault,
                                    addresses.liquidationMgr,
                                    INIT_GAS_COMPENSATION);
        assertEq(addresses.troveMgr, address(troveMgr));

        // TokenLocker
        tokenLocker = new TokenLocker(addresses.core,
                                      IBabelToken(addresses.babelToken),
                                      IIncentiveVoting(addresses.incentiveVoting),
                                      users.owner,
                                      INIT_LOCK_TO_TOKEN_RATIO);
        assertEq(addresses.tokenLocker, address(tokenLocker));

        // IncentiveVoting
        incentiveVoting = new IncentiveVoting(addresses.core,
                                              ITokenLocker(addresses.tokenLocker),
                                              addresses.babelVault);
        assertEq(addresses.incentiveVoting, address(incentiveVoting));

        // BabelToken
        babelToken = new BabelToken(addresses.babelVault,
                                    ZERO_ADDRESS, // LayerZero endpoint
                                    addresses.tokenLocker);
        assertEq(addresses.babelToken, address(babelToken));

        // BabelVault
        babelVault = new BabelVault(addresses.core,
                                    IBabelToken(addresses.babelToken),
                                    ITokenLocker(addresses.tokenLocker),
                                    IIncentiveVoting(addresses.incentiveVoting),
                                    addresses.stabilityPool,
                                    users.owner);
        assertEq(addresses.babelVault, address(babelVault));

        // use Factory to deploy new instances of `TroveManager` and `SortedTroves`
        // to add StakedBTC as valid collateral in the protocol
        IFactory.DeploymentParams memory params = IFactory.DeploymentParams({
            minuteDecayFactor : 999037758833783000,
            redemptionFeeFloor: 5e15,
            maxRedemptionFee: 1e18,
            borrowingFeeFloor: 0,
            maxBorrowingFee: 0,
            interestRateInBps: 0,
            maxDebt: 1_000_000e18, // 1M USD
            MCR: 2e18 // 200%
        });

        factory.deployNewInstance(address(stakedBTC), 
                                  addresses.priceFeed,
                                  ZERO_ADDRESS, // customTroveManagerImpl
                                  ZERO_ADDRESS, // customSortedTrovesImpl
                                  params);

        // 1 TroveManager deployed
        assertEq(1, factory.troveManagerCount());

        // create EmissionSchedule
        uint64[2][] memory scheduledWeeklyPct;
        emissionSchedule = new EmissionSchedule(address(babelCore), 
                                                IIncentiveVoting(address(incentiveVoting)),
                                                IBabelVault(address(babelVault)),
                                                INIT_ES_LOCK_WEEKS,
                                                INIT_ES_LOCK_DECAY_WEEKS,
                                                INIT_ES_WEEKLY_PCT,
                                                scheduledWeeklyPct);

        // create BoostCalculator
        boostCalc = new BoostCalculator(address(babelCore),
                                        ITokenLocker(address(tokenLocker)),
                                        INIT_BS_GRACE_WEEKS);

        // note: the hardhat script had some post deloyment actions
        // leaving them commented out for now unless we need them later
        //
        // Register new TroveManager with BabelVault to receive token emissions
        // address newTroveMsg = factory.troveManagers(0);
        // babelVault.registerReceiver(newTroveMsg, 2);
        // 
        // approve BorrowerOperations for 50 StakedBTC tokens
        // stakedBTC.approve(addresses.borrowerOps, 50e18);
        vm.stopPrank();

        // verify we are in the first week
        assertEq(tokenLocker.getWeek(), 0);
    }
}