pragma solidity ^0.4.21;

import './RefundVault.sol';
import './PeriodicAllocation.sol';
import './AllocationQueue.sol';
import '../Token/Token.sol';

contract Creator{
    Token public token = new Token();
    RefundVault public refund = new RefundVault();

    function createToken() external returns (Token) {
        token.transferOwnership(msg.sender);
        return token;
    }

    function createPeriodicAllocation(Token _token) external returns (PeriodicAllocation) {
        PeriodicAllocation allocation = new PeriodicAllocation(_token);
        allocation.transferOwnership(msg.sender);
        return allocation;
    }

    function createAllocationQueue(Token _token) external returns (AllocationQueue) {
        AllocationQueue allocation = new AllocationQueue(_token);
        allocation.transferOwnership(msg.sender);
        return allocation;
    }

    function createRefund() external returns (RefundVault) {
        refund.transferOwnership(msg.sender);
        return refund;
    }

}
