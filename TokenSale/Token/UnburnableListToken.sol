pragma solidity ^0.4.21;

import './BurnableToken.sol';
import '../Crowdsale/Crowdsale.sol';

contract UnburnableListToken is BurnableToken {

    mapping (address => bool) public grantedToSetUnburnableWallet;
    mapping (address => bool) public unburnableWallet;

    function grantToSetUnburnableWallet(address _to, bool permission) public {
        require(owner == msg.sender || msg.sender == Crowdsale(owner).wallets(uint8(Crowdsale.Roles.manager)));
        grantedToSetUnburnableWallet[_to] = permission;
    }

    // Add a wallet to unburnable list. After adding wallet can not be removed from list. Available to the owner of the contract.
    function setUnburnableWallet(address _wallet) public {
        require(owner == msg.sender || grantedToSetUnburnableWallet[msg.sender] || msg.sender == Crowdsale(owner).wallets(uint8(Crowdsale.Roles.manager)));
        unburnableWallet[_wallet] = true;
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
    function burn(address _beneficiary, uint256 _value) public onlyOwner {
        require(!unburnableWallet[_beneficiary]);

        return super.burn(_beneficiary, _value);
    }
}
