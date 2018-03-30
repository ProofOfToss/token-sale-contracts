pragma solidity ^0.4.21;

import './FreezingToken.sol';
import './MintableToken.sol';
import './MigratableToken.sol';

// (A2)
// Contract token
contract TossToken is FreezingToken, MintableToken, MigratableToken {
    string public constant name = "TOSS";
    string public constant symbol = "PROOF OF TOSS";
    uint8 public constant decimals = 18;

    function TossToken() public{
        owner = 0x0;
    }

    function setOwner() public {
        require(owner == 0x0);
        owner = msg.sender;
    }
}
