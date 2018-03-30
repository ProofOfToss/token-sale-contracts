pragma solidity ^0.4.21;

import './PausableToken.sol';

contract FreezingToken is PausableToken {
    struct freeze {
    uint256 amount;
    uint256 when;
    }


    mapping (address => freeze) freezedTokens;


    // @ Do I have to use the function      no
    // @ When it is possible to call        any time
    // @ When it is launched automatically  -
    // @ Who can call the function          any
    function freezedTokenOf(address _beneficiary) public view returns (uint256 amount){
        freeze storage _freeze = freezedTokens[_beneficiary];
        if(_freeze.when < now) return 0;
        return _freeze.amount;
    }

    // @ Do I have to use the function      no
    // @ When it is possible to call        any time
    // @ When it is launched automatically  -
    // @ Who can call the function          any
    function defrostDate(address _beneficiary) public view returns (uint256 Date) {
        freeze storage _freeze = freezedTokens[_beneficiary];
        if(_freeze.when < now) return 0;
        return _freeze.when;
    }


    // ***CHECK***SCENARIO***
    function freezeTokens(address _beneficiary, uint256 _amount, uint256 _when) public {
        require(owner == msg.sender || msg.sender == Crowdsale(owner).wallets(uint8(Crowdsale.Roles.manager)));
        freeze storage _freeze = freezedTokens[_beneficiary];
        _freeze.amount = _amount;
        _freeze.when = _when;
    }

    // ***CHECK***SCENARIO***
    function masFreezedTokens(address[] _beneficiary, uint256[] _amount, uint256[] _when) public {
        require(owner == msg.sender || msg.sender == Crowdsale(owner).wallets(uint8(Crowdsale.Roles.manager)));
        require(_beneficiary.length == _amount.length && _beneficiary.length == _when.length);
        for(uint16 i = 0; i < _beneficiary.length; i++){
            freeze storage _freeze = freezedTokens[_beneficiary[i]];
            _freeze.amount = _amount[i];
            _freeze.when = _when[i];
        }
    }


    function transferAndFreeze(address _to, uint256 _value, uint256 _when) external {
        require(unpausedWallet[msg.sender]);
        if(_when > 0){
            freeze storage _freeze = freezedTokens[_to];
            _freeze.amount = _freeze.amount.add(_value);
            _freeze.when = (_freeze.when > _when)? _freeze.when: _when;
        }
        transfer(_to,_value);
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balanceOf(msg.sender) >= freezedTokenOf(msg.sender).add(_value));
        return super.transfer(_to,_value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(balanceOf(_from) >= freezedTokenOf(_from).add(_value));
        return super.transferFrom( _from,_to,_value);
    }



}
