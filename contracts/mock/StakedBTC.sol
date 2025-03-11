// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract StakedBTC is ERC20, ERC20Permit {
    constructor() ERC20("Bima Mock BTC", "bmBTC") ERC20Permit("Bima Mock BTC") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}
