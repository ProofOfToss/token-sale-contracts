pragma solidity ^0.4.21;

import '../Ownable.sol';
import '../SafeMath.sol';
import '../Token/ERC20Basic.sol';

contract AllocationQueue is Ownable {
    using SafeMath for uint256;

    // address => date => tokens
    mapping(address => mapping(uint256 => uint256)) public queue;
    uint256 public totalShare;

    ERC20Basic public token;

    function AllocationQueue(ERC20Basic _token) public {
        token = _token;
    }

    function groupDates(uint256 _date) internal view returns (uint256) {
        return _date.div(30*24*60*60);
    }

    function addShare(address _beneficiary, uint256 _tokens, uint256 _freezeTime) onlyOwner external {
        require(token.balanceOf(this) == totalShare.add(_tokens));

        uint256 currentDate = groupDates(now);
        uint256 unfreezeDate = groupDates(now.add(_freezeTime));

        require(unfreezeDate > currentDate);

        queue[_beneficiary][unfreezeDate] = queue[_beneficiary][unfreezeDate].add(_tokens);
        totalShare = totalShare.add(_tokens);
    }

    function unlockFor(address _owner, uint256 _date) public {
        require(groupDates(_date) <= groupDates(now));

        uint256 date = groupDates(_date);
        uint256 share = queue[_owner][date];

        queue[_owner][date] = 0;

        if (share > 0) {
            token.transfer(_owner,share);
            totalShare = totalShare.sub(share);
        }
    }
}
