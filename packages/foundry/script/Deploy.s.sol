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
        // IEntryPoint entryPoint = IEntryPoint(address(0x0000000071727De22E5E9d8BAf0edAc6f37da032)); // EntryPoint only works for Base Sepolia!

        // TODO: get actual CCIP Router and other addresses
        address fakeAddress = address(1);

        // Create a RecoverableAccountFactory
        address router = fakeAddress; // TODO
        address worldIdVerifier = fakeAddress; // TODO
        uint64 worldIdVerifierChain = 1; // TODO
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

        /**
         * This function generates the file containing the contracts Abi definitions.
         * These definitions are used to derive the types needed in the custom scaffold-eth hooks, for example.
         * This function should be called last.
         */
        address[] memory addrs = new address[](1);
        string[] memory names = new string[](1);
        addrs[0] = address(recoverableAccount);
        names[0] = "RecoverableAccount";
        exportDeployments(addrs, names);
    }

    function test() public {}
}
