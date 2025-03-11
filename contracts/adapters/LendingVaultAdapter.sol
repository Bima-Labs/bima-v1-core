// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {ILendingVaultAdapter} from "../interfaces/ILendingVaultAdapter.sol";
import {BimaOwnable} from "../dependencies/BimaOwnable.sol";

/// @title LendingVaultAdapter
/// @dev This contract will be used to move funds in and out from the forked Morpho Vault
/// @dev Making the DebtToken available to be borrowed against assets other then Bitcoin LSTs, with custom parameters
contract LendingVaultAdapter is ILendingVaultAdapter, BimaOwnable {
    /// @inheritdoc ILendingVaultAdapter
    IDebtToken public immutable underlying;

    /// @inheritdoc ILendingVaultAdapter
    IERC4626 public immutable vault;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param _bimaCore BimaCore contract address
    /// @param _underlyingAddress underlying asset contract address
    /// @param _vaultAddress LendingVault contract address
    constructor(address _bimaCore, address _underlyingAddress, address _vaultAddress) BimaOwnable(_bimaCore) {
        underlying = IDebtToken(_underlyingAddress);
        vault = IERC4626(_vaultAddress);
    }

    /// @inheritdoc ILendingVaultAdapter
    function deposit(uint256 assets) public onlyOwner {
        underlying.mint(address(this), assets);

        underlying.approve(address(vault), assets);

        vault.deposit(assets, address(this));

        emit Deposit(msg.sender, assets, block.timestamp);
    }

    /// @inheritdoc ILendingVaultAdapter
    function redeem(uint256 shares) public onlyOwner {
        uint256 initialBalance = underlying.balanceOf(address(this));

        vault.redeem(shares, address(this), address(this));

        uint256 receivedAmount = underlying.balanceOf(address(this)) - initialBalance;

        underlying.burn(address(this), receivedAmount);

        emit Redeem(msg.sender, shares, block.timestamp);
    }

    /// @inheritdoc ILendingVaultAdapter
    function recover(address _token) external onlyOwner {
        IERC20 token = IERC20(_token);

        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}
