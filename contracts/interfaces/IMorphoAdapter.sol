// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IMorphoAdapter {
    event Deposit(address indexed signer, uint256 amount, uint256 timestamp);
    event Redeem(address indexed signer, uint256 amount, uint256 timestamp);

    function deposit(uint256 assets) external;

    function redeem(uint256 shares) external;

    function recover(address _token) external;
}
