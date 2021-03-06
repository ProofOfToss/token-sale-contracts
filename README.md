# Solidity smart-contracts for Proof of Toss token sale

Status: WIP & testing

## Requirements

* Solidity >= 4.0.21

## Description

The repository contains all necessary smart-contracts for Proof of Toss token sale:

* [Crowdsale contracts](TokenSale/Crowdsale):
    * Crowdsale: the crowdsale contract itself
    * RefundVault: the vault to refund the funds transferred to Crowdsale contract in case of failed token sale
    * AllocationToss: the contract to keep locked tokens reserved for Proof of Toss team
* [Token contract](TokenSale/Token):
    * ERC20Basic: basic version of ERC20 token interface (OpenZeppelin)
    * ERC20: full ERC20 token interface (OpenZeppelin)
    * BasicToken: basic version of StandardToken (OpenZeppelin)
    * StandardToken: full version of ERC20 token (OpenZeppelin)
    * BurnableToken: implementation of burnable token functionality
    * PausableToken: implementation of pausable token functionality (OpenZeppelin)
    * MintableToken: implementation of mintable token functionality (OpenZeppelin)
    * FreezingToken: implementation of freezing token functionality
    * MigratableToken: implementation of migratable token functionality
    * MigrationAgent: the migration agent to use in MigrablteToken
    * Token: the token itself for Proof of Toss token sale
* Ownable: base contract of ownable behaviour (OpenZeppelin)
* Pausable: base contract of pausable behaviour (OpenZeppelin with modifications)
* SafeMath: Math operations with safety checks that throw on error (OpenZeppelin)

Some of the contracts are taken from OpenZeppelin project with following modifications:

* Pausable: added unpaused wallets to ignore the pause for specific addresses 

## TODO

* Add operator deposit amount blocking/unblocking functions to TossToken smart-contract
* Add Solidity unit tests
* Set correct Proof of Toss team wallet addresses
* Set correct soft/hard cap and minimum payment values
* Mention non-ETH wallet addresses in Crowdsale::paymentsInOtherCurrency() function
* Perform third-party code audit

## How to deploy

Any possible options to compile and deploy contracts will work. You could use any of available ways to do it:

* e.g. compile via [Remix](https://remix.ethereum.org) (choose Solidity 4.0.19 and check the optimization option) and deploy via [MyEtherWallet](https://myetherwallet.com/)
* or integrate these contracts into Truffle box - this is the way we have chosen (info is below)

## Truffle Sandbox

Smart-contracts are integrated into our Truffle sandbox: https://github.com/ProofOfToss/token-sale-sandbox

It is possible to compile and deploy token sale smart-contracts to testrpc or mainnet/testnet with it.

Please read carefully the instructions in [Truffle sandbox repository](https://github.com/ProofOfToss/token-sale-sandbox)!
