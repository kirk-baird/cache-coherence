//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@account-abstraction/core/EntryPoint.sol";
import "../contracts/RecoverableAccount.sol";
import "../contracts/RecoverableAccountFactory.sol";
import "./DeployHelpers.s.sol";

contract DeployScript is ScaffoldETHDeploy {
    error InvalidPrivateKey(string);

    function run() external {
        // Load private key from .env and print address
        uint256 deployerPrivateKey = setupLocalhostEnv();
        if (deployerPrivateKey == 0) {
            revert InvalidPrivateKey(
                "You don't have a deployer account. Make sure you have set DEPLOYER_PRIVATE_KEY in .env or use `yarn generate` to generate a new random account"
            );
        }
        address owner = vm.addr(deployerPrivateKey);
        console.logString(
            string.concat(
                "Owner address: ", vm.toString(owner)
            )
        );

        vm.startBroadcast(deployerPrivateKey);

        // Sepolia Base Addresses
        // if (block.chainid == 0) {
        IEntryPoint entryPoint = IEntryPoint(address(0x0000000071727De22E5E9d8BAf0edAc6f37da032)); // EntryPoint only works for Alchemy
        uint64 worldIdVerifierChain = 16015286601757825753; // ETH Sepolia chainId from CCIP
        address router = address(0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93); // Base Sepolia Router
        address worldIdVerifier = address(0x98D85df420E932038F0E72d91d5231c092e9c793); // ETH Sepolid `WorldIDVerifier.sol`
        // }

        // Create a RecoverableAccountFactory
        RecoverableAccountFactory factory =
            new RecoverableAccountFactory(entryPoint, router, worldIdVerifier, worldIdVerifierChain);


        // Create a new RecoverableAccount
        RecoverableAccount recoverableAccount = new RecoverableAccount(entryPoint, router, worldIdVerifier, worldIdVerifierChain);

        vm.stopBroadcast();


        console.logString(
            string.concat(
                "Factory deployed at: ", vm.toString(address(factory))
            )
        );
        console.logString(
            string.concat(
                "RecoverableAccount deployed at: ", vm.toString(address(recoverableAccount))
            )
        );

        // Register during
        // recoverableAccount.initialize(owner); // This makes debugging on the front end challenging
        // uint256[8] memory proof;
        // IRecoverer.RegistrationPayload memory registrationPayload = IRecoverer.RegistrationPayload({
        //     merkleRoot: 1000,
        //     proof: proof,
        //     newNullifierHash: 9876,
        //     expectedSignalHash: 999
        // });
        // bytes32 messageId = recoverableAccount.registerWorldId{value: 1e16}(registrationPayload);
        // console.logString(
        //     string.concat(
        //         "CCIP Message Registation: ", vm.toString(messageId)
        //     )
        // );


        // Test transaction during deployment to save time
        uint256[8] memory proof;
        IRecoverer.RecoveryPayload memory recoveryPayload = IRecoverer.RecoveryPayload({
            merkleRoot: 1,
            proof: proof,
            newOwner: owner,
            expectedSignalHash: 1
        });
        bytes32 messageId = recoverableAccount.recoverAccount{value: 19609570891446417} (recoveryPayload);
        console.logString(
            string.concat(
                "CCIP Message Recovery: ", vm.toString(messageId)
            )
        );


        /**
         * This function generates the file containing the contracts Abi definitions.
         * These definitions are used to derive the types needed in the custom scaffold-eth hooks, for example.
         * This function should be called last.
         */
        address[] memory addrs = new address[](3);
        string[] memory names = new string[](3);
        addrs[0] = address(recoverableAccount);
        names[0] = "RecoverableAccount";
        addrs[1] = address(factory);
        names[1] = "RecoverableAccountFactory";
        addrs[2] = address(entryPoint);
        names[2] = "EntryPoint";
        exportDeployments(addrs, names);
    }

    function test() public {}
}
