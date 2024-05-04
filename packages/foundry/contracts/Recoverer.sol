// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IRouterClient} from
    "@chainlink/ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from
    "@chainlink/ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from
    "@chainlink/ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from
    "@chainlink/ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

import {IRecoverer} from "./interfaces/IRecoverer.sol";

/// @title Abstract contract that RecoverableAccount inherits for CCIP functionality
abstract contract Recoverer is IRecoverer, CCIPReceiver {
    using SafeERC20 for IERC20;

    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 msgValue, uint256 calculatedFees); // Used to make sure msg.value has enough balance.
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
    error SourceChainNotAllowlisted(uint64 sourceChainSelector); // Used when the source chain has not been allowlisted by the contract owner.
    error SenderNotAllowlisted(address sender); // Used when the sender has not been allowlisted by the contract owner.
    error InvalidReceiverAddress(); // Used when the receiver address is 0.
    error NotFromVerifier();
    error UnsupportedVerifierChain();
    error MessageWasNotSentByMessageTracker(bytes32 msgId); // Triggered when attempting to confirm a message not recognized as sent by this tracker.
    error MessageHasAlreadyBeenProcessedOnDestination(bytes32 msgId); // Triggered when trying to mark a message as `ProcessedOnDestination` when it is already marked as such.

    // Event emitted when a message is sent to another chain.
    // The chain selector of the destination chain.
    // The address of the receiver on the destination chain.
    // The data being sent.
    // the token address used to pay CCIP fees.
    // The fees paid for sending the CCIP message.
    event MessageSent( // The unique ID of the CCIP message.
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        bytes data,
        address feeToken,
        uint256 fees
    );

    // Event emitted when the sender contract receives an acknowledgment
    // that the receiver contract has successfully received and processed the message.
    // The unique ID of the message acknowledged by the receiver.
    // The chain selector of the source chain.
    // The address of the sender from the source chain.
    event MessageProcessedOnDestination( // The unique ID of the CCIP acknowledgment message.
        bytes32 indexed messageId,
        bytes32 indexed acknowledgedMsgId,
        uint64 indexed sourceChainSelector,
        address sender
    );

    // Event emitted when a message is received from another chain.
    // The chain selector of the source chain.
    // The address of the sender from the source chain.
    // The text that was received.
    event MessageReceived( // The unique ID of the CCIP message.
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        string text
    );

    address public constant NATIVE_GAS_TOKEN = address(0);

    uint64 immutable WORLD_ID_VERIFIER_CHAIN;
    address immutable WORLD_ID_VERIFIER;

    // Enum is used to track the status of messages sent via CCIP.
    // `NotSent` indicates a message has not yet been sent.
    // `Sent` indicates that a message has been sent to the Acknowledger contract but not yet acknowledged.
    // `ProcessedOnDestination` indicates that the Acknowledger contract has processed the message and that
    // the Message Tracker contract has received the acknowledgment from the Acknowledger contract.
    enum MessageStatus {
        NotSent, // 0
        Sent, // 1
        ProcessedOnDestination // 2

    }

    enum MessageType {
        Registration,
        Recovery
    }

    struct MessageInfo {
        MessageStatus status;
        bytes32 acknowledgerMessageId;
        MessageType messageType;
        bytes executionData; // ABI-encoded data required to execute action after cross-chain verification
    }

    // Mapping to keep track of message IDs to their info (status & acknowledger message ID).
    mapping(bytes32 => MessageInfo) public messagesInfo;

    constructor(
        address _router,
        address _worldIdVerifier,
        uint64 _worldIdVerifierChain
    ) CCIPReceiver(_router) {
        WORLD_ID_VERIFIER = _worldIdVerifier;
        WORLD_ID_VERIFIER_CHAIN = _worldIdVerifierChain;
    }

    function _sendIDToVerifier(
        VerificationPayload memory _verificationPayload,
        MessageType _msgType,
        bytes memory _executionData
    ) internal returns (bytes32 messageId) {
        bytes memory abiEncodedPayload = abi.encode(_verificationPayload);

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            WORLD_ID_VERIFIER,
            abiEncodedPayload, // Sending recovery payload
            NATIVE_GAS_TOKEN // Paying with native gas
        );

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(WORLD_ID_VERIFIER_CHAIN, evm2AnyMessage);

        if (fees > msg.value) {
            revert NotEnoughBalance(msg.value, fees);
        }

        // Send the CCIP message through the router and store the returned CCIP message ID
        messageId = router.ccipSend{value: fees}(
            WORLD_ID_VERIFIER_CHAIN, evm2AnyMessage
        );

        // Update the message info
        messagesInfo[messageId].status = MessageStatus.Sent;
        messagesInfo[messageId].messageType = _msgType;
        messagesInfo[messageId].executionData = _executionData;

        // Emit an event with message details
        emit MessageSent(
            messageId,
            WORLD_ID_VERIFIER_CHAIN,
            WORLD_ID_VERIFIER,
            abiEncodedPayload,
            address(0),
            fees
        );

        // Return the CCIP message ID
        return messageId;
    }

    /// handle a received message
    function _acknowledgeMessage(Client.Any2EVMMessage memory any2EvmMessage)
        internal
    {
        uint64 sourceChainSelector = any2EvmMessage.sourceChainSelector;
        address sender = abi.decode(any2EvmMessage.sender, (address));

        if (sender != WORLD_ID_VERIFIER) revert NotFromVerifier();
        if (sourceChainSelector != WORLD_ID_VERIFIER_CHAIN) {
            revert UnsupportedVerifierChain();
        }

        bytes32 initialMsgId = abi.decode(any2EvmMessage.data, (bytes32)); // Decode the data sent by the receiver
        bytes32 acknowledgerMsgId = any2EvmMessage.messageId;
        messagesInfo[initialMsgId].acknowledgerMessageId = acknowledgerMsgId; // Store the messageId of the received message

        // Check message has been sent but not processed
        if (messagesInfo[initialMsgId].status == MessageStatus.Sent) {
            // Updates the status of the message to 'ProcessedOnDestination' to reflect that an acknowledgment
            // of receipt has been received and emits an event to log this confirmation along with relevant details.
            messagesInfo[initialMsgId].status =
                MessageStatus.ProcessedOnDestination;
            emit MessageProcessedOnDestination(
                acknowledgerMsgId,
                initialMsgId,
                any2EvmMessage.sourceChainSelector,
                abi.decode(any2EvmMessage.sender, (address))
            );
        } else if (
            messagesInfo[initialMsgId].status
                == MessageStatus.ProcessedOnDestination
        ) {
            // If the message is already marked as 'ProcessedOnDestination', this indicates an attempt to
            // re-confirm a message that has already been processed on the destination chain and marked as such.
            revert MessageHasAlreadyBeenProcessedOnDestination(initialMsgId);
        } else {
            // If the message status is neither 'Sent' nor 'ProcessedOnDestination', it implies that the
            // message ID provided for acknowledgment does not correspond to a valid, previously
            // sent message.
            revert MessageWasNotSentByMessageTracker(initialMsgId);
        }
    }

    /// @notice Construct a CCIP message.
    function _buildCCIPMessage(
        address _receiver,
        bytes memory _abiEncodedData,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: _abiEncodedData, // ABI-encoded data
            // TODO: support enough gas token transfer for callback
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array as no tokens are transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 200_000})
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
    }

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}
}
