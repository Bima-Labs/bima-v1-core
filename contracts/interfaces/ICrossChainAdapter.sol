//SPDX-License-Identifier:MIT

pragma solidity 0.8.20;

import {DebtToken} from "../core/DebtToken.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface ICrossChainAdapter {
    event TokensLocked(
        address from,
        address indexed to,
        uint256 indexed usbdAmount,
        uint256 indexed destChainId,
        uint256 timestamp
    );
    event TokensUnlocked(address indexed to, uint256 usbdAmount, uint256 timestamp);
    event ChainIsEnabled(uint256 chaindId, uint256 fee);

    error ChainNotEnabled(uint256 chainId);
    struct DestChainInfo {
        uint256 fee;
        bool isEnabled;
    }

    function lock(address _transferTo, uint256 _usbdAmount, uint256 _destChainId) external returns (uint256);

    function unlock(address to, uint256 usbdAmount, address feeReceiver) external returns (uint256);

    function enableChainAndSetFee(uint256 _destChainId, uint256 _fee) external;

    function removeLiquidity(uint256 _usbdAmount, address _to) external;

    function chgangeChainfee(uint256 _newFee, uint256 _destChainId) external;

    function disableChain(uint256 destChainId) external;

    function getUsbdLiquidity() external view returns (uint256 liquidity);

    function checkenabledChainConfigs(uint256 _destChainId) external view returns (DestChainInfo memory);
}
