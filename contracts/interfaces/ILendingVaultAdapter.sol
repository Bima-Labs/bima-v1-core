// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface ILendingVaultAdapter {
    event Deposit(address indexed signer, uint256 amount, uint256 timestamp);
    event Redeem(address indexed signer, uint256 amount, uint256 timestamp);

    /// @notice The address of the underlying token contract.
    function underlying() external view returns (IDebtToken);

    /// @notice The address of the vault contract.
    function vault() external view returns (IERC4626);

    /// @notice Mints `assets` amount of `underlying` tokens and deposits them into the vault.
    function deposit(uint256 assets) external;

    /// @notice Redeems `shares` amount of vault shares and burns them immediately.
    /// @dev Always making sure any `underlying` tokens received by the vault are burned and not held
    function redeem(uint256 shares) external;

    /// @notice Recovers any ERC20 tokens held by a contract
    function recover(address _token) external;
}
