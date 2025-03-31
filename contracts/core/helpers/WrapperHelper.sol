// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BimaWrappedCollateral} from "../../wrappers/BimaWrappedCollateral.sol";
import {BimaWrappedCollateralFactory} from "../../wrappers/BimaWrappedCollateralFactory.sol";
import {IBorrowerOperations, ITroveManager} from "../../interfaces/IBorrowerOperations.sol";

contract WrapperHelper {
    BimaWrappedCollateralFactory public immutable bimaWrappedCollateralFactory;
    IBorrowerOperations public immutable borrowerOperations;
    IERC20 public immutable debtToken;

    constructor(address _borrowerOperations, address _debtToken, address _bimaWrappedCollateralFactory) {
        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        debtToken = IERC20(_debtToken);
        bimaWrappedCollateralFactory = BimaWrappedCollateralFactory(_bimaWrappedCollateralFactory);
    }

    function wrapAndOpenTrove(
        ITroveManager troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external {
        BimaWrappedCollateral wrapper = BimaWrappedCollateral(address(troveManager.collateralToken()));
        IERC20 underlying = bimaWrappedCollateralFactory.getColl(address(wrapper));

        underlying.transferFrom(msg.sender, address(this), _collateralAmount);

        underlying.approve(address(wrapper), _collateralAmount);

        uint256 wrappedAmount = wrapper.wrap(_collateralAmount);

        wrapper.approve(address(borrowerOperations), wrappedAmount);

        borrowerOperations.openTrove(
            troveManager,
            account,
            _maxFeePercentage,
            wrappedAmount,
            _debtAmount,
            _upperHint,
            _lowerHint
        );

        debtToken.transfer(msg.sender, _debtAmount);
    }

    function wrapAndAddColl(
        ITroveManager troveManager,
        address account,
        uint256 _collateralAmount,
        address _upperHint,
        address _lowerHint
    ) external {
        BimaWrappedCollateral wrapper = BimaWrappedCollateral(address(troveManager.collateralToken()));
        IERC20 underlying = bimaWrappedCollateralFactory.getColl(address(wrapper));

        underlying.transferFrom(msg.sender, address(this), _collateralAmount);

        underlying.approve(address(wrapper), _collateralAmount);

        uint256 wrappedAmount = wrapper.wrap(_collateralAmount);

        wrapper.approve(address(borrowerOperations), wrappedAmount);

        borrowerOperations.addColl(troveManager, account, wrappedAmount, _upperHint, _lowerHint);
    }

    function withdrawCollAndUnwrap(
        ITroveManager troveManager,
        address account,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    ) external {
        BimaWrappedCollateral wrapper = BimaWrappedCollateral(address(troveManager.collateralToken()));
        IERC20 underlying = bimaWrappedCollateralFactory.getColl(address(wrapper));

        borrowerOperations.withdrawColl(troveManager, account, _collWithdrawal, _upperHint, _lowerHint);

        uint256 unwrappedAmount = wrapper.unwrap(_collWithdrawal);

        underlying.transfer(msg.sender, unwrappedAmount);
    }
}
