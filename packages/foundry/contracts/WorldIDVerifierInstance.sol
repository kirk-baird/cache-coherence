// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./world-id-verification-chain/WorldIDVerifier.sol";
import "./interfaces/IRecoverer.sol";
import "./helpers/ByteHasher.sol";

contract WorldIDVerifierInstance is WorldIDVerifier {
    using ByteHasher for bytes;

    uint256 constant REGISTER_SIGNAL_ID = uint256(keccak256("registerRecovery"));
    uint256 constant RECOVERY_SIGNAL_ID = uint256(keccak256("recover"));

    uint256 public nullifierHash;
    constructor(
        IWorldID _worldId,
        address _ccipRouter,
        string memory _appId,
        string memory _actionId
    ) WorldIDVerifier(_worldId, _ccipRouter, _appId, _actionId) {}

    function _setNullifierHash(uint256 _nullifierHash) private {
        nullifierHash = _nullifierHash;
    }

    function register(RegistrationPayload memory _registrationPayload) external {
        RegistrationSignal memory signal = RegistrationSignal({
            signalId: REGISTER_SIGNAL_ID,
            chainId: block.chainid,
            wallet: address(this),
            initialOwner: _registrationPayload.owner
        });

        uint256 _signalHash = calculateSignalHash(signal);

        require(_registrationPayload.expectedSignalHash == _signalHash, "register: Unexpected signal hash");

        VerificationPayload memory verificationPayload = VerificationPayload({
            signalHash: _signalHash,
            merkleRoot: _registrationPayload.merkleRoot,
            nullifierHash: _registrationPayload.newNullifierHash,
            proof: _registrationPayload.proof
        });

        _verifyId(verificationPayload);
    }

    function calculateSignalHash(RegistrationSignal memory _registrationSignal) public pure returns (uint256) {
        return abi.encode(_registrationSignal).hashToField();
    }

}