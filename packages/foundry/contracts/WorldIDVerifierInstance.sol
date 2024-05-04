// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./world-id-verification-chain/WorldIDVerifier.sol";
import "./interfaces/IRecoverer.sol";
import "./helpers/ByteHasher.sol";

// Dummy World ID register/recover on the same chain
contract WorldIDVerifierInstance is WorldIDVerifier {
    using ByteHasher for bytes;

    uint256 constant REGISTER_SIGNAL_ID = uint256(keccak256("registerRecovery"));
    uint256 constant RECOVERY_SIGNAL_ID = uint256(keccak256("recover"));

    uint256 public nullifierHash;
    address public owner;
    // TODO
    // avoid executing same recovery multiple times
    uint256 public recoveryNonce;

    constructor(
        IWorldID _worldId,
        address _ccipRouter,
        string memory _appId,
        string memory _actionId
    ) WorldIDVerifier(_worldId, _ccipRouter, _appId, _actionId) {
        owner = msg.sender;
    }

    function _setNullifierHash(uint256 _nullifierHash) private {
        nullifierHash = _nullifierHash;
    }

    // TODO onlyowner or only once, protect
    // Have register as a separate step after constructor (for now)
    // to save having to pre-calculate the wallet address when making the signal offchain
    function register(RegistrationPayload memory _registrationPayload) public {
        // Construct signal using on-chain data
        RegistrationSignal memory signal = RegistrationSignal({
            signalId: REGISTER_SIGNAL_ID,
            chainId: block.chainid,
            wallet: address(this),
            initialOwner: owner
        });

        uint256 _signalHash = calculateSignalHash(signal);

        // signal sanity check
        // require(_registrationPayload.expectedSignalHash == _signalHash, "register: Unexpected signal hash");

        // perform verification
        VerificationPayload memory verificationPayload = VerificationPayload({
            signalHash: _signalHash,
            merkleRoot: _registrationPayload.merkleRoot,
            nullifierHash: _registrationPayload.newNullifierHash,
            proof: _registrationPayload.proof
        });
        _verifyId(verificationPayload);

        // Perform registration
        nullifierHash = _registrationPayload.newNullifierHash;
    }

    function recover(RecoveryPayload memory _recoveryPayload) external {
        // Construct signal using on-chain data
        RecoverySignal memory signal = RecoverySignal({
            signalId: RECOVERY_SIGNAL_ID,
            chainId: block.chainid,
            wallet: address(this),
            newOwner: _recoveryPayload.newOwner,
            nonce: recoveryNonce
        });

        uint256 _signalHash = calculateSignalHash(signal);

        // signal sanity check
        require(_recoveryPayload.expectedSignalHash == _signalHash, "register: Unexpected signal hash");

        // perform verification
        // note: uses stored nullifierHash
        VerificationPayload memory verificationPayload = VerificationPayload({
            signalHash: _signalHash,
            merkleRoot: _recoveryPayload.merkleRoot,
            nullifierHash: nullifierHash,
            proof: _recoveryPayload.proof
        });
        _verifyId(verificationPayload);

        // perform recovery
        owner = _recoveryPayload.newOwner;
        // increment nonce to protect against replay
        recoveryNonce++;
    }

    // TODO make internal
    function calculateSignalHash(RegistrationSignal memory _registrationSignal) public pure returns (uint256) {
        return abi.encode(_registrationSignal).hashToField();
    }

    // TODO make internal
    function calculateSignalHash(RecoverySignal memory _recoverySignal) public pure returns (uint256) {
        return abi.encode(_recoverySignal).hashToField();
    }

    // Helper, dummy to help get info for off-chain proof generation
    function encodeRegistrationSignal(address _owner) public view returns (bytes memory) {
        RegistrationSignal memory signal = RegistrationSignal({
            signalId: REGISTER_SIGNAL_ID,
            chainId: block.chainid,
            wallet: address(this),
            initialOwner: _owner
        });
        return abi.encode(signal);
    }

    // Helper, dummy to help get info for off-chain proof generation
    function encodeRecoverySignal(address _newOwner) public view returns (bytes memory) {
        RecoverySignal memory signal = RecoverySignal({
            signalId: RECOVERY_SIGNAL_ID,
            chainId: block.chainid,
            wallet: address(this),
            newOwner: _newOwner,
            nonce: recoveryNonce
        });
        return abi.encode(signal);
    }
}
