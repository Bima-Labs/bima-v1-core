// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/IAggregatorV3Interface.sol";

contract MockOracle is IAggregatorV3Interface {
    function decimals() external view returns (uint8) {
        return 8;
    }

    function description() external view returns (string memory) {
        return "BTC / USD";
    }

    function version() external view returns (uint256) {
        return 4;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        // Return round id equal to the input round id
        // Return answer equal to 60000
        // Started at should be block.timestamp - 1 day
        // Updated at should be block.timestamp
        // Answered in round should be 0
        return (_roundId, 60000 * 10 ** 8, block.timestamp - 1 days, block.timestamp - 1 days, _roundId);
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (12345, 60000 * 10 ** 8, block.timestamp, block.timestamp, 12345);
    }
}
