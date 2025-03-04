// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BimaFaucet is Ownable {
    uint256 public tokenAmount = 2e18;
    uint256 public constant INTERVAL = 1 days;

    mapping(address => mapping(address => uint256)) public tokensRecievedAt; // account => token => timestamp

    function getTokens(address _tokenAddress) external {
        require(tokensRecievedAt[msg.sender][_tokenAddress] + INTERVAL < block.timestamp);

        IERC20(_tokenAddress).transfer(msg.sender, tokenAmount);

        tokensRecievedAt[msg.sender][_tokenAddress] = block.timestamp;
    }

    function recoverTokens(address _tokenAddress) external onlyOwner {
        IERC20(_tokenAddress).transfer(msg.sender, IERC20(_tokenAddress).balanceOf(address(this)));
    }

    function updateTokenAmount(uint256 _newTokenAmount) external onlyOwner {
        require(_newTokenAmount > 0);
        tokenAmount = _newTokenAmount;
    }
}
