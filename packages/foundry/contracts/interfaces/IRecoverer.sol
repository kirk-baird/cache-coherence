// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

interface IRecoverer {

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
        uint256 expectedSignalHash;
    }

    struct RecoveryPayload {
        uint256 merkleRoot;
        uint256[8] proof;
        address newOwner;
        uint256 expectedSignalHash;
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

}
