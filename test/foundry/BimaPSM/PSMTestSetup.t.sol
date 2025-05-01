// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {TestSetup} from "../TestSetup.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BimaPSM} from "../../../contracts/BimaPSM.sol";

contract MockedERC20 is ERC20 {
    uint8 customDecimal;

    constructor(uint8 _decimal) ERC20("Mock USDT", "mUSDT") {
        customDecimal = _decimal;
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function decimals() public view override returns (uint8) {
        return customDecimal;
    }
}

contract PSMTestSetup is TestSetup {
    address user1 = makeAddr("USER 1");

    MockedERC20 underlying;
    BimaPSM psm;

    uint8 constant underlyingDecimals = 6;

    uint256 constant TRILLION_UNDERLYING = 1_000_000_000_000 * 10 ** underlyingDecimals;

    uint256 public initialUsbdLiquidity = 1_000_000_000_000_000e18;
    uint256 public initialUnderlyingLiquidity = TRILLION_UNDERLYING;

    function setUp() public virtual override {
        super.setUp();

        underlying = new MockedERC20(underlyingDecimals);

        psm = new BimaPSM(address(bimaCore), address(debtToken), address(underlying));

        // adding initial liquidity  to PSM
        vm.prank(users.owner);
        debtToken.authorizedMint(address(psm), initialUsbdLiquidity);
        underlying.mint(address(psm), initialUnderlyingLiquidity);
    }

    function test_constructor() external view {
        assertEq(address(psm.usbd()), address(debtToken));
        assertEq(address(psm.underlying()), address(underlying));
        assertEq(address(psm.owner()), bimaCore.owner());
        assertEq(psm.DECIMAL_DIFF(), debtToken.decimals() - underlyingDecimals);
        assertEq(psm.getUsbdLiquidity(), initialUsbdLiquidity);
        assertEq(psm.getUnderlyingLiquidity(), initialUnderlyingLiquidity);
    }
}
