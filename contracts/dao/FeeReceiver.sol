// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BimaOwnable} from "../dependencies/BimaOwnable.sol";

contract FeeReceiver is BimaOwnable {
    using SafeERC20 for IERC20;

    constructor(address _bimaCore) BimaOwnable(_bimaCore) {}

    function transferToken(IERC20 token, address receiver, uint256 amount) external onlyOwner {
        token.safeTransfer(receiver, amount);
    }

    function setTokenApproval(IERC20 token, address spender, uint256 amount) external onlyOwner {
        token.safeApprove(spender, amount);
    }
}
