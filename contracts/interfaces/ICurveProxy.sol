// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBimaOwnable} from "./IBimaOwnable.sol";
import {IGaugeController} from "./IGaugeController.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVotingEscrow {
    function create_lock(uint256 amount, uint256 unlock_time) external;

    function increase_amount(uint256 amount) external;

    function increase_unlock_time(uint256 unlock_time) external;
}

interface IMinter {
    function mint(address gauge) external;
}

interface IFeeDistributor {
    function claim() external returns (uint256);

    function token() external view returns (address);
}

interface IAragon {
    function vote(uint256 _voteData, bool _supports, bool _executesIfDecided) external;
}

interface ICurveProxy {
    struct GaugeWeightVote {
        address gauge;
        uint256 weight;
    }

    struct TokenBalance {
        IERC20 token;
        uint256 amount;
    }

    event CrvFeePctSet(uint256 feePct);
    event SetVoteManager(address voteManager);
    event SetDepositManager(address depositManager);
    event SetPerGaugeApproval(address caller, address gauge);

    function approveGaugeDeposit(address gauge, address depositor) external returns (bool);

    function claimFees() external returns (uint256);

    function execute(address target, bytes calldata data) external returns (bytes memory);

    function lockCRV() external returns (bool);

    function mintCRV(address gauge, address receiver) external returns (uint256);

    function setCrvFeePct(uint64 _feePct) external returns (bool);

    function setDepositManager(address _depositManager) external returns (bool);

    function setExecutePermissions(
        address caller,
        address target,
        bytes4[] calldata selectors,
        bool permitted
    ) external returns (bool);

    function setGaugeRewardsReceiver(address gauge, address receiver) external returns (bool);

    function setPerGaugeApproval(address caller, address gauge) external returns (bool);

    function setVoteManager(address _voteManager) external returns (bool);

    function transferTokens(address receiver, TokenBalance[] calldata balances) external returns (bool);

    function voteForGaugeWeights(GaugeWeightVote[] calldata votes) external returns (bool);

    function voteInCurveDao(IAragon aragon, uint256 id, bool support) external returns (bool);

    function withdrawFromGauge(address gauge, IERC20 lpToken, uint256 amount, address receiver) external returns (bool);

    function CRV() external view returns (IERC20);

    function crvFeePct() external view returns (uint64);

    function depositManager() external view returns (address);

    function feeDistributor() external view returns (IFeeDistributor);

    function feeToken() external view returns (IERC20);

    function gaugeController() external view returns (IGaugeController);

    function minter() external view returns (IMinter);

    function perGaugeApproval(address caller) external view returns (address gauge);

    function unlockTime() external view returns (uint64);

    function voteManager() external view returns (address);

    function votingEscrow() external view returns (IVotingEscrow);
}
