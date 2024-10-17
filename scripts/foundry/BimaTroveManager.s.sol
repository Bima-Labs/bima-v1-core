// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {PriceFeed} from "../../contracts/core/PriceFeed.sol";
import {Factory, IFactory} from "../../contracts/core/Factory.sol";
import {BabelVault} from "../../contracts/dao/Vault.sol";
import {IAggregatorV3Interface} from "../../contracts/interfaces/IAggregatorV3Interface.sol";

// foundry
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract BimaTroveManagerScript is Script, Test {
  address internal constant ZERO_ADDRESS = address(0);

  // FILL IN WITH YOUR TARGET ADDRESSES
  address internal constant COLLATERAL_ADDRESS;
  address internal constant FACTORY_ADDRESS;
  address internal constant PRICEFEED_ADDRESS;
  address internal constant BABELVAULT_ADDRESS;
  address internal constant ORACLE_ADDRESS;

  uint32 internal constant HEARTBEAT = 80_000;

  // TroveManager Options
  uint256 internal constant MCR = 2e18; // 200%
  uint256 internal constant MINUTE_DECAY_FACTOR = 999037758833783000;
  uint256 internal constant MAX_DEBT = 1_000_000e18; // 1M USBD
  uint256 internal constant REDEMPTION_FEE_FLOOR = 5e15;
  uint256 internal constant MAX_REDEMPTION_FEE = 1e18;
  uint256 internal constant BORROWING_FEE_FLOOR = 0;
  uint256 internal constant MAX_BORROWING_FEE = 0;
  uint256 internal constant INTEREST_RATE_BPS = 0;

  function run() external {
    vm.startBroadcast();

    console.log(Factory(FACTORY_ADDRESS).troveManagerCount());

    PriceFeed(PRICEFEED_ADDRESS).setOracle(
      COLLATERAL_ADDRESS,
      ORACLE_ADDRESS,
      HEARTBEAT,
      bytes4(0x00000000),
      IAggregatorV3Interface(ORACLE_ADDRESS).decimals(),
      false
    );

    Factory(FACTORY_ADDRESS).deployNewInstance(
      COLLATERAL_ADDRESS,
      PRICEFEED_ADDRESS,
      ZERO_ADDRESS,
      ZERO_ADDRESS,
      IFactory.DeploymentParams({
        minuteDecayFactor: MINUTE_DECAY_FACTOR,
        redemptionFeeFloor: REDEMPTION_FEE_FLOOR,
        maxRedemptionFee: MAX_REDEMPTION_FEE,
        borrowingFeeFloor: BORROWING_FEE_FLOOR,
        maxBorrowingFee: MAX_BORROWING_FEE,
        interestRateInBps: INTEREST_RATE_BPS,
        maxDebt: MAX_DEBT,
        MCR: MCR
      })
    );

    uint256 tmCountAfter = Factory(FACTORY_ADDRESS).troveManagerCount();
    console.log(tmCountAfter);

    address newTroveManagerAddress = Factory(FACTORY_ADDRESS).troveManagers(tmCountAfter - 1);

    BabelVault(BABELVAULT_ADDRESS).registerReceiver(newTroveManagerAddress, 2);

    vm.stopBroadcast();

    console.log("DONE");
  }
}
