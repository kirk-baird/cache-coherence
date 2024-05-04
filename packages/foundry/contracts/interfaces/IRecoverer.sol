// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

interface IRecoverer {

    struct RecoveryPayload {
        WorldIDSignal signal;
        uint256 merkleRoot;
        uint256 nullifierHash;
        uint256[8] proof;
    }

    struct WorldIDSignal {
        bytes data;
    }


}