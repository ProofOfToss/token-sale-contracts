pragma solidity ^0.4.21;

import './FreezingToken.sol';
import './MintableToken.sol';
import './MigratableToken.sol';
import './BurnableToken.sol';

// (A2)
// Contract token
contract Token is FreezingToken, MintableToken, MigratableToken, BurnableToken{
    string public constant name = "TOSS";
    string public constant symbol = "PROOF OF TOSS";
    uint8 public constant decimals = 18;
}
