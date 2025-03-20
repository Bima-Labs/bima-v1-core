// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ITokenLocker} from "../interfaces/ITokenLocker.sol";
import {IBimaVault} from "../interfaces/IVault.sol";

interface IClaimCallback {
    function claimCallback(address claimant, uint256 amount) external returns (bool success);
}

/**
    @title Bima veCRV Airdrop Distributor
    @notice Distributes BIMA to veCRV holders that voted in favor of
            Bima's initial Curve governance proposal.
    @dev Airdropped BIMA tokens are given as a one year locked position.
         Distribution is via a merkle proof. The proof and script used
         to create are available on Github: https://github.com/bima-fi
 */
contract AirdropDistributor is Ownable {
    using Address for address;

    bytes32 public merkleRoot;
    uint256 public canClaimUntil;

    mapping(uint256 => uint256) private claimedBitMap;
    mapping(address receiver => address callback) public claimCallback;

    IERC20 public immutable token;
    ITokenLocker public immutable locker;
    address public immutable vault;

    uint256 private immutable lockToTokenRatio;
    uint256 private constant MAX_LOCK_WEEKS = 52;
    uint256 public constant CLAIM_DURATION = 13 weeks;

    event Claimed(address indexed claimant, address indexed receiver, uint256 index, uint256 amount);
    event MerkleRootSet(bytes32 root, uint256 canClaimUntil);
    event SetClaimCallback(address receiver, address callback);
    event SweepUnclaimedTokens(uint256 amount);

    constructor(IERC20 _token, ITokenLocker _locker, address _vault) {
        token = _token;
        locker = _locker;
        vault = _vault;

        lockToTokenRatio = _locker.lockToTokenRatio();
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        require(merkleRoot == bytes32(0), "merkleRoot already set");
        merkleRoot = _merkleRoot;

        uint256 canClaimUntilCached = block.timestamp + CLAIM_DURATION;
        canClaimUntil = canClaimUntilCached;

        emit MerkleRootSet(_merkleRoot, canClaimUntilCached);
    }

    function sweepUnclaimedTokens() external {
        require(merkleRoot != bytes32(0), "merkleRoot not set");
        require(block.timestamp > canClaimUntil, "Claims still active");
        uint256 amount = token.allowance(vault, address(this));
        require(amount > 0, "Nothing to sweep");
        token.transferFrom(vault, address(this), amount);
        token.approve(vault, amount);
        IBimaVault(vault).increaseUnallocatedSupply(amount);

        emit SweepUnclaimedTokens(amount);
    }

    function isClaimed(uint256 index) public view returns (bool output) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        output = claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    /**
        @dev `amount` is after dividing by `locker.lockToTokenRatio()`
     */
    function claim(
        address claimant,
        address receiver,
        uint256 index,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        if (msg.sender != claimant) {
            require(msg.sender == owner(), "onlyOwner");
            require(claimant.isContract(), "Claimant must be a contract");
        }

        bytes32 merkleRootCache = merkleRoot;
        require(merkleRootCache != bytes32(0), "merkleRoot not set");

        require(block.timestamp < canClaimUntil, "Claims period has finished");
        require(!isClaimed(index), "Already claimed");

        bytes32 node = keccak256(abi.encodePacked(index, claimant, amount));
        require(MerkleProof.verifyCalldata(merkleProof, merkleRootCache, node), "Invalid proof");

        _setClaimed(index);
        token.transferFrom(vault, address(this), amount * lockToTokenRatio);
        locker.lock(receiver, amount, MAX_LOCK_WEEKS);

        if (claimant != receiver) {
            address callback = claimCallback[receiver];
            if (callback != address(0)) IClaimCallback(callback).claimCallback(claimant, amount);
        }

        emit Claimed(claimant, receiver, index, amount * lockToTokenRatio);
    }

    /**
        @notice Set a claim callback contract
        @dev When set, claims directed to the caller trigger a callback to this address
     */
    function setClaimCallback(address _callback) external returns (bool success) {
        claimCallback[msg.sender] = _callback;

        emit SetClaimCallback(msg.sender, _callback);

        success = true;
    }
}
