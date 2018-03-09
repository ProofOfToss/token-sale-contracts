pragma solidity ^0.4.18;

import '../Ownable.sol';
import './BasicToken.sol';
import './MigrationAgent.sol';

contract MigratableToken is BasicToken,Ownable {

    uint256 public totalMigrated;
    address public migrationAgent;

    event Migrate(address indexed _from, address indexed _to, uint256 _value);

    function setMigrationAgent(address _migrationAgent) public onlyOwner {
        require(migrationAgent == 0x0);
        migrationAgent = _migrationAgent;
    }


    function migrateInternal(address _holder) internal{
        require(migrationAgent != 0x0);

        uint256 value = balances[_holder];
        balances[_holder] = 0;

        totalSupply_ = totalSupply_.sub(value);
        totalMigrated = totalMigrated.add(value);

        MigrationAgent(migrationAgent).migrateFrom(_holder, value);
        Migrate(_holder,migrationAgent,value);
    }

    function migrateAll(address[] _holders) public onlyOwner {
        for(uint i = 0; i < _holders.length; i++){
            migrateInternal(_holders[i]);
        }
    }

    // Reissue your tokens.
    function migrate() public
    {
        require(balances[msg.sender] > 0);
        migrateInternal(msg.sender);
    }

}
