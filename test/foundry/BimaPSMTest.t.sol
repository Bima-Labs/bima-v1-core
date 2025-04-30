// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import {DebtToken} from "../../contracts/core/DebtToken.sol";
import {BimaPSM} from "../../contracts/BimaPSM.sol";
import {IBimaPSM} from "../../contracts/IBimaPSM.sol";

import {TestSetup} from "./TestSetup.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

pragma solidity 0.8.20;

contract UnderlyingToken is ERC20, ERC20Permit {
    constructor() ERC20("Mock USDT", "mUSDT") ERC20Permit("Bima Mock BTC") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }
}

contract BimaPSMTest is TestSetup {
    /**
     * Events
     */
    event Mint(
        address indexed from,
        address indexed to,
        uint256 underlyingAmount,
        uint256 usbdAmount,
        uint256 timestamp
    );

    event Redeem(
        address indexed from,
        address indexed to,
        uint256 underlyingAmount,
        uint256 usbdAmount,
        uint256 timestamp
    );

    address USER = makeAddr("USER 1");
    UnderlyingToken mockUnderlyingToken;
    BimaPSM psm;

    // owner providing initial liquidity
    uint256 public initialLiquidity = 10000e18;
    uint256 public initalMintToUser = 1000000e8;

    function setUp() public virtual override {
        super.setUp();
        vm.startPrank(USER);
        //8 decimal, minting intial amount of token to USER
        mockUnderlyingToken = new UnderlyingToken();
        vm.stopPrank();

        vm.startPrank(users.owner);
        psm = new BimaPSM(address(bimaCore), address(debtToken), address(mockUnderlyingToken));

        // adding initial liquidity  to PSM
        debtToken.authorizedMint(address(psm), initialLiquidity);
        vm.stopPrank();
    }

    /**
     * DECIMAL_FACTOR
     */
    function test_decimalFactor() public view {
        uint256 decimalFactor = 8;
        uint256 expectedDecimalFactor = psm.DECIMAL_FACTOR();
        assertEq(decimalFactor, expectedDecimalFactor);
    }

    /**
     * Mint
     */

    function test_Mint() public {
        uint256 underlyingtDepositAmount = 1000e8;

        vm.startPrank(USER);
        // approving  mUSDT
        mockUnderlyingToken.approve(address(psm), underlyingtDepositAmount);

        vm.expectEmit(true, true, false, true);
        emit Mint(USER, USER, underlyingtDepositAmount, 1000e18, block.timestamp);
        psm.mint(USER, USER, underlyingtDepositAmount);

        vm.stopPrank();

        /**
         * USBD balanceOf User - underlyingAmount(in decimal 18)
         *                Contract - initial deposit - underlyingAmount
         *
         * mUSDT balanceof User - initalMintToUser - underlyingAmount
         *                 Contract - underlyingAmount
         */
        uint256 psmUsbd = debtToken.balanceOf(address(psm));
        uint256 psmMusdt = mockUnderlyingToken.balanceOf(address(psm));

        uint256 userUsbd = debtToken.balanceOf(USER);
        uint256 userMusdt = mockUnderlyingToken.balanceOf(USER);

        assertEq(psmUsbd, initialLiquidity - 1000e18);
        assertEq(psmMusdt, underlyingtDepositAmount);
        assertEq(userUsbd, 1000e18);
        assertEq(userMusdt, initalMintToUser - underlyingtDepositAmount);
    }

    function test_Mint_NotEnoughLiquidty() public {
        uint256 amountToDeposit = 100000e8;

        vm.startPrank(USER);
        mockUnderlyingToken.approve(address(psm), amountToDeposit);
        uint256 usbdBalanceOfPSM = debtToken.balanceOf(address(psm));
        vm.expectRevert(
            abi.encodeWithSelector(
                IBimaPSM.NotEnoughLiquidty.selector,
                address(debtToken),
                usbdBalanceOfPSM,
                amountToDeposit
            )
        );
        psm.mint(USER, USER, amountToDeposit);
        vm.stopPrank();
    }

    /**
     * Redeem
     */

    function test_Redeem() external {
        //deposit
        uint256 underlyingtDepositAmount = 1000e8;

        vm.startPrank(USER);
        mockUnderlyingToken.approve(address(psm), underlyingtDepositAmount);
        psm.mint(USER, USER, underlyingtDepositAmount);
        vm.stopPrank();

        // // redeem
        vm.startPrank(USER);
        debtToken.approve(address(psm), 1000e18);
        vm.expectEmit(true, true, false, true);
        emit Redeem(USER, USER, underlyingtDepositAmount, 1000e18, block.timestamp);
        psm.redeem(USER, USER, underlyingtDepositAmount);
        vm.stopPrank();

        /**
         * USBD balanceOf User - 0
         *                Contract - initial deposit
         *
         * mUSDT balanceof User - initalMintToUser
         *                 Contract - 0
         */
        uint256 psmUsbd = debtToken.balanceOf(address(psm));
        uint256 psmMusdt = mockUnderlyingToken.balanceOf(address(psm));

        uint256 userUsbd = debtToken.balanceOf(USER);
        uint256 userMusdt = mockUnderlyingToken.balanceOf(USER);

        assertEq(psmUsbd, initialLiquidity);
        assertEq(psmMusdt, 0);
        assertEq(userUsbd, 0);
        assertEq(userMusdt, initalMintToUser);
    }

    function test_Redeem_NotEnoughLiquidty() public {
        vm.startPrank(users.owner);
        debtToken.authorizedMint(USER, 100000e18);
        vm.stopPrank();

        uint256 userUsbdBalance = debtToken.balanceOf(USER);
        assertEq(userUsbdBalance, 100000e18);

        vm.startPrank(USER);
        debtToken.approve(address(psm), 100000e18);

        uint256 underlyingTokenBalanceOfPSM = mockUnderlyingToken.balanceOf(address(psm));
        vm.expectRevert(
            abi.encodeWithSelector(
                IBimaPSM.NotEnoughLiquidty.selector,
                address(mockUnderlyingToken),
                underlyingTokenBalanceOfPSM,
                100000e8
            )
        );
        psm.redeem(USER, USER, 100000e8);
        vm.stopPrank();
    }

    /**
     * Remove Liquidity
     */

    function test_RemoveLiquidity() public {
        uint256 amount = 1000e18;
        // removing a portion of liquidity
        vm.startPrank(users.owner);
        psm.removeLiquidity(amount);
        vm.stopPrank();

        uint256 psmUsbd = debtToken.balanceOf(address(psm));
        assertEq(psmUsbd, initialLiquidity - 1000e18);
    }

    // Non owner cannot remove liquidity
    function test_RemoveLiquidity_Revert_Non_Owner() external {
        uint256 amount = 1000e18;
        vm.expectRevert();
        psm.removeLiquidity(amount);
    }

    /**
     * Underlying To Usbd
     */
    function test_UnderlyingToUsbd() external view {
        uint256 underlyingAmount = 1e8;
        uint256 expectedUsbd = 1e18;
        uint256 usbdAmount = psm.underlyingToUsbd(underlyingAmount);
        assertEq(usbdAmount, expectedUsbd);
    }
}
