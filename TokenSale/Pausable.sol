pragma solidity ^0.4.18;

import './Ownable.sol';

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {

    mapping (address => bool) public unpausedWallet;

    event Pause();
    event Unpause();

    bool public paused = false;


    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused(address _to) {
        require(!paused||unpausedWallet[msg.sender]||unpausedWallet[_to]);
        _;
    }

    // Add a wallet ignoring the "Exchange pause". Available to the owner of the contract.
    function addUnpausedWallet(address _wallet) public onlyOwner {
        unpausedWallet[_wallet] = true;
    }

    // Remove the wallet ignoring the "Exchange pause". Available to the owner of the contract.
    function delUnpausedWallet(address _wallet) public onlyOwner {
        unpausedWallet[_wallet] = false;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() onlyOwner public {
        require(!paused);
        paused = true;
        Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() onlyOwner public {
        require(paused);
        paused = false;
        Unpause();
    }
}
