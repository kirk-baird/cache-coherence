//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../contracts/RecoverableAccount.sol";
import "../contracts/RecoverableAccountFactory.sol";
import "./DeployHelpers.s.sol";

contract DeployScript is ScaffoldETHDeploy {
    error InvalidPrivateKey(string);

    function run() external {
        uint256 deployerPrivateKey = setupLocalhostEnv();
        if (deployerPrivateKey == 0) {
            revert InvalidPrivateKey(
                "You don't have a deployer account. Make sure you have set DEPLOYER_PRIVATE_KEY in .env or use `yarn generate` to generate a new random account"
            );
        }
        address owner = vm.addr(deployerPrivateKey);
        console.logAddress(owner);

        vm.startBroadcast(deployerPrivateKey);

        // TODO: get actual CCIP Router and other addresses
        address fakeAddress = address(1);

        address router = fakeAddress; // TODO
        address worldIdVerifier = fakeAddress; // TODO
        uint64 worldIdVerifierChain = 1; // TODO
        IEntryPoint entryPoint = IEntryPoint(address(0x0000000071727De22E5E9d8BAf0edAc6f37da032)); // EntryPoint only works for Base Sepolia!
        RecoverableAccountFactory factory =
            new RecoverableAccountFactory(entryPoint, router, worldIdVerifier, worldIdVerifierChain);

        vm.stopBroadcast();

        /**
         * This function generates the file containing the contracts Abi definitions.
         * These definitions are used to derive the types needed in the custom scaffold-eth hooks, for example.
         * This function should be called last.
         */
        exportDeployments();
    }

    function test() public {}
}
