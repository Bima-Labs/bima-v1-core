// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {DebtToken} from "./core/DebtToken.sol";

import {BimaOwnable} from "./dependencies/BimaOwnable.sol";

contract BimaPegStabilityModule is BimaOwnable {
    event BimaPegStabilityModule_GetUsbd(
        address indexed from,
        address indexed to,
        uint256 underlyingAmount,
        uint256 usbdAmount,
        uint256 timestamp
    );

    event BimaPegStabilityModule_Redeem(
        address indexed from,
        address indexed to,
        uint256 underlyingAmount,
        uint256 usbdAmount,
        uint256 timestamp
    );

    error BimaPegStabilityModule_NotEnoughLiquidty(address asset);

    DebtToken public immutable usbd;
    IERC20 public immutable underlying;

    uint8 public immutable DECIMAL_FACTOR;

    constructor(address _bimaCore, address _usbd, address _underlying) BimaOwnable(_bimaCore) {
        usbd = DebtToken(_usbd);
        underlying = IERC20(_underlying);

        DECIMAL_FACTOR = IERC20Metadata(address(underlying)).decimals();
    }

    function getUsbd(address _from, address _to, uint256 _underlyingAmount) external returns (uint256 usbdAmount) {
        uint256 balance = underlying.balanceOf(address(this));

        underlying.transferFrom(_from, address(this), _underlyingAmount);

        uint256 transferredUnderlyingAmount = underlying.balanceOf(address(this)) - balance;

        usbdAmount = _underlyingToUsbd(transferredUnderlyingAmount);

        if (usbd.balanceOf(address(this)) < usbdAmount) {
            revert BimaPegStabilityModule_NotEnoughLiquidty(address(usbd));
        }

        usbd.transfer(_to, usbdAmount);

        emit BimaPegStabilityModule_GetUsbd(_from, _to, _underlyingAmount, usbdAmount, block.timestamp);
    }

    function redeem(address _from, address _to, uint256 _underlyingAmount) external returns (uint256 usbdAmount) {
        usbdAmount = _underlyingToUsbd(_underlyingAmount);

        usbd.transferFrom(_from, address(this), usbdAmount);

        if (underlying.balanceOf(address(this)) < _underlyingAmount) {
            revert BimaPegStabilityModule_NotEnoughLiquidty(address(underlying));
        }

        underlying.transfer(_to, _underlyingAmount);

        emit BimaPegStabilityModule_Redeem(_from, _to, _underlyingAmount, usbdAmount, block.timestamp);
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
