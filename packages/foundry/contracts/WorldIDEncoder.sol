// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.23;

import "./interfaces/IRecoverer.sol";
import "./interfaces/IWorldID.sol";
import "./helpers/ByteHasher.sol";

abstract contract WorldIDEncoder {
    using ByteHasher for bytes;

    struct VerificationPayload {
        uint256 signalHash;
        uint256 merkleRoot;
        uint256 nullifierHash;
        uint256[8] proof;
    }

    struct RegistrationPayload {
        uint256 merkleRoot;
        uint256 newNullifierHash;
        uint256[8] proof;
        address owner;
        uint256 expectedSignalHash;
    }

    struct RecoveryPayload {
        uint256 merkleRoot;
        uint256[8] proof;
        address newOwner;
        // uint256 expectedSignalHash;
    }

    ///////////////////////////////////////////////////////////////////////////////
    ///                                  SIGNALS                                ///
    ///////////////////////////////////////////////////////////////////////////////

    struct RegistrationSignal {
        uint256 signalId;
        uint256 chainId; // block.chainid or maybe sourceChainSelector
        address wallet; // address(this)
        address initialOwner; // user sets this
    }

    struct RecoverySignal {
        uint256 signalId;
        uint256 chainId;
        address wallet;
        address newOwner;
        uint256 nonce;
    }

    uint256 constant REGISTER_SIGNAL_ID = uint256(keccak256("registerRecovery"));
    uint256 constant RECOVERY_SIGNAL_ID = uint256(keccak256("recover"));

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
}