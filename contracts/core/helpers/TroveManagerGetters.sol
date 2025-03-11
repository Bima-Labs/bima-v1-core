// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ITroveManager} from "../../interfaces/ITroveManager.sol";
import {IFactory} from "../../interfaces/IFactory.sol";

/*  Helper contract for grabbing Trove data for the front end. Not part of the core Bima system. */
contract TroveManagerGetters {
    struct Collateral {
        address collateral;
        address[] troveManagers;
    }

    IFactory public immutable factory;

    constructor(IFactory _factory) {
        factory = _factory;
    }

    /**
        @notice Returns all active system trove managers and collaterals, as an
        `       array of tuples of [(collateral, [troveManager, ...]), ...]
     */
    function getAllCollateralsAndTroveManagers() external view returns (Collateral[] memory collateralMap) {
        uint256 length = factory.troveManagerCount();
        address[2][] memory troveManagersAndCollaterals = new address[2][](length);
        address[] memory uniqueCollaterals = new address[](length);
        uint256 collateralCount;
        for (uint256 i; i < length; i++) {
            address troveManager = factory.troveManagers(i);
            address collateral = address(ITroveManager(troveManager).collateralToken());
            troveManagersAndCollaterals[i] = [troveManager, collateral];
            for (uint256 x; x < length; x++) {
                if (uniqueCollaterals[x] == collateral) break;
                if (uniqueCollaterals[x] == address(0)) {
                    uniqueCollaterals[x] = collateral;
                    collateralCount++;
                    break;
                }
            }
        }

        collateralMap = new Collateral[](collateralCount);
        for (uint256 i; i < collateralCount; i++) {
            collateralMap[i].collateral = uniqueCollaterals[i];
            uint256 tmCollCount;
            address[] memory troveManagers = new address[](length);
            for (uint256 x; x < length; x++) {
                if (troveManagersAndCollaterals[x][1] == uniqueCollaterals[i]) {
                    troveManagers[tmCollCount] = troveManagersAndCollaterals[x][0];
                    tmCollCount++;
                }
            }
            collateralMap[i].troveManagers = new address[](tmCollCount);
            for (uint256 x; x < tmCollCount; x++) {
                collateralMap[i].troveManagers[x] = troveManagers[x];
            }
        }
    }

    /**
        @notice Returns a list of trove managers where `account` has an existing trove
     */
    function getActiveTroveManagersForAccount(address account) external view returns (address[] memory troveManagers) {
        uint256 length = factory.troveManagerCount();
        troveManagers = new address[](length);
        uint256 tmCount;
        for (uint256 i; i < length; i++) {
            address troveManager = factory.troveManagers(i);

            if (ITroveManager(troveManager).getTroveStatus(account) != ITroveManager.Status.nonExistent) {
                troveManagers[tmCount] = troveManager;
                tmCount++;
            }
        }
        assembly {
            mstore(troveManagers, tmCount)
        }
    }
}
