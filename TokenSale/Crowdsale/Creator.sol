pragma solidity ^0.4.21;

import './RefundVault.sol';
import './AllocationToss.sol';
import './PeriodicAllocation.sol';
import '../Token/Token.sol';

contract Creator{
    Token public token = new Token();
    RefundVault public refund = new RefundVault();

    function createToken() external returns (Token) {
        token.transferOwnership(msg.sender);
        return token;
    }

    function createAllocation(Token _token, uint256 _unlockPart1, uint256 _unlockPart2) external returns (AllocationTOSS) {
        AllocationTOSS allocation = new AllocationTOSS(_token,_unlockPart1,_unlockPart2);
        allocation.transferOwnership(msg.sender);
        return allocation;
    }

    function createPeriodicAllocation(Token _token, uint256 _unlockStart) external returns (PeriodicAllocation) {
        PeriodicAllocation allocation = new PeriodicAllocation(_token,_unlockStart);
        allocation.transferOwnership(msg.sender);
        return allocation;
    }

    function createRefund() external returns (RefundVault) {
        refund.transferOwnership(msg.sender);
        return refund;
    }

}
