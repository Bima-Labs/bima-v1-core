//SPDX-License-Identifier:MIT

pragma solidity 0.8.20;

import {DebtToken} from "../core/DebtToken.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ICrossChainAdapter} from "../interfaces/ICrossChainAdapter.sol";

contract CrossChainAdapter is ICrossChainAdapter, ReentrancyGuard, AccessControl {
    bytes32 public constant UNLOCKER = keccak256(abi.encode("CrossChainAdapter.UNLOCKER"));
    DebtToken public immutable usbd;

    uint256 sourceChainfee; // 1e18 = 1%
    mapping(uint256 destChainId => DestChainInfo destChainConfig) enabledChainConfigs;

    modifier isChainEnabled(uint256 _destChainId) {
        if (!enabledChainConfigs[_destChainId].isEnabled) {
            revert ChainNotEnabled(_destChainId);
        }
        _;
    }

    constructor(address _usbd, address _admin, uint256 _sourceChainFee) {
        sourceChainfee = _sourceChainFee;
        usbd = DebtToken(_usbd);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    // ========== Lock/Unlock FUNCTIONS ========== //

    function lock(
        address _transferTo,
        uint256 _usbdAmount,
        uint256 _destChainId
    ) external nonReentrant isChainEnabled(_destChainId) returns (uint256) {
        usbd.transferFrom(msg.sender, address(this), _usbdAmount);
        emit TokensLocked(msg.sender, _transferTo, _usbdAmount, _destChainId, block.timestamp);
        return _usbdAmount;
    }

    function unlock(
        address to,
        uint256 usbdAmount,
        address feeReceiver
    ) external nonReentrant onlyRole(UNLOCKER) returns (uint256) {
        (uint256 unlockAmount, uint256 feeAmount) = previewUnlockAmountAndFee(usbdAmount, block.chainid);
        usbd.transfer(to, unlockAmount);
        usbd.transfer(feeReceiver, feeAmount);
        emit TokensUnlocked(to, usbdAmount, block.timestamp);
        return unlockAmount;
    }

    // ========== INTERNAL FUNCTIONS ========== //

    function previewUnlockAmountAndFee(
        uint256 _depositAmount,
        uint256 _destChainId
    ) internal view isChainEnabled(_destChainId) returns (uint256, uint256) {
        uint256 unlockAmount;
        uint256 feeAmount;

        // if it is called by unlock`
        if (_destChainId == block.chainid) {
            feeAmount = (sourceChainfee * _depositAmount) / 100e18;
            unlockAmount = _depositAmount - feeAmount;
            return (unlockAmount, feeAmount);
        }

        feeAmount = (enabledChainConfigs[_destChainId].fee * _depositAmount) / 100e18;
        unlockAmount = _destChainId - feeAmount;
        return (unlockAmount, feeAmount);
    }

    // ========== OWNER FUNCTIONS ========== //
    function enableChainAndSetFee(uint256 _destChainId, uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        enabledChainConfigs[_destChainId] = DestChainInfo({fee: _fee, isEnabled: true});
        emit ChainIsEnabled(_destChainId, _fee);
    }

    function removeLiquidity(uint256 _usbdAmount, address _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        usbd.transfer(_to, _usbdAmount);
    }

    function chgangeChainfee(
        uint256 _newFee,
        uint256 _destChainId
    ) external isChainEnabled(_destChainId) onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_destChainId == block.chainid) {
            sourceChainfee = _newFee;
        } else {
            enabledChainConfigs[_destChainId].fee = _newFee;
        }
    }

    function disableChain(uint256 destChainId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete enabledChainConfigs[destChainId];
    }

    // ========== VIEW FUNCTIONS ========== //

    function getUsbdLiquidity() external view returns (uint256 liquidity) {
        liquidity = usbd.balanceOf(address(this));
    }

    function checkenabledChainConfigs(uint256 _destChainId) external view returns (DestChainInfo memory) {
        return enabledChainConfigs[_destChainId];
    }
}
