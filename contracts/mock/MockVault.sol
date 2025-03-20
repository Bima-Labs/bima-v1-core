// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockVault is ERC4626 {
    constructor(IERC20 token) ERC4626(token) ERC20("Vault Share", "VLT") {}
}
