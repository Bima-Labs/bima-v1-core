// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IDelegatedOps {
    function isApprovedDelegate(address owner, address caller) external view returns (bool isApproved);

    function setDelegateApproval(address _delegate, bool _isApproved) external;
}
