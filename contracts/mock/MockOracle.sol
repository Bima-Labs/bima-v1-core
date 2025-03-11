// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IAggregatorV3Interface} from "../interfaces/IAggregatorV3Interface.sol";

contract MockOracle is IAggregatorV3Interface {
    uint80 public roundId;
    int256 public answer;
    uint256 public startedAt;
    uint256 public updatedAt;
    uint80 public answeredInRound;

    constructor() {
        roundId = 12345;
        answer = 60000 * 10 ** 8;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 12345;
    }

    function setResponse(
        uint80 _roundId,
        int256 _answer,
        uint256 _startedAt,
        uint256 _updatedAt,
        uint80 _answeredInRound
    ) external {
        roundId = _roundId;
        answer = _answer;
        startedAt = _startedAt;
        updatedAt = _updatedAt;
        answeredInRound = _answeredInRound;
    }

    function refresh() external {
        ++roundId;
        ++answeredInRound;
        updatedAt = block.timestamp;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external pure returns (string memory) {
        return "BTC / USD";
    }

    function version() external pure returns (uint256) {
        return 4;
    }

    function getRoundData(uint80 _roundId) external view returns (uint80, int256, uint256, uint256, uint80) {
        return (_roundId, answer, startedAt, updatedAt, _roundId);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
