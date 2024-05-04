// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "contracts/WorldIDVerifierInstance.sol";

contract WorldIDVerifierInstanceTest is Test {
    WorldIDVerifierInstance public worldIDVerifier;

    address public alice = makeAddr("alice");

    // Ethereum Sepolia
    IWorldID public worldID =
        IWorldID(0x469449f251692E0779667583026b5A1E99512157);
    address public ccipRouter = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    string private constant APP_ID =
        "app_staging_8e12a99bd10cac0f5e110ca03d0eaf21";
    string private constant ACTION_ID = "test-recovery-action";

    uint256[8] proof = [
        0x04170cb9d00237ba1f07e398c0c1f3515fb16b8e9fcc5094329924218f617d19,
        0x2587bf2268a4d3037c44cd0c4254b982c497f2c242472aa981a87006581514b1,
        0x25a40e5c4cbf2d4d17f67e1b8ef33b2fd037d8d89ccd4015be587ae50e5a2a53,
        0x05258621f94e1b19a9322f70ae932bbfd724e3044976ac474dab587f05f601d8,
        0x13de0b84026a97b21243c01923399642bf305c0202bd092c363e58c3e07350ab,
        0x09277ce3a2d0998310148d4aebe7062feac38e48706bdbb58b0c1ad4e111eeca,
        0x0a51e2635eca1fa13b5efab94769b154647bdf7020f9ac2a25bbb27abd97e34c,
        0x1a2b630d756dd76dcb87e340a722b3c45654fc99550a8c2dab6b55c628e329c8
    ];

    uint256 merkleRoot =
        0x1c499e00d910a10771042e167ed6a1b910ee1c3d92dec2e1fc6f32af938675e0;
    uint256 nullifierHash =
        0x15a1ea4b221550e60fa9db357257dda46df5765354bdcdd3ab1f31f23fc7646f;

    IRecoverer.RegistrationPayload registrationPayload;

    // uint256 ethSepoliaFork;

    // string immutable ETH_SEPOLIA_S

    function setUp() public {
        worldIDVerifier = new WorldIDVerifierInstance(
            worldID,
            ccipRouter, // ccipRouter
            APP_ID, // appId
            ACTION_ID // actionId
        );
    }

    function test_register() public {
        // bytes memory registrationSignal = worldIDVerifier.encodeRegistrationSignal(alice);
        uint256 registrationSignalHash = ByteHasher.hashToField("");

        registrationPayload = IRecoverer.RegistrationPayload({
            merkleRoot: merkleRoot,
            newNullifierHash: nullifierHash,
            proof: proof,
            expectedSignalHash: registrationSignalHash
        });

        worldIDVerifier.register(registrationPayload);

        assertGt(worldIDVerifier.nullifierHash(), 0, "Nullifier hash not set");
    }
}
