// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {BimaMath} from "../../../contracts/dependencies/BimaMath.sol";

contract BimaMathTest is Test {
    uint256 internal constant MIN_BTC_PRICE_8DEC = 1_000 * 10 ** 8;
    uint256 internal constant MAX_BTC_PRICE_8DEC = 20_000_000 * 10 ** 8;

    function setUp() public {}

    function testFuzz_getAbsoluteDifference(uint256 _a, uint256 _b) public pure {
        _b = bound(_b, 0, _a);

        assertEq(BimaMath._getAbsoluteDifference(_a, _b), _a - _b);
        assertEq(BimaMath._getAbsoluteDifference(_b, _a), _a - _b);
        assertEq(BimaMath._getAbsoluteDifference(_b, _b), 0);
        assertEq(BimaMath._getAbsoluteDifference(_a, _a), 0);
    }

    function testFuzz_computeNominalCR(uint128 _coll, uint256 _debt) public pure {
        if (_debt > 0) {
            assertEq(BimaMath._computeNominalCR(_coll, _debt), (_coll * BimaMath.NICR_PRECISION) / _debt);
        } else {
            assertEq(BimaMath._computeNominalCR(_coll, _debt), 2 ** 256 - 1);
        }
    }

    function testFuzz_computeCR(uint128 _coll, uint256 _debt, uint256 _btcPrice) public pure {
        _btcPrice = bound(_btcPrice, MIN_BTC_PRICE_8DEC, MAX_BTC_PRICE_8DEC);

        if (_debt > 0) {
            assertEq(BimaMath._computeCR(_coll, _debt, _btcPrice), (_coll * _btcPrice) / _debt);
        } else {
            assertEq(BimaMath._computeCR(_coll, _debt, _btcPrice), 2 ** 256 - 1);
        }
    }

    function testFuzz_decPow_525600000_minutes(uint256 _base, uint256 _minutes) public pure {
        _minutes = bound(_minutes, 525600000, type(uint64).max);
        _base = bound(_base, 977159968434245000, 999931237762985000);

        assertEq(BimaMath._decPow(_base, 525600000), BimaMath._decPow(_base, _minutes));
    }
}
