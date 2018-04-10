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


    //!!!Добавил модификатор
    modifier contractOnly(address _to) {
        uint256 codeLength;

        assembly {
        // Retrieve the size of the code on target address, this needs assembly .
        codeLength := extcodesize(_to)
        }

        require(codeLength > 0);

        _;
    }

    /**
    * @dev Transfer the specified amount of tokens to the specified address.
    * Invokes the `tokenFallback` function if the recipient is a contract.
    * The token transfer fails if the recipient is a contract
    * but does not implement the `tokenFallback` function
    * or the fallback function to receive funds.
    *
    * @param _to Receiver address.
    * @param _value Amount of tokens that will be transferred.
    * @param _data Transaction metadata.
    */

    //!!! Добавил модификатор public
    function transferToContract(address _to, uint _value, bytes _data) public contractOnly(_to) returns (bool) {
        // Standard function transfer similar to ERC20 transfer with no _data .
        // Added due to backwards compatibility reasons .

        //!!!Убал проверку, теперь она в модификаторе

        super.transfer(_to, _value);

        ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
        receiver.tokenFallback(msg.sender, _value, _data);

        return true;
    }

    // @brief Allow another contract to allow another contract to block tokens. Can be revoked
    // @param _spender another contract address
    // @param _value amount of approved tokens
    //!!! Добавил модификатор public
    function grantToAllowBlocking(address _contract, bool permission) contractOnly(_contract) public {

        //!!!Убал проверку, теперь она в модификаторе

        grantedToAllowBlocking[msg.sender][_contract] = permission;

        emit TokenOperationEvent('grant_allow_blocking', msg.sender, _contract, 0, 0);
    }

    // @brief Allow another contract to block tokens. Can't be revoked
    // @param _owner tokens owner
    // @param _contract another contract address
    //!!! Добавил модификатор public
    function allowBlocking(address _owner, address _contract) contractOnly(_contract) public {

        //!!! Заменил if(condition) throw на require

        require(_contract != msg.sender && _contract != owner);

        require(grantedToAllowBlocking[_owner][msg.sender]);

        allowedToBlocking[_owner][_contract] = true;

        emit TokenOperationEvent('allow_blocking', _owner, _contract, 0, msg.sender);
    }

    // @brief Blocks tokens
    // @param _blocking The address of tokens which are being blocked
    // @param _value The blocked token count
    //!!! Добавил модификатор public
    //!!! Внимание! название метода перекрывает ключевое слово block!
    function blockTokens(address _blocking, uint256 _value) whenNotPaused(_blocking) public {
        //!!! Заменил if(condition) throw на require
        require(allowedToBlocking[_blocking][msg.sender]);

        require(balanceOf(_blocking) >= freezedTokenOf(_blocking).add(_value) && _value > 0);

        balances[_blocking] = balances[_blocking].sub(_value);
        blocked[_blocking][msg.sender] = blocked[_blocking][msg.sender].add(_value);

        emit TokenOperationEvent('block', _blocking, 0, _value, msg.sender);
    }

    // @brief Unblocks tokens and sends them to the given address (to _unblockTo)
    // @param _blocking The address of tokens which are blocked
    // @param _unblockTo The address to send to the blocked tokens after unblocking
    // @param _value The blocked token count to unblock
    //!!! Добавил модификатор public
    function unblockTokens(address _blocking, address _unblockTo, uint256 _value) whenNotPaused(_unblockTo) public {
        //!!! Заменил if(condition) throw на require
        require(allowedToBlocking[_blocking][msg.sender]);
        require(blocked[_blocking][msg.sender] >= _value && _value > 0);

        blocked[_blocking][msg.sender] = blocked[_blocking][msg.sender].sub(_value);
        balances[_unblockTo] = balances[_unblockTo].add(_value);

        emit TokenOperationEvent('unblock', _blocking, _unblockTo, _value, msg.sender);
    }
}
