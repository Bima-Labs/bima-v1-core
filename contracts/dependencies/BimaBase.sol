// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBimaBase} from "../interfaces/IBimaBase.sol";
import {BIMA_DECIMAL_PRECISION} from "./Constants.sol";

/*
 * Base contract for TroveManager, BorrowerOperations and StabilityPool. Contains global system constants and
 * common functions.
 */
contract BimaBase is IBimaBase {
    // Critical Collateral Ratio
    // If the system's total collateral ratio (TCR) falls
    // below the CCR, Recovery Mode is triggered
    uint256 public constant CCR = 1.6e18; // 160%

    // Amount of debt to be locked in gas pool on opening troves
    uint256 public immutable DEBT_GAS_COMPENSATION;

    uint256 public constant PERCENT_DIVISOR = 200; // dividing by 200 yields 0.5%

    constructor(uint256 _gasCompensation) {
        DEBT_GAS_COMPENSATION = _gasCompensation;
    }

    // --- Gas compensation functions ---

    // Returns the composite debt (drawn debt + gas compensation) of a trove, for the purpose of ICR calculation
    function _getCompositeDebt(uint256 _debt) internal view returns (uint256 result) {
        result = _debt + DEBT_GAS_COMPENSATION;
    }

    function _getNetDebt(uint256 _debt) internal view returns (uint256 result) {
        result = _debt - DEBT_GAS_COMPENSATION;
    }

    // Return the amount of collateral to be drawn from a trove's collateral and sent as gas compensation.
    function _getCollGasCompensation(uint256 _entireColl) internal pure returns (uint256 result) {
        result = _entireColl / PERCENT_DIVISOR;
    }

    function _requireUserAcceptsFee(uint256 _fee, uint256 _amount, uint256 _maxFeePercentage) internal pure {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 feePercentage = (_fee * BIMA_DECIMAL_PRECISION) / _amount;
        require(feePercentage <= _maxFeePercentage, "Fee exceeded provided maximum");
    }
}
