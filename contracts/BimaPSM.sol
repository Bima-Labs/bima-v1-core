// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {DebtToken} from "./core/DebtToken.sol";

import {BimaOwnable} from "./dependencies/BimaOwnable.sol";

contract BimaPSM is BimaOwnable {
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

    error NotEnoughLiquidty(address asset, uint256 availableAmount, uint256 requestedAmount);

    DebtToken public immutable usbd;
    IERC20 public immutable underlying;

    uint8 public immutable DECIMAL_FACTOR;

    constructor(address _bimaCore, address _usbd, address _underlying) BimaOwnable(_bimaCore) {
        usbd = DebtToken(_usbd);
        underlying = IERC20(_underlying);

        DECIMAL_FACTOR = IERC20Metadata(address(underlying)).decimals();
    }

    function mint(address _from, address _to, uint256 _underlyingAmount) external returns (uint256 usbdAmount) {
        uint256 balance = underlying.balanceOf(address(this));

        underlying.transferFrom(_from, address(this), _underlyingAmount);

        uint256 transferredUnderlyingAmount = underlying.balanceOf(address(this)) - balance;

        usbdAmount = _underlyingToUsbd(transferredUnderlyingAmount);

        uint256 usbdBalanceOfPSM = usbd.balanceOf(address(this));
        if (usbdBalanceOfPSM < usbdAmount) {
            revert NotEnoughLiquidty(address(usbd),usbdBalanceOfPSM,_underlyingAmount);
        }

        usbd.transfer(_to, usbdAmount);

        emit Mint(_from, _to, _underlyingAmount, usbdAmount, block.timestamp);
    }

    function redeem(address _from, address _to, uint256 _underlyingAmount) external returns (uint256 usbdAmount) {
        usbdAmount = _underlyingToUsbd(_underlyingAmount);

        usbd.transferFrom(_from, address(this), usbdAmount);
        
        uint256 underlyingTokenBalanceOfPSM =underlying.balanceOf(address(this));
        if(underlyingTokenBalanceOfPSM < _underlyingAmount) {
            revert NotEnoughLiquidty(address(underlying),underlyingTokenBalanceOfPSM,_underlyingAmount);
        }

        underlying.transfer(_to, _underlyingAmount);

        emit Redeem(_from, _to, _underlyingAmount, usbdAmount, block.timestamp);
    }

    function underlyingToUsbd(uint256 _underlyingAmount) external view returns (uint256 usbdAmount) {
        return _underlyingToUsbd(_underlyingAmount);
    }

    function _underlyingToUsbd(uint256 _underlyingAmount) internal view returns (uint256 usbdAmount) {
        usbdAmount = _underlyingAmount * (10 ** (18 - DECIMAL_FACTOR));
    }

    function removeLiquidity(uint256 _usbdAmount) external onlyOwner {
        usbd.transfer(msg.sender, _usbdAmount);
    }
}
