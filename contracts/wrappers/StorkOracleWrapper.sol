// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IAggregatorV3Interface} from "../interfaces/IAggregatorV3Interface.sol";

interface IStorkOracle {
    function getTemporalNumericValueV1(
        bytes32 id
    )
        external
        view
        returns (
            // nanosecond level precision timestamp of latest publisher update in batch
            uint64 timestampNs,
            // should be able to hold all necessary numbers (up to 6277101735386680763835789423207666416102355444464034512895)
            int192 quantizedValue
        );
}

/// @title Oracle Wrapper for Stork Oracle
/// @notice More Info on Stork: https://docs.stork.network/
contract StorkOracleWrapper is IAggregatorV3Interface {
    uint8 public constant DECIMAL_PRECISION = 18;

    IStorkOracle public immutable storkOracle;
    bytes32 public immutable encodedAssetId;

    /// @param _storkOracle Stork on-chain oracle address
    /// @param _encodedAssetId Id of the specific price feed (Retrieved from Stork off chain feed)
    constructor(address _storkOracle, bytes32 _encodedAssetId) {
        storkOracle = IStorkOracle(_storkOracle);
        encodedAssetId = _encodedAssetId;

        // Check if the oracle is alive
        storkOracle.getTemporalNumericValueV1(encodedAssetId);
    }

    function decimals() external pure returns (uint8 dec) {
        // stork oracle always reports prices in 18 decimal precision
        dec = DECIMAL_PRECISION;
    }

    function description() external pure returns (string memory desc) {
        desc = "AggregatorV3Interface Wrapper for Stork Oracle";
    }

    function version() external pure returns (uint256 ver) {
        ver = 1;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint64 timestampNs, int192 quantizedValue) = storkOracle.getTemporalNumericValueV1(encodedAssetId);

        answer = int256(quantizedValue);
        updatedAt = timestampNs / 1e9 - 1 seconds;
        startedAt = updatedAt;
        roundId = _roundId;
        answeredInRound = _roundId;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint64 timestampNs, int192 quantizedValue) = storkOracle.getTemporalNumericValueV1(encodedAssetId);

        answer = int256(quantizedValue);
        updatedAt = timestampNs / 1e9;
        startedAt = updatedAt;
        roundId = uint80(updatedAt / 1 seconds); // increment round every second
        answeredInRound = roundId;
    }
}
