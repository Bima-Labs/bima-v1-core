// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IEmissionReceiver {
    function notifyRegisteredId(uint256[] calldata assignedIds) external returns (bool);
}
