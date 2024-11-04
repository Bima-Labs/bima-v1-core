// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {StorkOracleWrapper, IStorkOracle} from "../../contracts/wrappers/StorkOracleWrapper.sol";
import {IAggregatorV3Interface} from "../../contracts/interfaces/IAggregatorV3Interface.sol";
import {PriceFeed} from "../../contracts/core/PriceFeed.sol";
import {IBorrowerOperations} from "../../contracts/interfaces/IBorrowerOperations.sol";
import {ITroveManager} from "../../contracts/interfaces/ITroveManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BimaFaucet} from "../../contracts/mock/BimaFaucet.sol";

// Quick test file to see if deployed TroveManager is working as expected.
// Run: forge test --match-path test/foundry/TroveManagerSanity.t.sol -vv
contract TroveManagerSanityTest is Test {
    StorkOracleWrapper public storkOracleWrapper;
    IStorkOracle public storkOracle;
    bytes32 public encodedAssetId;

    // Fill in with rpc and addresses you want to test on
    string public RPC_URL = "";
    address public COLLATERAL_ADDRESS;
    address public TROVE_MANAGER_ADDRESS;
    address public ORACLE_ADDRESS;
    address public BORROW_OPERATIONS_ADDRESS;
    address public PRICE_FEED_ADDRESS;
    address public BIMA_FAUCET;

    function setUp() public {
        vm.createSelectFork(RPC_URL);
    }

    function testFlow() public {
        console.log("Current Timestamp: ", block.timestamp);

        console.log("latestRoundData from IAggregatorV3Interface..");
        (uint80 roundId, int256 answer, , uint256 updatedAt, ) = IAggregatorV3Interface(ORACLE_ADDRESS)
            .latestRoundData();
        console.log(roundId);
        console.log(answer);
        console.log(updatedAt);

        console.log("fetchPrice from PriceFeed..");
        uint256 price = PriceFeed(PRICE_FEED_ADDRESS).fetchPrice(COLLATERAL_ADDRESS);
        console.log(price);

        console.log("Approve Collateral..");
        IERC20(COLLATERAL_ADDRESS).approve(BORROW_OPERATIONS_ADDRESS, 10e18);
        deal(COLLATERAL_ADDRESS, address(this), 10e18);
        console.log("My Collateral Balance: ", IERC20(COLLATERAL_ADDRESS).balanceOf(address(this)));

        console.log("Opening A Trove..");
        IBorrowerOperations(BORROW_OPERATIONS_ADDRESS).openTrove(
            ITroveManager(TROVE_MANAGER_ADDRESS),
            address(this),
            0.1e18,
            10e18,
            100_000e18,
            address(0),
            address(0)
        );
        console.log("Trove Opened..");

        console.log("My Collateral Balance: ", IERC20(COLLATERAL_ADDRESS).balanceOf(address(this)));
        console.log(
            "My Debt Token Balance: ",
            ITroveManager(TROVE_MANAGER_ADDRESS).debtToken().balanceOf(address(this))
        );
    }

    function testFaucet() public {
        console.log("My Collateral Balance: ", IERC20(COLLATERAL_ADDRESS).balanceOf(address(this)));
        console.log("Getting Faucet..");
        BimaFaucet(BIMA_FAUCET).getTokens(COLLATERAL_ADDRESS);
        console.log("My Collateral Balance: ", IERC20(COLLATERAL_ADDRESS).balanceOf(address(this)));
    }
}
