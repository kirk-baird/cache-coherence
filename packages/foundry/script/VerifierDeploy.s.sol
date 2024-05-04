//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../contracts/world-id-verification-chain/WorldIDVerifier.sol";
import "./DeployHelpers.s.sol";
import "forge-std/Script.sol";
import "forge-std/Vm.sol";
import {IWorldID} from "../contracts/interfaces/IWorldID.sol";

contract DeployScript is ScaffoldETHDeploy {
    error InvalidPrivateKey(string);

    // Run WorldIdVerifier
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

        // Create a new RecoverableAccount
        IWorldID worldId = 	IWorldID(address(0x469449f251692E0779667583026b5A1E99512157));
        address router = address(0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59);
        string memory appId = "cache-coherence";
        string memory actionId = "cache-coherence-recover";
        WorldIDVerifier verifier = new WorldIDVerifier(worldId, router, appId, actionId);

        vm.stopBroadcast();

        console.logString(
            string.concat(
                "WorldIDVerifier deployed at: ", vm.toString(address(verifier))
            )
        );
    }

    function test() public {}
}
