pragma solidity ^0.4.21;

import '../Ownable.sol';
import '../SafeMath.sol';
import '../Token/ERC20Basic.sol';

// (B)
// The contract for freezing tokens for the team..
contract AllocationTOSS is Ownable {
    using SafeMath for uint256;

    struct Share {
    uint256 proportion;
    uint256 forPart;
    }

    // How many days to freeze from the moment of finalizing ICO
    uint256 public unlockPart1;
    uint256 public unlockPart2;
    uint256 public totalShare;

    mapping(address => Share) public shares;

    ERC20Basic public token;

    address public owner;

    // The contract takes the ERC20 coin address from which this contract will work and from the
    // owner (Team wallet) who owns the funds.
    function AllocationTOSS(ERC20Basic _token, uint256 _unlockPart1, uint256 _unlockPart2) public{
        unlockPart1 = _unlockPart1;
        unlockPart2 = _unlockPart2;
        token = _token;
    }

    function addShare(address _beneficiary, uint256 _proportion, uint256 _percenForFirstPart) onlyOwner external {
        shares[_beneficiary] = Share(shares[_beneficiary].proportion.add(_proportion),_percenForFirstPart);
        totalShare = totalShare.add(_proportion);
    }

    // If the time of freezing expired will return the funds to the owner.
    function unlockFor(address _owner) public {
        require(now >= unlockPart1);
        uint256 share = shares[_owner].proportion;
        if (now < unlockPart2) {
            share = share.mul(shares[_owner].forPart)/100;
            shares[_owner].forPart = 0;
        }
        if (share > 0) {
            uint256 unlockedToken = token.balanceOf(this).mul(share).div(totalShare);
            shares[_owner].proportion = shares[_owner].proportion.sub(share);
            totalShare = totalShare.sub(share);
            token.transfer(_owner,unlockedToken);
        }
    }
}
