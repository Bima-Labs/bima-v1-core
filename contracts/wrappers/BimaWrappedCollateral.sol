// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BimaWrappedCollateral is ERC20 {
    ERC20 public immutable underlyingCollateral;

    uint256 private immutable DECIMAL_DIFF;

    constructor(ERC20 _underlyingCollateral, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        underlyingCollateral = ERC20(_underlyingCollateral);

        DECIMAL_DIFF = 18 - underlyingCollateral.decimals();
    }

    function wrap(uint256 _underlyingAmount) external returns (uint256 _wrappedAmount) {
        underlyingCollateral.transferFrom(msg.sender, address(this), _underlyingAmount);

        _wrappedAmount = previewWrappedAmount(_underlyingAmount);

        _mint(msg.sender, _wrappedAmount);
    }

    function unwrap(uint256 _wrappedAmount) external returns (uint256 _underlyingAmount) {
        _burn(msg.sender, _wrappedAmount);

        _underlyingAmount = previewUnwrappedAmount(_wrappedAmount);

        underlyingCollateral.transfer(msg.sender, _underlyingAmount);
    }

    function previewWrappedAmount(uint256 _underlyingAmount) public view returns (uint256 _wrappedAmount) {
        _wrappedAmount = _underlyingAmount * 10 ** DECIMAL_DIFF;
    }

    function previewUnwrappedAmount(uint256 _wrappedAmount) public view returns (uint256 _underlyingAmount) {
        _underlyingAmount = _wrappedAmount / (10 ** DECIMAL_DIFF);
    }
}
