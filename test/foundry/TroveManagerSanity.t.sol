// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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
    string public RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/CnYxxNH2dzg3KVHAlxUr6BuXwSgDi2dp";
    address public COLLATERAL_ADDRESS = 0xdc0CcAd18ca645A03870676C78a81524B4655197;
    address public TROVE_MANAGER_ADDRESS = 0x29467211aD35f97cea26ae11Da0c427836eC4C05;
    address public ORACLE_ADDRESS = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public BORROW_OPERATIONS_ADDRESS = 0x87FED36c032EE7289a1d2f3C48798e4C7fCDfAEc;
    address public PRICE_FEED_ADDRESS = 0x4B248F3646755F5b71A66BAe8C55C568809CbFf2;
    address public BIMA_FAUCET;

    function setUp() public {
        vm.createSelectFork(RPC_URL);
    }

    function testSanityFlow() public {
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

        assertEq(ITroveManager(TROVE_MANAGER_ADDRESS).debtToken().balanceOf(address(this)), 100_000e18);
        assertEq(IERC20(COLLATERAL_ADDRESS).balanceOf(address(this)), 0);
    }

    function test_simulation() public {
        address user = 0x3F3B0272cD337eb386F2596eD25351316A165809;

        vm.startPrank(user);

        assertEq(IERC20(COLLATERAL_ADDRESS).balanceOf(user), 0.0115e18);

        uint256 price = PriceFeed(PRICE_FEED_ADDRESS).fetchPrice(COLLATERAL_ADDRESS);

        // deal(COLLATERAL_ADDRESS, user, 1e18, true);
        // IERC20(COLLATERAL_ADDRESS).approve(BORROW_OPERATIONS_ADDRESS, 1e18);

        // // 76'262.650216790000000000

        console.log("Opening A Trove..");
        IBorrowerOperations(BORROW_OPERATIONS_ADDRESS).openTrove(
            ITroveManager(TROVE_MANAGER_ADDRESS),
            user,
            0.1e18,
            0.0115e18,
            257.032713930348240203e18,
            address(0),
            address(0)
        );
        console.log("Trove Opened..");

        assertEq(ITroveManager(TROVE_MANAGER_ADDRESS).getCurrentICR(user, price), 0);
    }

    function testFaucet() public {
        console.log("My Collateral Balance: ", IERC20(COLLATERAL_ADDRESS).balanceOf(address(this)));
        console.log("Getting Faucet..");
        BimaFaucet(BIMA_FAUCET).getTokens(COLLATERAL_ADDRESS);
        console.log("My Collateral Balance: ", IERC20(COLLATERAL_ADDRESS).balanceOf(address(this)));
    }
}
