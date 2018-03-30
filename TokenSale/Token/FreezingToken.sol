pragma solidity ^0.4.21;

import './PausableToken.sol';

contract FreezingToken is PausableToken {
    struct freeze {
    uint256 amount;
    uint256 when;
    }

    address public freezingManager;
    mapping (address => bool) public freezingAgent;

    mapping (address => freeze) freezedTokens;

    function freezedTokenOf(address _beneficiary) public view returns (uint256 amount){
        freeze storage _freeze = freezedTokens[_beneficiary];
        if(_freeze.when < now) return 0;
        return _freeze.amount;
    }

    function defrostDate(address _beneficiary) public view returns (uint256 Date) {
        freeze storage _freeze = freezedTokens[_beneficiary];
        if(_freeze.when < now) return 0;
        return _freeze.when;
    }

    function freezeTokens(address _beneficiary, uint256 _amount, uint256 _when) onlyOwner public {
        freeze storage _freeze = freezedTokens[_beneficiary];
        _freeze.amount = _amount;
        _freeze.when = _when;
    }

    function setFreezingManager(address _newAddress) external {
        require(msg.sender == owner || msg.sender == freezingManager);
        freezingAgent[freezingManager] = false;
        freezingManager = _newAddress;
        freezingAgent[freezingManager] = true;
    }

    function changeFreezingAgent(address _agent, bool _right) external {
        require(msg.sender == freezingManager);
        freezingAgent[_agent] = _right;
    }

    function transferAndFreeze(address _to, uint256 _value, uint256 _when) external {
        require(freezingAgent[msg.sender]);
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
