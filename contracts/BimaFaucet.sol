// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BimaFaucet {
  uint256 public constant TOKEN_AMOUNT = 2e18;
  uint256 public constant INTERVAL = 1 days;

  mapping(address => mapping(address => uint256)) public tokensRecievedAt; // account => token => timestamp

  function getTokens(address _tokenAddress) external {
    require(tokensRecievedAt[msg.sender][_tokenAddress] + INTERVAL < block.timestamp);

    IERC20(_tokenAddress).transfer(msg.sender, TOKEN_AMOUNT);

    tokensRecievedAt[msg.sender][_tokenAddress] = block.timestamp;
  }
}
