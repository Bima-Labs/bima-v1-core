// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBimaOwnable} from "./IBimaOwnable.sol";
import {ITroveManager} from "./ITroveManager.sol";
import {IDebtToken} from "./IDebtToken.sol";
import {IBimaBase} from "./IBimaBase.sol";
import {IDelegatedOps} from "./IDelegatedOps.sol";

interface IBorrowerOperations is IBimaOwnable, IBimaBase, IDelegatedOps {
    enum BorrowerOperation {
        openTrove,
        closeTrove,
        adjustTrove
    }

    struct SystemBalances {
        uint256[] collaterals;
        uint256[] debts;
        uint256[] prices;
    }

    event BorrowingFeePaid(address indexed borrower, IERC20 collateralToken, uint256 amount);
    event CollateralConfigured(ITroveManager, IERC20 collateralToken);
    event TroveCreated(address indexed _borrower, uint256 arrayIndex);
    event TroveManagerRemoved(ITroveManager);
    event TroveUpdated(
        address indexed _borrower,
        uint256 _debt,
        uint256 _coll,
        uint256 stake,
        BorrowerOperation operation
    );
    event SetMinNetDebt(uint256 newMinNetDebt);

    function addColl(
        ITroveManager troveManager,
        address account,
        uint256 _collateralAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function adjustTrove(
        ITroveManager troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external;

    function closeTrove(ITroveManager troveManager, address account) external;

    function configureCollateral(ITroveManager troveManager, IERC20 collateralToken) external;

    function fetchBalances() external returns (SystemBalances memory balances);

    function getGlobalSystemBalances() external returns (uint256 totalPricedCollateral, uint256 totalDebt);

    function getTCR() external returns (uint256 globalTotalCollateralRatio);

    function openTrove(
        ITroveManager troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function removeTroveManager(ITroveManager troveManager) external;

    function repayDebt(
        ITroveManager troveManager,
        address account,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function setMinNetDebt(uint256 _minNetDebt) external;

    function withdrawColl(
        ITroveManager troveManager,
        address account,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    ) external;

    function withdrawDebt(
        ITroveManager troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function checkRecoveryMode(uint256 TCR) external pure returns (bool);

    function debtToken() external view returns (IDebtToken);

    function factory() external view returns (address);

    function getCompositeDebt(uint256 _debt) external view returns (uint256);

    function minNetDebt() external view returns (uint256);

    function troveManagersData(ITroveManager) external view returns (IERC20 collateralToken, uint16 index);
}
