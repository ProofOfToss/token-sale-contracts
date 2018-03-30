pragma solidity ^0.4.21;

import './Ownable.sol';

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {

    mapping (address => bool) public unpausedWallet;

    event Pause();
    event Unpause();

    bool public paused = true;


    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused(address _to) {
        require(!paused||unpausedWallet[msg.sender]||unpausedWallet[_to]);
        _;
    }

    // Add a wallet ignoring the "Exchange pause". Available to the owner of the contract.
    function setUnpausedWallet(address _wallet, bool mode) public {
        require(owner == msg.sender || msg.sender == Crowdsale(owner).wallets(uint8(Crowdsale.Roles.manager)));
        unpausedWallet[_wallet] = mode;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function setPause(bool mode) public onlyOwner {
        if (!paused && mode) {
            paused = true;
            emit Pause();
        }
        if (paused && !mode) {
            paused = false;
            emit Unpause();
        }
    }

}
