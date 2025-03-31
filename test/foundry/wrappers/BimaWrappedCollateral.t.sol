pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import {StakedBTC} from "../../../contracts/mock/StakedBTC.sol";
import {BimaWrappedCollateral} from "../../../contracts/wrappers/BimaWrappedCollateral.sol";

import {TestSetup} from "../TestSetup.sol";

contract BimaWrappedCollateralTest is TestSetup {
    StakedBTC stbtc;
    BimaWrappedCollateral bmc;

    function setUp() public virtual override {
        super.setUp();

        stbtc = new StakedBTC();
        bmc = new BimaWrappedCollateral(stbtc, "test", "test");
    }

    function test_wrapAndOpenTrove() external {}
}
