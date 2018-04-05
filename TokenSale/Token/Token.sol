pragma solidity ^0.4.21;

import './FreezingToken.sol';
import './MintableToken.sol';
import './MigratableToken.sol';
import './BurnableToken.sol';
import '../Pausable.sol';
import "../ERC223ReceivingContract.sol";

// (A2)
// Contract token
contract Token is FreezingToken, MintableToken, MigratableToken, BurnableToken {
    string public constant name = "TOSS";
    string public constant symbol = "PROOF OF TOSS";
    uint8 public constant decimals = 18;

    mapping (address => mapping (address => bool)) public grantedToAllowBlocking; // Address of smart contract that can allow other contracts to block tokens
    mapping (address => mapping (address => bool)) public allowedToBlocking; // Address of smart contract that can block tokens
    mapping (address => mapping (address => uint256)) public blocked; // Blocked tokens

    event TokenOperationEvent(string operation, address indexed from, address indexed to, uint256 value, address indexed _contract);

    /**
     * @dev Transfer the specified amount of tokens to the specified address.
     *      Invokes the `tokenFallback` function if the recipient is a contract.
     *      The token transfer fails if the recipient is a contract
     *      but does not implement the `tokenFallback` function
     *      or the fallback function to receive funds.
     *
     * @param _to    Receiver address.
     * @param _value Amount of tokens that will be transferred.
     * @param _data  Transaction metadata.
     */
    function transferToContract(address _to, uint _value, bytes _data) public returns (bool) {
        // Standard function transfer similar to ERC20 transfer with no _data .
        // Added due to backwards compatibility reasons .
        uint codeLength;

        assembly {
            // Retrieve the size of the code on target address, this needs assembly .
            codeLength := extcodesize(_to)
        }

        require(codeLength > 0);

        super.transfer(_to, _value);

        ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
        receiver.tokenFallback(msg.sender, _value, _data);

        return true;
    }

    // @brief Allow another contract to allow another contract to block tokens. Can be revoked
    // @param _spender another contract address
    // @param _value amount of approved tokens
    function grantToAllowBlocking(address _contract, bool permission) {
        uint codeLength;

        assembly { // Retrieve the size of the code on target address, this needs assembly .
            codeLength := extcodesize(_contract)
        }

        if (codeLength <= 0) throw; // Only smart contracts allowed

        grantedToAllowBlocking[msg.sender][_contract] = permission;

        emit TokenOperationEvent('grant_allow_blocking', msg.sender, _contract, 0, 0);
    }

    // @brief Allow another contract to block tokens. Can't be revoked
    // @param _owner tokens owner
    // @param _contract another contract address
    function allowBlocking(address _owner, address _contract) {
        uint codeLength;

        assembly { // Retrieve the size of the code on target address, this needs assembly .
            codeLength := extcodesize(_contract)
        }

        if (codeLength <= 0) throw; // Only smart contracts allowed
        if (_contract == msg.sender) throw;
        if (_contract == _owner) throw;
        if (! grantedToAllowBlocking[_owner][msg.sender]) throw;

        allowedToBlocking[_owner][_contract] = true;

        emit TokenOperationEvent('allow_blocking', _owner, _contract, 0, msg.sender);
    }

    // @brief Check if contract is granted to allow blocking to other contracts
    // @param _owner owner of allowance
    // @param _spender spender contract
    // @return the rest of allowed tokens
    function allowanceToAllowBlocking(address _owner, address _contract) constant returns (bool granted) {
        return grantedToAllowBlocking[_owner][_contract];
    }

    // @brief Blocks tokens
    // @param _blocking The address of tokens which are being blocked
    // @param _value The blocked token count
    function block(address _blocking, uint256 _value) whenNotPaused(_blocking) {
        if (! allowedToBlocking[_blocking][msg.sender]) throw;
        if (balances[_blocking] < _value || _value <= 0) throw;

        balances[_blocking] -= _value;
        blocked[_blocking][msg.sender] += _value;

        emit TokenOperationEvent('block', _blocking, 0, _value, msg.sender);
    }

    // @brief Unblocks tokens and sends them to the given address (to _unblockTo)
    // @param _blocking The address of tokens which are blocked
    // @param _unblockTo The address to send to the blocked tokens after unblocking
    // @param _value The blocked token count to unblock
    function unblock(address _blocking, address _unblockTo, uint256 _value) whenNotPaused(_unblockTo) {
        if (blocked[_blocking][msg.sender] == 0) throw;
        if (! allowedToBlocking[_blocking][msg.sender]) throw;
        if (blocked[_blocking][msg.sender] < _value) throw;

        blocked[_blocking][msg.sender] -= _value;
        balances[_unblockTo] += _value;

        emit TokenOperationEvent('unblock', _blocking, _unblockTo, _value, msg.sender);
    }
}
