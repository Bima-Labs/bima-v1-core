// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {IMorphoAdapter} from "../interfaces/IMorphoAdapter.sol";
import {BimaOwnable} from "../dependencies/BimaOwnable.sol";

contract MorphoAdapter is IMorphoAdapter, BimaOwnable {
    IDebtToken public underlying;
    IERC4626 public vault;

    constructor(address _bimaCore) BimaOwnable(_bimaCore) {}

    function setAddresses(address _underlyingAddress, address _vaultAddress) external onlyOwner {
        require(address(underlying) == address(0), "MorphoAdapter: addresses already set");

        underlying = IDebtToken(_underlyingAddress);
        vault = IERC4626(_vaultAddress);
    }

    function deposit(uint256 assets) public onlyOwner {
        underlying.mint(address(this), assets);

        underlying.approve(address(vault), assets);

        vault.deposit(assets, address(this));

        emit Deposit(msg.sender, assets, block.timestamp);
    }

    function redeem(uint256 shares) public onlyOwner {
        uint256 initialBalance = underlying.balanceOf(address(this));

        vault.redeem(shares, address(this), address(this));

        uint256 receivedAmount = underlying.balanceOf(address(this)) - initialBalance;

        underlying.burn(address(this), receivedAmount);

        emit Redeem(msg.sender, shares, block.timestamp);
    }

    function recover(address _token) external onlyOwner {
        IERC20 token = IERC20(_token);

        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}
