// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBimaOwnable} from "./IBimaOwnable.sol";
import {IAggregatorV3Interface} from "./IAggregatorV3Interface.sol";

interface IPriceFeed is IBimaOwnable {
    function fetchPrice(address _token) external returns (uint256);

    function setOracle(
        address _token,
        address _chainlinkOracle,
        uint32 _heartbeat,
        bytes4 sharePriceSignature,
        uint8 sharePriceDecimals,
        bool _isEthIndexed
    ) external;

    function MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND() external view returns (uint256);

    function TARGET_DIGITS() external view returns (uint256);

    function oracleRecords(
        address
    )
        external
        view
        returns (
            IAggregatorV3Interface chainLinkOracle,
            uint8 decimals,
            uint32 heartbeat,
            bytes4 sharePriceSignature,
            uint8 sharePriceDecimals,
            bool isFeedWorking,
            bool isEthIndexed
        );

    function priceRecords(
        address
    ) external view returns (uint96 scaledPrice, uint32 timestamp, uint32 lastUpdated, uint80 roundId);
}
