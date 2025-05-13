// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBimaPSM} from "./interfaces/IBimaPSM.sol";
import {BimaOwnable} from "./dependencies/BimaOwnable.sol";
import {DebtToken} from "./core/DebtToken.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BimaPSM is IBimaPSM, BimaOwnable {
    using SafeERC20 for IERC20;

    DebtToken public immutable usbd;
    IERC20 public immutable underlying;

    uint256 public immutable DECIMAL_DIFF;

    constructor(address _bimaCore, address _usbd, address _underlying) BimaOwnable(_bimaCore) {
        usbd = DebtToken(_usbd);
        underlying = IERC20(_underlying);

        DECIMAL_DIFF = 10 ** (usbd.decimals() - IERC20Metadata(_underlying).decimals());
    }

    // ========== MINT/REDEEM FUNCTIONS ========== //

    /// @inheritdoc IBimaPSM
    function mint(address _to, uint256 _underlyingAmount) external returns (uint256 usbdAmount) {
        uint256 balance = underlying.balanceOf(address(this));

        underlying.safeTransferFrom(msg.sender, address(this), _underlyingAmount);

        uint256 transferredUnderlyingAmount = underlying.balanceOf(address(this)) - balance;

        usbdAmount = _underlyingToUsbd(transferredUnderlyingAmount);

        uint256 usbdLiquidity = usbd.balanceOf(address(this));

        if (usbdLiquidity < usbdAmount) revert NotEnoughLiquidity(address(usbd), usbdLiquidity, usbdAmount);

        usbd.transfer(_to, usbdAmount);

        emit Mint(msg.sender, _to, _underlyingAmount, usbdAmount, block.timestamp);
    }

    /// @inheritdoc IBimaPSM
    function redeem(address _to, uint256 _underlyingAmount) external returns (uint256 usbdAmount) {
        usbdAmount = _underlyingToUsbd(_underlyingAmount);

        usbd.transferFrom(msg.sender, address(this), usbdAmount);

        uint256 underlyingLiquidity = underlying.balanceOf(address(this));

        if (underlyingLiquidity < _underlyingAmount) {
            revert NotEnoughLiquidity(address(underlying), underlyingLiquidity, _underlyingAmount);
        }

        underlying.safeTransfer(_to, _underlyingAmount);

        emit Redeem(msg.sender, _to, _underlyingAmount, usbdAmount, block.timestamp);
    }

    // ========== VIEW FUNCTIONS ========== //

    /// @inheritdoc IBimaPSM
    function underlyingToUsbd(uint256 _underlyingAmount) external view returns (uint256 usbdAmount) {
        return _underlyingToUsbd(_underlyingAmount);
    }

    /// @inheritdoc IBimaPSM
    function usbdToUnderlying(uint256 _usbdAmount) external view returns (uint256 underlyingAmount) {
        underlyingAmount = _usbdAmount / DECIMAL_DIFF;
    }

    /// @inheritdoc IBimaPSM
    function getUsbdLiquidity() external view returns (uint256 liquidity) {
        liquidity = usbd.balanceOf(address(this));
    }

    /// @inheritdoc IBimaPSM
    function getUnderlyingLiquidity() external view returns (uint256 liquidity) {
        liquidity = underlying.balanceOf(address(this));
    }

    // ========== INTERNAL FUNCTIONS ========== //

    function _underlyingToUsbd(uint256 _underlyingAmount) internal view returns (uint256 usbdAmount) {
        usbdAmount = _underlyingAmount * DECIMAL_DIFF;
    }

    // ========== OWNER FUNCTIONS ========== //

    /// @inheritdoc IBimaPSM
    function removeLiquidity(uint256 _usbdAmount) external onlyOwner {
        usbd.transfer(msg.sender, _usbdAmount);
    }
}
