// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IBimaPSM {
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

    error NotEnoughLiquidity(address asset, uint256 availableAmount, uint256 requestedAmount);

    function mint(address _to, uint256 _underlyingAmount) external returns (uint256 usbdAmount);

    function redeem(address _to, uint256 _underlyingAmount) external returns (uint256 usbdAmount);

    function underlyingToUsbd(uint256 _underlyingAmount) external returns (uint256 usbdAmount);

    function usbdToUnderlying(uint256 _usbdAmount) external returns (uint256 underlyingAmount);

    function getUsbdLiquidity() external returns (uint256 liquidity);

    function getUnderlyingLiquidity() external returns (uint256 liquidity);

    function removeLiquidity(uint256 _usbdAmount) external;
}
