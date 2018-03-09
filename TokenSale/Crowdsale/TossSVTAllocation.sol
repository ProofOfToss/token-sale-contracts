pragma solidity ^0.4.18;

import '../Token/ERC20Basic.sol';
import '../SafeMath.sol';

// (B)
// The contract for freezing tokens for the team..
contract TossSVTAllocation {
    using SafeMath for uint256;

    // How many days to freeze from the moment of finalizing ICO
    uint256 public UnlockPart1 = now + 1 years;
    uint256 public UnlockPart2 = now + 2 years;
    uint256 public ProcentForPart1 = 50;

    ERC20Basic public token;

    address public owner;

    // The contract takes the ERC20 coin address from which this contract will work and from the
    // owner (Team wallet) who owns the funds.
    function TossSVTAllocation(ERC20Basic _token, address _owner) public{

        token = _token;
        owner = _owner;
    }

    // If the time of freezing expired will return the funds to the owner.
    function unlock() public {
        require(now >= UnlockPart1);
        uint256 unlockedToken = token.balanceOf(this);
        if(now < UnlockPart2){
            unlockedToken = unlockedToken.mul(ProcentForPart1)/100;
            ProcentForPart1 = 0;
        }
        token.transfer(owner,unlockedToken);
    }
}
