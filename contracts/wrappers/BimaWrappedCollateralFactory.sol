// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BimaWrappedCollateral} from "./BimaWrappedCollateral.sol";

import {BimaOwnable} from "../dependencies/BimaOwnable.sol";

contract BimaWrappedCollateralFactory is BimaOwnable {
    mapping(address collateral => address wrapped) public collToWrappedColl;
    mapping(address wrapped => address collateral) public wrappedCollToColl;

    constructor(address _bimaCore) BimaOwnable(_bimaCore) {}

    function createWrapper(
        address _token,
        string memory _name,
        string memory _symbol
    ) external onlyOwner returns (address _wrappedColl) {
        require(collToWrappedColl[_token] == address(0), "Wrapper already exists");

        _wrappedColl = address(new BimaWrappedCollateral(ERC20(_token), _name, _symbol));

        collToWrappedColl[_token] = _wrappedColl;
        wrappedCollToColl[_wrappedColl] = _token;
    }

    function getWrappedColl(IERC20 _collateral) external view returns (BimaWrappedCollateral _wrappedColl) {
        _wrappedColl = BimaWrappedCollateral(collToWrappedColl[address(_collateral)]);
    }

    function getColl(address _wrappedCollateral) external view returns (IERC20 _collateral) {
        _collateral = IERC20(wrappedCollToColl[_wrappedCollateral]);
    }
}
