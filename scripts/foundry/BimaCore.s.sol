// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// mocks
import {MockOracle} from "../../contracts/mock/MockOracle.sol";

// interfaces
import {IDebtToken} from "../../contracts/interfaces/IDebtToken.sol";
import {IStabilityPool} from "../../contracts/interfaces/IStabilityPool.sol";
import {IBorrowerOperations} from "../../contracts/interfaces/IBorrowerOperations.sol";
import {ILiquidationManager} from "../../contracts/interfaces/ILiquidationManager.sol";
import {IBabelVault, IRewards, IBoostDelegate} from "../../contracts/interfaces/IVault.sol";
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
import {GasPool} from "../../contracts/core/GasPool.sol";

// dao
import {FeeReceiver} from "../../contracts/dao/FeeReceiver.sol";
import {InterimAdmin} from "../../contracts/dao/InterimAdmin.sol";
import {TokenLocker} from "../../contracts/dao/TokenLocker.sol";
import {IncentiveVoting} from "../../contracts/dao/IncentiveVoting.sol";
import {BabelToken} from "../../contracts/dao/BabelToken.sol";
import {BabelVault, IEmissionReceiver} from "../../contracts/dao/Vault.sol";
import {EmissionSchedule} from "../../contracts/dao/EmissionSchedule.sol";
import {BoostCalculator} from "../../contracts/dao/BoostCalculator.sol";

// foundry
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

