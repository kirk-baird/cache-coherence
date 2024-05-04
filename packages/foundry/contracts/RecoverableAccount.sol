// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

import "@account-abstraction/core/BaseAccount.sol";
import "@account-abstraction/core/Helpers.sol";
import "@account-abstraction/samples/callback/TokenCallbackHandler.sol";

import "./Recoverer.sol";

/**
  * RecoverableAccount.
  *  This is recoverable account,
  *  has execute, eth handling methods
  *  has a single signer that can send requests through the entryPoint.
  *  The recoverable extension allows authentication through a WorldCoin ID
  */
contract RecoverableAccount is Ownable2StepUpgradeable, BaseAccount, TokenCallbackHandler, Recoverer, UUPSUpgradeable {
    /**
    * Constants and Immutables
    */
    IEntryPoint private immutable ENTRY_POINT;

    /**
    * Events
    */
    event AccountRecovered(address indexed oldOwner, address indexed newOwner);

    /*
    * Public and External Functions
    */

    // Create a RecoverableAccount
    constructor(IEntryPoint anEntryPoint, address _router, address _worldIdVerifier, uint64 _worldIdVerifierChain) Recoverer(_router, _worldIdVerifier, _worldIdVerifierChain) {
        // TODO: Add world ID, CCIP Router address, dst chain, dst address
        ENTRY_POINT = anEntryPoint;
    }

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of SimpleAccount must be deployed with the new EntryPoint address, then upgrading
      * the implementation by calling `upgradeTo()`
      * @param anOwner the owner (signer) of this account
     */
     function initialize(address anOwner) public virtual initializer {
        _initialize(anOwner);
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return ENTRY_POINT;
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     * @param dest destination address to call
     * @param value the value to pass in this call
     * @param func the calldata to pass in this call
     */
    function execute(address dest, uint256 value, bytes calldata func) external {
        _requireFromEntryPointOrOwner();
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
     * @param dest an array of destination addresses
     * @param value an array of values to pass to each call. can be zero-length for no-value calls
     * @param func an array of calldata to pass to each call
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func) external {
        _requireFromEntryPointOrOwner();
        require(dest.length == func.length && (value.length == 0 || value.length == func.length), "wrong array lengths");
        if (value.length == 0) {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], 0, func[i]);
            }
        } else {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], value[i], func[i]);
            }
        }
    }

    /**
     * check current account deposit in the entryPoint
     */
     function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    /**
    * Recovery function to begin update of the `owner` address.
    * Authenticates identity via WorldCoin
    */
    function recoverAccount(address newOwner, RecoveryPayload calldata recoveryPayload) external {
        // TODO: Add function parameters
        // TODO: Call CCIP with world coin authentication

        transferOwnership(newOwner);
    }

    /**
    * Callback after WorldCoin authentication has occurred
    * Called from CCIP bridge to confirm authentication
    */
    function callbackRecoverAccount() external {
        // TODO: Verify caller is CCIP Bridge
        // TODO: Update owner address to new address

        // TODO: Emit event details
        // emit AccountRecovered(oldOwner, newOwner);
    }

    function supportsInterface(bytes4 interfaceId) public pure override(CCIPReceiver, TokenCallbackHandler) returns (bool) {
        // TODO: I don't think this is correct
        return CCIPReceiver.supportsInterface(interfaceId) || super.supportsInterface(interfaceId);
    }

    /*
    * Internal and Private functions
    */


    // Overrides OZ's Ownable.sol to support calls to itself
    function _checkOwner() internal view override {
        if (owner() != _msgSender() || address(this) != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    // Require the function call went through EntryPoint or owner
    function _requireFromEntryPointOrOwner() internal view {
        require(msg.sender == address(entryPoint()) || msg.sender == owner(), "account: not Owner or EntryPoint");
    }

    /// implement template method of BaseAccount
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
    internal override virtual returns (uint256 validationData) {
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        if (owner() != ECDSA.recover(hash, userOp.signature))
            return SIG_VALIDATION_FAILED;
        return SIG_VALIDATION_SUCCESS;
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        (newImplementation);
        // TODO: Verification
        require(msg.sender == owner());
    }

    function _initialize(address anOwner) internal virtual {
        _transferOwnership(anOwner);
    }

}

