// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DebtToken} from "../core/DebtToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBimaPSM {
    /// @notice Emitted when a user deposits underlying tokens and receives USBD tokens in return
    /// @param from Address that initiated the mint
    /// @param to Address that will receive USBD tokens
    /// @param underlyingAmount Amount of underlying tokens deposited
    /// @param usbdAmount Amount of USBD tokens transferred
    /// @param timestamp Timestamp of calling the mint function
    event Mint(
        address indexed from, address indexed to, uint256 underlyingAmount, uint256 usbdAmount, uint256 timestamp
    );

    /// @notice Emitted when a user redeems USBD tokens for underlying tokens
    /// @param from Address that initiated the redeem
    /// @param to   Address that will receive underlying tokens
    /// @param underlyingAmount  Amount of underlying tokens redeemed
    /// @param usbdAmount  Amount of USBD deposited for redeeming
    /// @param timestamp Timestamp of redeeming
    event Redeem(
        address indexed from, address indexed to, uint256 underlyingAmount, uint256 usbdAmount, uint256 timestamp
    );

    /// @notice Emitted when there is not enough liquidity in the PSM
    /// @param asset Address of the asset that has not enough liquidity
    /// @param availableAmount Amount of asset available in the PSM
    /// @param requestedAmount Amount of asset requested by the user
    error NotEnoughLiquidity(address asset, uint256 availableAmount, uint256 requestedAmount);

    /// @notice USBD token contract
    /// @return usbd
    function usbd() external returns (DebtToken usbd);

    /// @notice Underlying token contract
    /// @return underlying
    function underlying() external returns (IERC20 underlying);

    /// @notice Decimal numbers difference between the usbd and the underlying
    /// @dev Used for converting amounts between usbd and the underlying
    /// @return decimalDiff
    function DECIMAL_DIFF() external returns (uint256 decimalDiff);

    /// @notice Deposit underlying token and receive exact amount of USBD tokens in return 1:1
    /// @param _to Address that will receive USBD tokens
    /// @param _underlyingAmount Amount of underlying tokens to deposit
    /// @return usbdAmount Amount of USBD  transferred to the receiver
    function mint(address _to, uint256 _underlyingAmount) external returns (uint256 usbdAmount);

    /// @notice Deposit USBD and receive exact amount of underlying tokens in return 1:1
    /// @param _to Address that will receive underlying tokens
    /// @param _underlyingAmount Amount of underlying tokens user wants to get
    /// @return usbdAmount Amount of USBD tokens to be redeemed
    function redeem(address _to, uint256 _underlyingAmount) external returns (uint256 usbdAmount);

    /// @notice Convert underlying amount to USBD amount
    /// @param _underlyingAmount Amount of underlying tokens to be converted
    /// @return usbdAmount The amount of USBD for the given underlying amount
    function underlyingToUsbd(uint256 _underlyingAmount) external returns (uint256 usbdAmount);

    /// @notice Convert USBD amount to underlying amount
    /// @param _usbdAmount Amount of USBD to be converted
    /// @return underlyingAmount Amount of underlying amount for the given USBD amount
    function usbdToUnderlying(uint256 _usbdAmount) external returns (uint256 underlyingAmount);

    /// @notice Get the amount of USBD liquidity in the PSM
    /// @return liquidity The amount of USBD liquidity in the PSM
    function getUsbdLiquidity() external returns (uint256 liquidity);

    /// @notice Get the amount of underlying token liquidity in the PSM
    /// @return liquidity The amount of underlying token liquidity in the PSM
    function getUnderlyingLiquidity() external returns (uint256 liquidity);

    /// @notice Remove liquidity from the PSM
    /// @dev only Owner can call this function
    /// @param _usbdAmount Amount of USBD to be removed
    function removeLiquidity(uint256 _usbdAmount) external;
}
