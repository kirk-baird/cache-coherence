// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/RecoverableAccount.sol";

contract YourContractTest is Test {
    RecoverableAccount public recoverableAccount;

    function setUp() public {
        // recoverableAccount = new RecoverableAccount(vm.addr(1));
    }
}
