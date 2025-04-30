// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DebtToken} from "../../../../contracts/core/DebtToken.sol";
import {BimaPSM} from "../../../../contracts/BimaPSM.sol";
import {TestSetup} from "../../TestSetup.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

pragma solidity 0.8.20;

contract UnderlyingToken is ERC20, ERC20Permit {
    uint8 customDecimal;

    constructor(uint8 _decimal) ERC20("Mock USDT", "mUSDT") ERC20Permit("Bima Mock BTC") {
        customDecimal = _decimal;
        _mint(msg.sender, 1000000000000 * 10 ** decimals());
    }

    function decimals() public view override returns (uint8) {
        return customDecimal;
    }
}

contract TestSetUpPSM is TestSetup {
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
    uint8 customTokenDecimal = 15;
    // owner providing initial liquidity
    uint256 public initialLiquidity = 100000000000000000000000000000000000000000000e18;
    uint256 public initalMintToUser = 1000000000000 * 10 ** customTokenDecimal;

    function setUp() public virtual override {
        super.setUp();
        vm.startPrank(USER);
        //8 decimal, minting intial amount of token to USER
        mockUnderlyingToken = new UnderlyingToken(customTokenDecimal);
        vm.stopPrank();

        vm.startPrank(users.owner);
        psm = new BimaPSM(address(bimaCore), address(debtToken), address(mockUnderlyingToken));

        // adding initial liquidity  to PSM
        debtToken.authorizedMint(address(psm), initialLiquidity);
        vm.stopPrank();
    }
}
