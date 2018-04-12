pragma solidity ^0.4.21;

import '../Pausable.sol';
import './StandardToken.sol';

/**
 * @title Pausable token
 * @dev StandardToken modified with pausable transfers.
 **/
contract PausableToken is StandardToken, Pausable {

    mapping (address => bool) public grantedToSetUnpausedWallet;

    function transfer(address _to, uint256 _value) public whenNotPaused(_to) returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused(_to) returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function grantToSetUnpausedWallet(address _to, bool permission) public {
        require(owner == msg.sender || msg.sender == Crowdsale(owner).wallets(uint8(Crowdsale.Roles.manager)));
        grantedToSetUnpausedWallet[_to] = permission;
    }

    // Add a wallet ignoring the "Exchange pause". Available to the owner of the contract.
    function setUnpausedWallet(address _wallet, bool mode) public {
        require(owner == msg.sender || grantedToSetUnpausedWallet[msg.sender] || msg.sender == Crowdsale(owner).wallets(uint8(Crowdsale.Roles.manager)));
        unpausedWallet[_wallet] = mode;
    }
}
