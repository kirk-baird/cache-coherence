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

        // Create a new EntryPoint
        IEntryPoint entryPoint = new EntryPoint();

        // TODO: worldIdVerifier needs to be deployed
        address fakeAddress = address(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
        address router = fakeAddress; // local testnet only
        address worldIdVerifier = fakeAddress; // local testnet only
        uint64 worldIdVerifierChain = 1; // local testnet only

        // Sepolia Base Addresses
        // if (block.chainid == 0) {
        entryPoint = IEntryPoint(address(0x0000000071727De22E5E9d8BAf0edAc6f37da032)); // EntryPoint only works for Alchemy
        worldIdVerifierChain = 16015286601757825753; // ETH Sepolia chainId
        router = address(0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93); // Base Sepolia Router
        // }

        // Create a RecoverableAccountFactory
        RecoverableAccountFactory factory =
            new RecoverableAccountFactory(entryPoint, router, worldIdVerifier, worldIdVerifierChain);


        // Create a new RecoverableAccount
        RecoverableAccount recoverableAccount = new RecoverableAccount(entryPoint, router, worldIdVerifier, worldIdVerifierChain);

        // uint256[8] memory proof;
        // IRecoverer.RecoveryPayload memory recoveryPayload = IRecoverer.RecoveryPayload({
        //     merkleRoot: 1,
        //     proof: proof,
        //     newOwner: owner,
        //     expectedSignalHash: 1
        // });
        // bytes32 messageId = recoverableAccount.recoverAccount{value: 19609570891446417} (recoveryPayload);
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
        // console.logString(
        //     string.concat(
        //         "CCIP Message: ", vm.toString(messageId)
        //     )
        // );


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