struct PredictedAddresses {
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

struct DeployedContracts {
  MockOracle mockAggregator;
  BabelCore babelCore;
  PriceFeed priceFeed;
  Factory factory;
  LiquidationManager liquidationMgr;
  DebtToken debtToken;
  BorrowerOperations borrowerOps;
  StabilityPool stabilityPool;
  TroveManager troveMgr;
  SortedTroves sortedTroves;
  GasPool gasPool;
  FeeReceiver feeReceiver;
  InterimAdmin interimAdmin;
  TokenLocker tokenLocker;
  IncentiveVoting incentiveVoting;
  BabelToken babelToken;
  BabelVault babelVault;
}

contract BimaCoreScript is Script, Test {
  uint256 internal constant GAS_COMPENSATION = 1e18;
  uint256 internal constant MIN_NET_DEBT = 1000e18;
  uint256 internal constant INIT_LOCK_TO_TOKEN_RATIO = 1e18;
  string internal constant DEBT_TOKEN_NAME = "US Bitcoin Dollar";
  string internal constant DEBT_TOKEN_SYMBOL = "USBD";

  address internal constant GUARDIAN = address(1);

  // contract constructors are inter-dependent so need to precalculate
  // some prAddresses to correctly initialize immutable storage variables
  PredictedAddresses internal prAddresses;

  // Avoiding stack too deep error
  DeployedContracts internal deployedContracts;

  function run() external {
    vm.startBroadcast();

    deployedContracts.mockAggregator = new MockOracle();

    uint256 nonce = vm.getNonce(msg.sender);

    prAddresses.feeReceiver = vm.computeCreateAddress(msg.sender, nonce + 1);
    prAddresses.priceFeed = vm.computeCreateAddress(msg.sender, nonce + 2);

    deployedContracts.babelCore = new BabelCore(msg.sender, GUARDIAN, prAddresses.priceFeed, prAddresses.feeReceiver);

    deployedContracts.feeReceiver = new FeeReceiver(address(deployedContracts.babelCore));
    assertEq(prAddresses.feeReceiver, address(deployedContracts.feeReceiver));

    deployedContracts.priceFeed = new PriceFeed(
      address(deployedContracts.babelCore),
      address(deployedContracts.mockAggregator)
    );
    assertEq(prAddresses.priceFeed, address(deployedContracts.priceFeed));

    deployedContracts.interimAdmin = new InterimAdmin(address(deployedContracts.babelCore));

    deployedContracts.babelCore.commitTransferOwnership(address(deployedContracts.interimAdmin));

    deployedContracts.gasPool = new GasPool();

    deployedContracts.sortedTroves = new SortedTroves();

    nonce = vm.getNonce(msg.sender);

    prAddresses.factory = vm.computeCreateAddress(msg.sender, nonce);
    prAddresses.liquidationMgr = vm.computeCreateAddress(msg.sender, nonce + 1);
    prAddresses.debtToken = vm.computeCreateAddress(msg.sender, nonce + 2);
    prAddresses.borrowerOps = vm.computeCreateAddress(msg.sender, nonce + 3);
    prAddresses.stabilityPool = vm.computeCreateAddress(msg.sender, nonce + 4);
    prAddresses.troveMgr = vm.computeCreateAddress(msg.sender, nonce + 5);
    prAddresses.tokenLocker = vm.computeCreateAddress(msg.sender, nonce + 6);
    prAddresses.incentiveVoting = vm.computeCreateAddress(msg.sender, nonce + 7);
    prAddresses.babelToken = vm.computeCreateAddress(msg.sender, nonce + 8);
    prAddresses.babelVault = vm.computeCreateAddress(msg.sender, nonce + 9);

    deployedContracts.factory = new Factory(
      address(deployedContracts.babelCore),
      IDebtToken(prAddresses.debtToken),
      IStabilityPool(prAddresses.stabilityPool),
      IBorrowerOperations(prAddresses.borrowerOps),
      address(deployedContracts.sortedTroves),
      prAddresses.troveMgr,
      ILiquidationManager(prAddresses.liquidationMgr)
    );
    assertEq(prAddresses.factory, address(deployedContracts.factory));

    deployedContracts.liquidationMgr = new LiquidationManager(
      IStabilityPool(prAddresses.stabilityPool),
      IBorrowerOperations(prAddresses.borrowerOps),
      prAddresses.factory,
      GAS_COMPENSATION
    );
    assertEq(prAddresses.liquidationMgr, address(deployedContracts.liquidationMgr));

    deployedContracts.debtToken = new DebtToken(
      DEBT_TOKEN_NAME,
      DEBT_TOKEN_SYMBOL,
      prAddresses.stabilityPool,
      prAddresses.borrowerOps,
      deployedContracts.babelCore,
      address(0),
      prAddresses.factory,
      address(deployedContracts.gasPool),
      GAS_COMPENSATION
    );
    assertEq(prAddresses.debtToken, address(deployedContracts.debtToken));

    deployedContracts.borrowerOps = new BorrowerOperations(
      address(deployedContracts.babelCore),
      prAddresses.debtToken,
      prAddresses.factory,
      MIN_NET_DEBT,
      GAS_COMPENSATION
    );
    assertEq(prAddresses.borrowerOps, address(deployedContracts.borrowerOps));

    deployedContracts.stabilityPool = new StabilityPool(
      address(deployedContracts.babelCore),
      IDebtToken(prAddresses.debtToken),
      IBabelVault(prAddresses.babelVault),
      prAddresses.factory,
      prAddresses.liquidationMgr
    );
    assertEq(prAddresses.stabilityPool, address(deployedContracts.stabilityPool));

    deployedContracts.troveMgr = new TroveManager(
      address(deployedContracts.babelCore),
      address(deployedContracts.gasPool),
      prAddresses.debtToken,
      prAddresses.borrowerOps,
      prAddresses.babelVault,
      prAddresses.liquidationMgr,
      GAS_COMPENSATION
    );
    assertEq(prAddresses.troveMgr, address(deployedContracts.troveMgr));

    deployedContracts.tokenLocker = new TokenLocker(
      address(deployedContracts.babelCore),
      IBabelToken(prAddresses.babelToken),
      IIncentiveVoting(prAddresses.incentiveVoting),
      msg.sender,
      INIT_LOCK_TO_TOKEN_RATIO
    );
    assertEq(prAddresses.tokenLocker, address(deployedContracts.tokenLocker));

    deployedContracts.incentiveVoting = new IncentiveVoting(
      address(deployedContracts.babelCore),
      ITokenLocker(prAddresses.tokenLocker),
      prAddresses.babelVault
    );
    assertEq(prAddresses.incentiveVoting, address(deployedContracts.incentiveVoting));

    deployedContracts.babelToken = new BabelToken(prAddresses.babelVault, address(0), prAddresses.tokenLocker);
    assertEq(prAddresses.babelToken, address(deployedContracts.babelToken));

    deployedContracts.babelVault = new BabelVault(
      address(deployedContracts.babelCore),
      IBabelToken(prAddresses.babelToken),
      ITokenLocker(prAddresses.tokenLocker),
      IIncentiveVoting(prAddresses.incentiveVoting),
      prAddresses.stabilityPool,
      msg.sender
    );
    assertEq(prAddresses.babelVault, address(deployedContracts.babelVault));

    vm.stopBroadcast();

    console.log("DONE");
  }
}
