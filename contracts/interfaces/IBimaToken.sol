// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

interface IBimaToken {
    struct SendParam {
        uint32 dstEid; // Destination endpoint ID.
        bytes32 to; // Recipient address.
        uint256 amountLD; // Amount to send in local decimals.
        uint256 minAmountLD; // Minimum amount to send in local decimals.
        bytes extraOptions; // Additional options supplied by the caller to be used in the LayerZero message.
        bytes composeMsg; // The composed message for the send() operation.
        bytes oftCmd; // The OFT command to be executed, unused in default OFT implementations.
    }

    struct OFTLimit {
        uint256 minAmountLD; // Minimum amount in local decimals that can be sent to the recipient.
        uint256 maxAmountLD; // Maximum amount in local decimals that can be sent to the recipient.
    }

    struct OFTReceipt {
        uint256 amountSentLD; // Amount of tokens ACTUALLY debited from the sender in local decimals.
        // @dev In non-default implementations, the amountReceivedLD COULD differ from this value.
        uint256 amountReceivedLD; // Amount of tokens to be received on the remote side.
    }

    struct OFTFeeDetail {
        int256 feeAmountLD; // Amount of the fee in local decimals.
        string description; // Description of the fee.
    }

    struct MessagingParams {
        uint32 dstEid;
        bytes32 receiver;
        bytes message;
        bytes options;
        bool payInLzToken;
    }

    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct Origin {
        uint32 srcEid;
        bytes32 sender;
        uint64 nonce;
    }

    struct InboundPacket {
        Origin origin; // Origin information of the packet.
        uint32 dstEid; // Destination endpointId of the packet.
        address receiver; // Receiver address for the packet.
        bytes32 guid; // Unique identifier of the packet.
        uint256 value; // msg.value of the packet.
        address executor; // Executor address for the packet.
        bytes message; // Message payload of the packet.
        bytes extraData; // Additional arbitrary data for the packet.
    }

    struct EnforcedOptionParam {
        uint32 eid; // Endpoint ID
        uint16 msgType; // Message Type
        bytes options; // Additional options
    }

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ReceiveFromChain(uint16 indexed _srcChainId, address indexed _to, uint256 _amount);
    event RetryMessageSuccess(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _payloadHash);
    event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes _toAddress, uint256 _amount);
    event SetMinDstGas(uint16 _dstChainId, uint16 _type, uint256 _minDstGas);
    event SetPrecrime(address precrime);
    event SetTrustedRemote(uint16 _remoteChainId, bytes _path);
    event SetTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress);
    event SetUseCustomAdapterParams(bool _useCustomAdapterParams);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event PreCrimeSet(address preCrimeAddress);
    event PeerSet(uint32 eid, bytes32 peer);

    event OFTSent(
        bytes32 indexed guid,
        uint32 dstEid,
        address indexed fromAddress,
        uint256 amountSentLD,
        uint256 amountReceivedLD
    );
    event OFTReceived(bytes32 indexed guid, uint32 srcEid, address indexed toAddress, uint256 amountReceivedLD);

    function approve(address spender, uint256 amount) external returns (bool);

    function authorizedMint(address _to, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;

    function burnWithGasCompensation(address _account, uint256 _amount) external returns (bool);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    function enableTroveManager(address _troveManager) external;

    function flashLoan(address receiver, uint256 amount, bytes calldata data) external returns (bool);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable;

    function lzReceiveAndRevert(InboundPacket[] calldata _packets) external payable;

    function _lzReceiveSimulate(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external;

    function mint(address _account, uint256 _amount) external;

    function mintWithGasCompensation(address _account, uint256 _amount) external returns (bool);

    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function renounceOwnership() external;

    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external;

    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory);

    function sendToSP(address _sender, uint256 _amount) external;

    function setDelegate(address _delegate) external;

    function setEnforcedOptions(EnforcedOptionParam[] calldata _enforcedOptions) external;

    function setLendingVaultAdapterAddress(address _lendingVaultAdapterAddress) external;

    function setMsgInspector(address _msgInspector) external;

    function setPeer(uint32 _eid, bytes32 _peer) external;

    function setPrecrime(address _precrime) external;

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function transferOwnership(address newOwner) external;

    function allowance(address owner, address spender) external view returns (uint256);

    function allowInitializePath(Origin calldata _origin) external view returns (bool);

    function approvalRequired() external view returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function borrowerOperationsAddress() external view returns (address);

    function combineOptions(
        uint32 _eid,
        uint16 _msgType,
        bytes calldata _extraOptions
    ) external view returns (bytes memory options);

    function DEBT_GAS_COMPENSATION() external view returns (uint256);

    function decimals() external view returns (uint8);

    function domainSeparator() external view returns (bytes32);

    function endpoint() external view returns (ILayerZeroEndpointV2 iEndpoint);

    function transferToLocker(address sender, uint256 amount) external returns (bool success);

    function mintToVault(uint256 _totalSupply) external returns (bool success);

    // enforcedOptions

    function factory() external view returns (address);

    function FLASH_LOAN_FEE() external view returns (uint256);

    function flashFee(address token, uint256 amount) external view returns (uint256);

    function gasPool() external view returns (address);

    function isComposeMsgSender(
        Origin calldata _origin,
        bytes calldata _message,
        address _sender
    ) external view returns (bool isSender);

    function isPeer(uint32 _eid, bytes32 _peer) external view returns (bool);

    function maxFlashLoan(address token) external view returns (uint256);

    function name() external view returns (string memory);

    function nextNonce(uint32 _eid, bytes32 _sender) external view returns (uint64);

    function nonces(address owner) external view returns (uint256);

    function oApp() external view returns (address);

    function oAppVersion() external view returns (uint64 senderVersion, uint64 receiverVersion);

    function oftVersion() external view returns (bytes4 interfaceId, uint64 version);

    function owner() external view returns (address);

    function peers(uint32 _eid) external view returns (bytes32 peer);

    function permitTypeHash() external view returns (bytes32);

    function preCrime() external view returns (address);

    function quoteOFT(
        SendParam calldata _sendParam
    ) external view returns (OFTLimit memory, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory);

    function quoteSend(SendParam calldata _sendParam, bool _payInLzToken) external view returns (MessagingFee memory);

    function sharedDecimals() external view returns (uint8);

    function stabilityPoolAddress() external view returns (address);

    function symbol() external view returns (string memory);

    function token() external view returns (address);

    function totalSupply() external view returns (uint256);

    function troveManager(address) external view returns (bool);

    function version() external view returns (string memory);
}
