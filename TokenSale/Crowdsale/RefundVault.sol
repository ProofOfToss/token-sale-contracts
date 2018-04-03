pragma solidity ^0.4.21;

import '../Ownable.sol';
import '../SafeMath.sol';

// (A3)
// Contract for freezing of investors' funds. Hence, investors will be able to withdraw money if the
// round does not attain the softcap. From here the wallet of the beneficiary will receive all the
// money (namely, the beneficiary, not the manager's wallet).
contract RefundVault is Ownable {
    using SafeMath for uint256;

    enum State { Active, Refunding, Closed }

    uint8 round;

    mapping (uint8 => mapping (address => uint256)) public deposited;

    State public state;

    event Closed();
    event RefundsEnabled();
    event Refunded(address indexed beneficiary, uint256 weiAmount);
    event Deposited(address indexed beneficiary, uint256 weiAmount);

    function RefundVault() public {
        state = State.Active;
    }

    // Depositing funds on behalf of an TokenSale investor. Available to the owner of the contract (Crowdsale Contract).
    function deposit(address investor) onlyOwner public payable {
        require(state == State.Active);
        deposited[round][investor] = deposited[round][investor].add(msg.value);
        emit Deposited(investor,msg.value);
    }

    // Move the collected funds to a specified address. Available to the owner of the contract.
    function close(address _wallet1, address _wallet2, uint256 _feesValue) onlyOwner public {
        require(state == State.Active);
        require(_wallet1 != 0x0);
        state = State.Closed;
        emit Closed();
        if(_wallet2 != 0x0)
        _wallet2.transfer(_feesValue);
        _wallet1.transfer(address(this).balance);
    }

    // Allow refund to investors. Available to the owner of the contract.
    function enableRefunds() onlyOwner public {
        require(state == State.Active);
        state = State.Refunding;
        emit RefundsEnabled();
    }

    // Return the funds to a specified investor. In case of failure of the round, the investor
    // should call this method of this contract (RefundVault) or call the method claimRefund of Crowdsale
    // contract. This function should be called either by the investor himself, or the company
    // (or anyone) can call this function in the loop to return funds to all investors en masse.
    function refund(address investor) public {
        require(state == State.Refunding);
        uint256 depositedValue = deposited[round][investor];
        require(depositedValue > 0);
        deposited[round][investor] = 0;
        investor.transfer(depositedValue);
        emit Refunded(investor, depositedValue);
    }

    function restart() external onlyOwner {
        require(state == State.Closed);
        round++;
        state = State.Active;

    }

    // Destruction of the contract with return of funds to the specified address. Available to
    // the owner of the contract.
    function del(address _wallet) external onlyOwner {
        selfdestruct(_wallet);
    }
}
