// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ByteHasher} from "../helpers/ByteHasher.sol";
import {IWorldID} from "../interfaces/IWorldID.sol";
import {IRecoverer} from "../interfaces/IRecoverer.sol";
import {IRouterClient} from "@chainlink/ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

import {Client} from "@chainlink/ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract WorldIDVerifier is IRecoverer, CCIPReceiver {
    using ByteHasher for bytes;

    ///////////////////////////////////////////////////////////////////////////////
    ///                                  ERRORS                                ///
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when attempting to reuse a nullifier
    error InvalidNullifier();

    error InvalidReceiverAddress();

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance.

    // Emitted when an acknowledgment message is successfully sent back to the sender contract.
    // This event signifies that the Acknowledger contract has recognized the receipt of an initial message
    // and has informed the original sender contract by sending an acknowledgment message,
    // including the original message ID.
    event AcknowledgmentSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address indexed receiver, // The address of the receiver on the destination chain.
        bytes32 data, // The data being sent back, containing the message ID of the initial message to acknowledge.
        address feeToken, // The token address used to pay CCIP fees for sending the acknowledgment.
        uint256 fees // The fees paid for sending the acknowledgment message via CCIP.
    );
    
    address public constant NATIVE_GAS_TOKEN = address(0);

    /// @dev The World ID instance that will be used for verifying proofs
    IWorldID internal immutable worldId;

    /// @dev The contract's external nullifier hash
    uint256 internal immutable externalNullifier;

    /// @dev The World ID group ID (always 1)
    uint256 internal immutable groupId = 1;

    /// @dev Whether a nullifier hash has been used already. Used to guarantee an action is only performed once by a single person
    mapping(uint256 => bool) internal nullifierHashes;

    /// @param _worldId The WorldID instance that will verify the proofs
    /// @param _appId The World ID app ID
    /// @param _actionId The World ID action ID
    constructor(
        IWorldID _worldId,
        address _ccipRouter,
        string memory _appId,
        string memory _actionId
    ) CCIPReceiver(_ccipRouter) {
        worldId = _worldId;
        externalNullifier = abi
            .encodePacked(abi.encodePacked(_appId).hashToField(), _actionId)
            .hashToField();
    }

    /// @param signal An arbitrary input from the user, usually the user's wallet address (check README for further details)
    /// @param root The root of the Merkle tree (returned by the JS widget).
    /// @param nullifierHash The nullifier hash for this proof, preventing double signaling (returned by the JS widget).
    /// @param proof The zero-knowledge proof that demonstrates the claimer is registered with World ID (returned by the JS widget).
    /// @dev Feel free to rename this method however you want! We've used `claim`, `verify` or `execute` in the past.
    function verifyAndExecute(
        address signal,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) public {
        // First, we make sure this person hasn't done this before
        if (nullifierHashes[nullifierHash]) revert InvalidNullifier();

        // We now verify the provided proof is valid and the user is verified by World ID
        worldId.verifyProof(
            root,
            groupId,
            abi.encodePacked(signal).hashToField(),
            nullifierHash,
            externalNullifier,
            proof
        );

        // We now record the user has done this, so they can't do it again (proof of uniqueness)
        nullifierHashes[nullifierHash] = true;

    }

    function _verifyId(
        RecoveryPayload memory _recoveryPayload
    ) internal {
        // Nullifier hashes can only be used once
        if (nullifierHashes[_recoveryPayload.nullifierHash]) revert InvalidNullifier();

        // Verify that the claimer is verified with WorldID - reverts if invalid
        worldId.verifyProof(
            _recoveryPayload.merkleRoot,
            groupId,
            abi.encode(_recoveryPayload.signal).hashToField(),
            _recoveryPayload.nullifierHash,
            externalNullifier,
            _recoveryPayload.proof
        );

        // Mark nullifierHash as used
        nullifierHashes[_recoveryPayload.nullifierHash] = true;
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
    {
        // Only accept messages from RecoverableAccounts
        address sender = abi.decode(any2EvmMessage.sender, (address));

        RecoveryPayload memory recoveryPayload = abi.decode(any2EvmMessage.data, (RecoveryPayload));
        
        // Verify WorldID
        _verifyId(recoveryPayload);

        // Acknowledge valid recovery with callback
        _acknowledgeRecovery(
            any2EvmMessage.messageId,
            abi.decode(any2EvmMessage.sender, (address)),
            any2EvmMessage.sourceChainSelector
        );
    }

    function _acknowledgeRecovery(
        bytes32 _messageIdToAcknowledge,
        address _messageTrackerAddress,
        uint64 _messageTrackerChainSelector
    ) private {

        if (_messageTrackerAddress == address(0))
            revert InvalidReceiverAddress();

        // Construct the CCIP message for acknowledgment, including the message ID of the initial message.
        Client.EVM2AnyMessage memory acknowledgment = Client.EVM2AnyMessage({
            receiver: abi.encode(_messageTrackerAddress), // ABI-encoded receiver address
            data: abi.encode(_messageIdToAcknowledge), // ABI-encoded message ID to acknowledge
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array as no tokens are transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 200_000})
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: NATIVE_GAS_TOKEN
        });

        // Initialize a router client instance to interact with the cross-chain router.
        IRouterClient router = IRouterClient(this.getRouter());

        // Calculate the fee required to send the CCIP acknowledgment message.
        uint256 fees = router.getFee(
            _messageTrackerChainSelector, // The chain selector for routing the message.
            acknowledgment // The acknowledgment message data.
        );

        // Ensure the contract has sufficient balance to cover the message sending fees.
        if (fees > address(this).balance) {
            revert NotEnoughBalance(address(this).balance, fees);
        }

        // Send the acknowledgment message via the CCIP router and capture the resulting message ID.
        bytes32 messageId = router.ccipSend(
            _messageTrackerChainSelector, // The destination chain selector.
            acknowledgment // The CCIP message payload for acknowledgment.
        );

        // Emit an event detailing the acknowledgment message sending, for external tracking and verification.
        emit AcknowledgmentSent(
            messageId, // The ID of the sent acknowledgment message.
            _messageTrackerChainSelector, // The destination chain selector.
            _messageTrackerAddress, // The receiver of the acknowledgment, typically the original sender.
            _messageIdToAcknowledge, // The original message ID that was acknowledged.
            NATIVE_GAS_TOKEN, // The fee token used.
            fees // The fees paid for sending the message.
        );
    }

    receive() external payable {}
}