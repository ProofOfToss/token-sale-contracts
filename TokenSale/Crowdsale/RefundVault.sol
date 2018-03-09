pragma solidity ^0.4.0;

import '../Ownable.sol';
import '../SafeMath.sol';

// (A3)
// Contract for freezing of investors' funds. Hence, investors will be able to withdraw money if the
// round does not attain the softcap. From here the wallet of the beneficiary will receive all the
// money (namely, the beneficiary, not the manager's wallet).
contract RefundVault is Ownable {
    using SafeMath for uint256;

    enum State { Active, Refunding, Closed }

    mapping (address => uint256) public deposited;
    State public state;

    event Closed();
    event RefundsEnabled();
    event Refunded(address indexed beneficiary, uint256 weiAmount);
    event Deposited(address indexed beneficiary, uint256 weiAmount);

    function RefundVault() public {
        state = State.Active;
    }

    // Depositing funds on behalf of an ICO investor. Available to the owner of the contract (Crowdsale Contract).
    function deposit(address investor) onlyOwner public payable {
        require(state == State.Active);
        deposited[investor] = deposited[investor].add(msg.value);
        Deposited(investor,msg.value);
    }

    // Move the collected funds to a specified address. Available to the owner of the contract.
    function close(address _wallet) onlyOwner public {
        require(state == State.Active);
        require(_wallet != 0x0);
        state = State.Closed;
        Closed();
        _wallet.transfer(this.balance);
    }

    // Allow refund to investors. Available to the owner of the contract.
    function enableRefunds() onlyOwner public {
        require(state == State.Active);
        state = State.Refunding;
        RefundsEnabled();
    }

    // Return the funds to a specified investor. In case of failure of the round, the investor
    // should call this method of this contract (RefundVault) or call the method claimRefund of Crowdsale
    // contract. This function should be called either by the investor himself, or the company
    // (or anyone) can call this function in the loop to return funds to all investors en masse.
    function refund(address investor) public {
        require(state == State.Refunding);
        require(deposited[investor] > 0);
        uint256 depositedValue = deposited[investor];
        deposited[investor] = 0;
        investor.transfer(depositedValue);
        Refunded(investor, depositedValue);
    }

    // Destruction of the contract with return of funds to the specified address. Available to
    // the owner of the contract.
    function del(address _wallet) external onlyOwner {
        selfdestruct(_wallet);
    }
}
