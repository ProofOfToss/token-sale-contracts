pragma solidity ^0.4.21;

import '../SafeMath.sol';
import '../Token/Token.sol';
import './RefundVault.sol';
import './AllocationToss.sol';
import './Creator.sol';

// (A1)
// The main contract for the sale and management of rounds.
// 0000000000000000000000000000000000000000000000000000000000000000
contract Crowdsale{

    uint256 constant USER_UNPAUSE_TOKEN_TIMEOUT =  60 days;
    uint256 constant FORCED_REFUND_TIMEOUT1     = 400 days;
    uint256 constant FORCED_REFUND_TIMEOUT2     = 600 days;
    uint256 constant ROUND_PROLONGATE           =   0 days;
    uint256 constant BURN_TOKENS_TIME           =  90 days;

    using SafeMath for uint256;

    enum TokenSaleType {round1, round2}
    TokenSaleType public TokenSale = TokenSaleType.round2;

    //              0             1         2        3        4        5      6       7        8     9
    enum Roles {beneficiary, accountant, manager, observer, bounty, company, team, founders, fund, fees}

    Creator public creator;
    bool creator2;
    bool isBegin=false;
    Token public token;
    RefundVault public vault;
    AllocationTOSS public allocation;
    //FeesStrategy public feesStrategy;

    bool public isFinalized;
    bool public isInitialized;
    bool public isPausedCrowdsale;
    bool public chargeBonuses;
    bool public canFirstMint=true;

    // Initially, all next 7+ roles/wallets are given to the Manager. The Manager is an employee of the company
    // with knowledge of IT, who publishes the contract and sets it up. However, money and tokens require
    // a Beneficiary and other roles (Accountant, Team, etc.). The Manager will not have the right
    // to receive them. To enable this, the Manager must either enter specific wallets here, or perform
    // this via method changeWallet. In the finalization methods it is written which wallet and
    // what percentage of tokens are received.
    address[10] public wallets = [

    // Beneficiary
    // Receives all the money (when finalizing Round1 & Round2)
    msg.sender,

    // Accountant
    // Receives all the tokens for non-ETH investors (when finalizing Round1 & Round2)
    msg.sender,

    // Manager
    // All rights except the rights to receive tokens or money. Has the right to change any other
    // wallets (Beneficiary, Accountant, ...), but only if the round has not started. Once the
    // round is initialized, the Manager has lost all rights to change the wallets.
    // If the TokenSale is conducted by one person, then nothing needs to be changed. Permit all 7 roles
    // point to a single wallet.
    msg.sender,

    // Observer
    // Has only the right to call paymentsInOtherCurrency (please read the document)
    msg.sender,

    // Bounty - 2% tokens
    msg.sender,

    // Company, White list 1%
    msg.sender,

    // Team, 6%, freeze 1+1 year
    msg.sender,

    // Founders, 10% freeze 1+1 year
    msg.sender,

    // Fund, 11%
    msg.sender

    ];



    struct Bonus {
    uint256 value;
    uint256 procent;
    uint256 freezeTime;
    }

    struct Profit {
    uint256 percent;
    uint256 duration;
    }

    struct Freezed {
    uint256 value;
    uint256 dateTo;
    }

    Bonus[] public bonuses;
    Profit[] public profits;


    uint256 public startTime= 1523491200;
    uint256 public endTime  = 1526083199;
    uint256 public renewal;

    // How many tokens (excluding the bonus) are transferred to the investor in exchange for 1 ETH
    // **THOUSANDS** 10^18 for human, *10**18 for Solidity, 1e18 for MyEtherWallet (MEW).
    // Example: if 1ETH = 40.5 Token ==> use 40500 finney
    uint256 public rate = 10000 ether;

    // ETH/USD rate in US$
    // **QUINTILLIONS** 10^18 / *10**18 / 1e18. Example: ETH/USD=$1000 ==> use 1000*10**18 (Solidity) or 1000 ether or 1000e18 (MEW)
    uint256 public exchange  = 700 ether;

    // If the round does not attain this value before the closing date, the round is recognized as a
    // failure and investors take the money back (the founders will not interfere in any way).
    // **QUINTILLIONS** 10^18 / *10**18 / 1e18. Example: softcap=15ETH ==> use 15*10**18 (Solidity) or 15e18 (MEW)
    uint256 public softCap = 2857 ether;

    // The maximum possible amount of income
    // **QUINTILLIONS** 10^18 / *10**18 / 1e18. Example: hardcap=123.45ETH ==> use 123450*10**15 (Solidity) or 12345e15 (MEW)
    uint256 public hardCap = 46429 ether;

    // If the last payment is slightly higher than the hardcap, then the usual contracts do
    // not accept it, because it goes beyond the hardcap. However it is more reasonable to accept the
    // last payment, very slightly raising the hardcap. The value indicates by how many ETH the
    // last payment can exceed the hardcap to allow it to be paid. Immediately after this payment, the
    // round closes. The funders should write here a small number, not more than 1% of the CAP.
    // Can be equal to zero, to cancel.
    // **QUINTILLIONS** 10^18 / *10**18 / 1e18
    uint256 public overLimit = 20 ether;

    // The minimum possible payment from an investor in ETH. Payments below this value will be rejected.
    // **QUINTILLIONS** 10^18 / *10**18 / 1e18. Example: minPay=0.1ETH ==> use 100*10**15 (Solidity) or 100e15 (MEW)
    uint256 public minPay = 71 finney;

    uint256 public maxAllProfit = 30;

    uint256 public ethWeiRaised;
    uint256 public nonEthWeiRaised;
    uint256 public weiRound1;
    uint256 public tokenReserved;

    uint256 public totalSaledToken;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    event Finalized();
    event Initialized();

    function Crowdsale(Creator _creator) public
    {
        creator2=true;
        creator=_creator;
    }

    function onlyAdmin(bool forObserver) internal view {
        require(wallets[uint8(Roles.manager)] == msg.sender || wallets[uint8(Roles.beneficiary)] == msg.sender ||
        forObserver==true && wallets[uint8(Roles.observer)] == msg.sender);
    }

    // Setting of basic parameters, analog of class constructor
    // @ Do I have to use the function      see your scenario
    // @ When it is possible to call        before Round 1/2
    // @ When it is launched automatically  -
    // @ Who can call the function          admins
    function begin() internal
    {
        if (isBegin) return;
        isBegin=true;

        token = creator.createToken();
        if (creator2) {
            vault = creator.createRefund();
        }

        //        if (wallets[uint8(Roles.fees)] != 0x0) {
        //            feesStrategy = creator.createFeesStrategy();
        //        }

        token.setUnpausedWallet(wallets[uint8(Roles.accountant)], true);
        token.setUnpausedWallet(wallets[uint8(Roles.manager)], true);
        token.setUnpausedWallet(wallets[uint8(Roles.bounty)], true);
        token.setUnpausedWallet(wallets[uint8(Roles.company)], true);
        token.setUnpausedWallet(wallets[uint8(Roles.observer)], true);

        //bonuses.push(Bonus(0 finney, 0, 0));
        bonuses.push(Bonus(71429 finney, 30, 30*5 days));

        profits.push(Profit(15,1 days));
        profits.push(Profit(10,2 days));
        profits.push(Profit(5,4 days));

    }



    // Issue of tokens for the zero round, it is usually called: private pre-sale (Round 0)
    // @ Do I have to use the function      may be
    // @ When it is possible to call        before Round 1/2
    // @ When it is launched automatically  -
    // @ Who can call the function          admins
    function firstMintRound0(uint256 _amount) public {
        onlyAdmin(false);
        require(canFirstMint);
        begin();
        token.mint(wallets[uint8(Roles.accountant)],_amount);
    }

    // info
    function totalSupply() external view returns (uint256){
        return token.totalSupply();
    }

    // Returns the name of the current round in plain text. Constant.
    function getTokenSaleType() external view returns(string){
        return (TokenSale == TokenSaleType.round1)?'round1':'round2';
    }

    // Transfers the funds of the investor to the contract of return of funds. Internal.
    function forwardFunds() internal {
        if(address(vault) != 0x0){
            vault.deposit.value(msg.value)(msg.sender);
        }else {
            //            if(address(feesStrategy) != 0x0 ){
            //                wallets[uint8(Roles.fees)].transfer(feesStrategy.pay(msg.value));
            //            }
            if(address(this).balance > 0){
                wallets[uint8(Roles.beneficiary)].transfer(address(this).balance);
            }
        }

    }

    // Check for the possibility of buying tokens. Inside. Constant.
    function validPurchase() internal view returns (bool) {

        // The round started and did not end
        bool withinPeriod = (now > startTime && now < endTime.add(renewal));

        // Rate is greater than or equal to the minimum
        bool nonZeroPurchase = msg.value >= minPay;

        // hardCap is not reached, and in the event of a transaction, it will not be exceeded by more than OverLimit
        bool withinCap = msg.value <= hardCap.sub(weiRaised()).add(overLimit);

        // round is initialized and no "Pause of trading" is set
        return withinPeriod && nonZeroPurchase && withinCap && isInitialized && !isPausedCrowdsale;
    }

    // Check for the ability to finalize the round. Constant.
    function hasEnded() public view returns (bool) {

        bool timeReached = now > endTime.add(renewal);

        bool capReached = weiRaised() >= hardCap;

        return (timeReached || capReached) && isInitialized;
    }

    // Finalize. Only available to the Manager and the Beneficiary. If the round failed, then
    // anyone can call the finalization to unlock the return of funds to investors
    // You must call a function to finalize each round (after the Round1 & after the Round2)
    // @ Do I have to use the function      yes
    // @ When it is possible to call        after end of Round1 & Round2
    // @ When it is launched automatically  no
    // @ Who can call the function          admins or anybody (if round is failed)
    function finalize() public {

        require(wallets[uint8(Roles.manager)] == msg.sender || wallets[uint8(Roles.beneficiary)] == msg.sender || !goalReached());
        require(!isFinalized);
        require(hasEnded() || ((wallets[uint8(Roles.manager)] == msg.sender || wallets[uint8(Roles.beneficiary)] == msg.sender) && goalReached()));

        isFinalized = true;
        finalization();
        emit Finalized();
    }

    // The logic of finalization. Internal
    // @ Do I have to use the function      no
    // @ When it is possible to call        -
    // @ When it is launched automatically  after end of round
    // @ Who can call the function          -
    function finalization() internal {

        //uint256 feesValue;
        // If the goal of the achievement
        if (goalReached()) {

            if(address(vault) != 0x0){
                // Send ether to Beneficiary
                //if(address(feesStrategy) == 0x0){
                vault.close(wallets[uint8(Roles.beneficiary)],0x0,0);
                //} else {
                //    feesValue = feesStrategy.pay(ethWeiRaised);
                //    vault.close(wallets[uint8(Roles.beneficiary)],wallets[uint8(Roles.fees)],feesValue);
                //}
            }

            // if there is anything to give
            if (tokenReserved > 0) {

                token.mint(wallets[uint8(Roles.accountant)],tokenReserved);

                // Reset the counter
                tokenReserved = 0;
            }

            // If the finalization is Round 1
            if (TokenSale == TokenSaleType.round1) {

                // Reset settings
                isInitialized = false;
                isFinalized = false;

                // Switch to the second round (to Round2)
                TokenSale = TokenSaleType.round2;

                // Reset the collection counter
                weiRound1 = weiRaised();
                ethWeiRaised = 0;
                nonEthWeiRaised = 0;



            }
            else // If the second round is finalized
            {

                // Permission to collect tokens to those who can pick them up
                chargeBonuses = true;

                totalSaledToken = token.totalSupply();
                //partners = true;

            }

        }
        else if (address(vault) != 0x0) // If they failed round
        {
            // Allow investors to withdraw their funds

            vault.enableRefunds();
        }
    }

    // The Manager freezes the tokens for the Team.
    // You must call a function to finalize Round 2 (only after the Round2)
    // @ Do I have to use the function      yes
    // @ When it is possible to call        Round2
    // @ When it is launched automatically  -
    // @ Who can call the function          admins
    function finalize2() public {

        onlyAdmin(false);
        require(chargeBonuses);
        chargeBonuses = false;

        allocation = creator.createAllocation(token, now + 1 years /* stage N1 */, now + 2 years /* stage N2 */);
        token.setUnpausedWallet(allocation, true);

        // Team = 6%, Founders = 10%, Fund = 11%    TOTAL = 27%
        allocation.addShare(wallets[uint8(Roles.team)],       6,  50); // only 50% - first year, stage N1  (and +50 for stage N2)
        allocation.addShare(wallets[uint8(Roles.founders)],  10,  50); // only 50% - first year, stage N1  (and +50 for stage N2)
        allocation.addShare(wallets[uint8(Roles.fund)],      11, 100); // 100% - first year

        // 27% - tokens to freeze contract (Team+Founders+Fund)
        token.mint(allocation, totalSaledToken.mul(27).div(70));

        // 2% - tokens to Bounty wallet
        token.mint(wallets[uint8(Roles.bounty)], totalSaledToken.mul(2).div(70));

        // 1% - tokens to Company (White List) wallet
        token.mint(wallets[uint8(Roles.company)], totalSaledToken.mul(1).div(70));

    }



    // Initializing the round. Available to the manager. After calling the function,
    // the Manager loses all rights: Manager can not change the settings (setup), change
    // wallets, prevent the beginning of the round, etc. You must call a function after setup
    // for the initial round (before the Round1 and before the Round2)
    // @ Do I have to use the function      yes
    // @ When it is possible to call        before each round
    // @ When it is launched automatically  -
    // @ Who can call the function          admins
    function initialize() public {

        onlyAdmin(false);
        // If not yet initialized
        require(!isInitialized);
        begin();


        // And the specified start time has not yet come
        // If initialization return an error, check the start date!
        require(now <= startTime);

        initialization();

        emit Initialized();

        isInitialized = true;
        renewal = 0;
        canFirstMint = false;
    }

    function initialization() internal {
        if (address(vault) != 0x0 && vault.state() != RefundVault.State.Active){
            vault.restart();
        }
    }

    // At the request of the investor, we raise the funds (if the round has failed because of the hardcap)
    // @ Do I have to use the function      no
    // @ When it is possible to call        if round is failed (softcap not reached)
    // @ When it is launched automatically  -
    // @ Who can call the function          all investors
    function claimRefund() external {
        require(address(vault) != 0x0);
        vault.refund(msg.sender);
    }

    // We check whether we collected the necessary minimum funds. Constant.
    function goalReached() public view returns (bool) {
        return weiRaised() >= softCap;
    }


    // Customize. The arguments are described in the constructor above.
    // @ Do I have to use the function      yes
    // @ When it is possible to call        before each rond
    // @ When it is launched automatically  -
    // @ Who can call the function          admins
    function setup(uint256 _startTime, uint256 _endTime, uint256 _softCap, uint256 _hardCap,
    uint256 _rate, uint256 _exchange,
    uint256 _maxAllProfit, uint256 _overLimit, uint256 _minPay,
    uint256[] _durationTB , uint256[] _percentTB, uint256[] _valueVB, uint256[] _percentVB, uint256[] _freezeTimeVB) public
    {

        onlyAdmin(false);
        require(!isInitialized);

        begin();

        // Date and time are correct
        require(now <= _startTime);
        require(_startTime < _endTime);
        startTime = _startTime;
        endTime = _endTime;

        // The parameters are correct
        require(_softCap <= _hardCap);
        softCap = _softCap;
        hardCap = _hardCap;

        require(_rate > 0);
        rate = _rate;

        overLimit = _overLimit;
        minPay = _minPay;
        exchange = _exchange;
        maxAllProfit = _maxAllProfit;

        require(_valueVB.length == _percentVB.length && _valueVB.length == _freezeTimeVB.length);
        bonuses.length = _valueVB.length;
        for(uint256 i = 0; i < _valueVB.length; i++){
            bonuses[i] = Bonus(_valueVB[i],_percentVB[i],_freezeTimeVB[i]);
        }

        require(_percentTB.length == _durationTB.length);
        profits.length = _percentTB.length;
        for( i = 0; i < _percentTB.length; i++){
            profits[i] = Profit(_percentTB[i],_durationTB[i]);
        }

    }

    // Collected funds for the current round. Constant.
    function weiRaised() public constant returns(uint256){
        return ethWeiRaised.add(nonEthWeiRaised);
    }

    // Returns the amount of fees for both phases. Constant.
    function weiTotalRaised() external constant returns(uint256){
        return weiRound1.add(weiRaised());
    }

    // Returns the percentage of the bonus on the current date. Constant.
    function getProfitPercent() public constant returns (uint256){
        return getProfitPercentForData(now);
    }

    // Returns the percentage of the bonus on the given date. Constant.
    function getProfitPercentForData(uint256 _timeNow) public constant returns (uint256){
        uint256 allDuration;
        for(uint8 i = 0; i < profits.length; i++){
            allDuration = allDuration.add(profits[i].duration);
            if(_timeNow < startTime.add(allDuration)){
                return profits[i].percent;
            }
        }
        return 0;
    }

    function getBonuses(uint256 _value) public constant returns (uint256,uint256,uint256){
        if(bonuses.length == 0 || bonuses[0].value > _value){
            return (0,0,0);
        }
        uint16 i = 1;
        for(i; i < bonuses.length; i++){
            if(bonuses[i].value > _value){
                break;
            }
        }
        return (bonuses[i-1].value,bonuses[i-1].procent,bonuses[i-1].freezeTime);
    }

    // The ability to quickly check Round1 (only for Round1, only 1 time). Completes the Round1 by
    // transferring the specified number of tokens to the Accountant's wallet. Available to the Manager.
    // Use only if this is provided by the script and white paper. In the normal scenario, it
    // does not call and the funds are raised normally. We recommend that you delete this
    // function entirely, so as not to confuse the auditors. Initialize & Finalize not needed.
    // ** QUINTILIONS **  10^18 / 1**18 / 1e18
    // @ Do I have to use the function      no, see your scenario
    // @ When it is possible to call        after Round0 and before Round2
    // @ When it is launched automatically  -
    // @ Who can call the function          admins
    //    function fastTokenSale(uint256 _totalSupply) external {
    //      onlyAdmin(false);
    //        require(TokenSale == TokenSaleType.round1 && !isInitialized);
    //        token.mint(wallets[uint8(Roles.accountant)], _totalSupply);
    //        TokenSale = TokenSaleType.round2;
    //    }


    // Remove the "Pause of exchange". Available to the manager at any time. If the
    // manager refuses to remove the pause, then 30-120 days after the successful
    // completion of the TokenSale, anyone can remove a pause and allow the exchange to continue.
    // The manager does not interfere and will not be able to delay the term.
    // He can only cancel the pause before the appointed time.
    // @ Do I have to use the function      YES YES YES
    // @ When it is possible to call        after end of ICO
    // @ When it is launched automatically  -
    // @ Who can call the function          admins or anybody
    function tokenUnpause() external {

        require(wallets[uint8(Roles.manager)] == msg.sender
        || (now > endTime.add(renewal).add(USER_UNPAUSE_TOKEN_TIMEOUT) && TokenSale == TokenSaleType.round2 && isFinalized && goalReached()));
        token.setPause(true);
    }

    // Enable the "Pause of exchange". Available to the manager until the TokenSale is completed.
    // The manager cannot turn on the pause, for example, 3 years after the end of the TokenSale.
    // ***CHECK***SCENARIO***
    // @ Do I have to use the function      no
    // @ When it is possible to call        while Round2 not ended
    // @ When it is launched automatically  before any rounds
    // @ Who can call the function          admins
    function tokenPause() public {
        onlyAdmin(false);
        require(!isFinalized);
        token.setPause(false);
    }

    // Pause of sale. Available to the manager.
    // @ Do I have to use the function      no
    // @ When it is possible to call        during active rounds
    // @ When it is launched automatically  -
    // @ Who can call the function          admins
    function setCrowdsalePause(bool mode) public {
        onlyAdmin(false);
        isPausedCrowdsale = mode;
    }

    // For example - After 5 years of the project's existence, all of us suddenly decided collectively
    // (company + investors) that it would be more profitable for everyone to switch to another smart
    // contract responsible for tokens. The company then prepares a new token, investors
    // disassemble, study, discuss, etc. After a general agreement, the manager allows any investor:
    //      - to burn the tokens of the previous contract
    //      - generate new tokens for a new contract
    // It is understood that after a general solution through this function all investors
    // will collectively (and voluntarily) move to a new token.
    // @ Do I have to use the function      no
    // @ When it is possible to call        only after ICO!
    // @ When it is launched automatically  -
    // @ Who can call the function          admins
    function moveTokens(address _migrationAgent) public {
        onlyAdmin(false);
        token.setMigrationAgent(_migrationAgent);
    }

    // @ Do I have to use the function      no
    // @ When it is possible to call        only after ICO!
    // @ When it is launched automatically  -
    // @ Who can call the function          admins
    function migrateAll(address[] _holders) public {
        onlyAdmin(false);
        token.migrateAll(_holders);
    }

    // Change the address for the specified role.
    // Available to any wallet owner except the observer.
    // Available to the manager until the round is initialized.
    // The Observer's wallet or his own manager can change at any time.
    // @ Do I have to use the function      no
    // @ When it is possible to call        depend...
    // @ When it is launched automatically  -
    // @ Who can call the function          staff (all 7+ roles)
    function changeWallet(Roles _role, address _wallet) external
    {
        require(
        (msg.sender == wallets[uint8(_role)] && _role != Roles.observer)
        ||
        (msg.sender == wallets[uint8(Roles.manager)] && (!isInitialized || _role == Roles.observer) && _role != Roles.fees )
        );

        wallets[uint8(_role)] = _wallet;
    }


    // The beneficiary at any time can take rights in all roles and prescribe his wallet in all the
    // rollers. Thus, he will become the recipient of tokens for the role of Accountant,
    // Team, etc. Works at any time.
    // @ Do I have to use the function      no
    // @ When it is possible to call        any time
    // @ When it is launched automatically  -
    // @ Who can call the function          only Beneficiary
    function resetAllWallets() external{
        address _beneficiary = wallets[uint8(Roles.beneficiary)];
        require(msg.sender == _beneficiary);
        for(uint8 i = 0; i < wallets.length; i++){
            if(uint8(Roles.fees) == i)
            continue;
            wallets[i] = _beneficiary;
        }
        token.setUnpausedWallet(_beneficiary, true);
    }


    // Burn the investor tokens, if provided by the ICO scenario. Limited time available - BURN_TOKENS_TIME
    // ***CHECK***SCENARIO***
    // @ Do I have to use the function      no
    // @ When it is possible to call        any time
    // @ When it is launched automatically  -
    // @ Who can call the function          admin
    function massBurnTokens(address[] _beneficiary, uint256[] _value) external {
        onlyAdmin(false);
        require(endTime.add(renewal).add(BURN_TOKENS_TIME) > now);
        require(_beneficiary.length == _value.length);
        for(uint16 i; i<_beneficiary.length; i++) {
            token.burn(_beneficiary[i],_value[i]);
        }
    }

    // Extend the round time, if provided by the script. Extend the round only for
    // a limited number of days - ROUND_PROLONGATE
    // ***CHECK***SCENARIO***
    // @ Do I have to use the function      no
    // @ When it is possible to call        during active round
    // @ When it is launched automatically  -
    // @ Who can call the function          admins
    function prolong(uint256 _duration) external {
        onlyAdmin(false);
        require(now > startTime && now < endTime.add(renewal) && isInitialized);//добавленно
        renewal = renewal.add(_duration);
        require(renewal <= ROUND_PROLONGATE);

    }
    // If a little more than a year has elapsed (Round2 start date + 400 days), a smart contract
    // will allow you to send all the money to the Beneficiary, if any money is present. This is
    // possible if you mistakenly launch the Round2 for 30 years (not 30 days), investors will transfer
    // money there and you will not be able to pick them up within a reasonable time. It is also
    // possible that in our checked script someone will make unforeseen mistakes, spoiling the
    // finalization. Without finalization, money cannot be returned. This is a rescue option to
    // get around this problem, but available only after a year (400 days).

    // Another reason - the TokenSale was a failure, but not all ETH investors took their money during the year after.
    // Some investors may have lost a wallet key, for example.

    // The method works equally with the Round1 and Round2. When the Round1 starts, the time for unlocking
    // the distructVault begins. If the TokenSale is then started, then the term starts anew from the first day of the TokenSale.

    // Next, act independently, in accordance with obligations to investors.

    // Within 400 days (FORCED_REFUND_TIMEOUT1) of the start of the Round, if it fails only investors can take money. After
    // the deadline this can also include the company as well as investors, depending on who is the first to use the method.
    // @ Do I have to use the function      no
    // @ When it is possible to call        -
    // @ When it is launched automatically  -
    // @ Who can call the function          beneficiary & manager
    function distructVault() public {
        require(address(vault) != 0x0);
        if (wallets[uint8(Roles.beneficiary)] == msg.sender && (now > startTime.add(FORCED_REFUND_TIMEOUT1))) {
            vault.del(wallets[uint8(Roles.beneficiary)]);
        }
        if (wallets[uint8(Roles.manager)] == msg.sender && (now > startTime.add(FORCED_REFUND_TIMEOUT2))) {
            vault.del(wallets[uint8(Roles.manager)]);
        }
    }


    // We accept payments other than Ethereum (ETH) and other currencies, for example, Bitcoin (BTC).
    // Perhaps other types of cryptocurrency - see the original terms in the white paper and on the TokenSale website.

    // We release tokens on Ethereum. During the Round1 and Round2 with a smart contract, you directly transfer
    // the tokens there and immediately, with the same transaction, receive tokens in your wallet.

    // When paying in any other currency, for example in BTC, we accept your money via one common wallet.
    // Our manager fixes the amount received for the bitcoin wallet and calls the method of the smart
    // contract paymentsInOtherCurrency to inform him how much foreign currency has been received - on a daily basis.
    // The smart contract pins the number of accepted ETH directly and the number of BTC. Smart contract
    // monitors softcap and hardcap, so as not to go beyond this framework.

    // In theory, it is possible that when approaching hardcap, we will receive a transfer (one or several
    // transfers) to the wallet of BTC, that together with previously received money will exceed the hardcap in total.
    // In this case, we will refund all the amounts above, in order not to exceed the hardcap.

    // Collection of money in BTC will be carried out via one common wallet. The wallet's address will be published
    // everywhere (in a white paper, on the TokenSale website, on Telegram, on Bitcointalk, in this code, etc.)
    // Anyone interested can check that the administrator of the smart contract writes down exactly the amount
    // in ETH (in equivalent for BTC) there. In theory, the ability to bypass a smart contract to accept money in
    // BTC and not register them in ETH creates a possibility for manipulation by the company. Thanks to
    // paymentsInOtherCurrency however, this threat is leveled.

    // Any user can check the amounts in BTC and the variable of the smart contract that accounts for this
    // (paymentsInOtherCurrency method). Any user can easily check the incoming transactions in a smart contract
    // on a daily basis. Any hypothetical tricks on the part of the company can be exposed and panic during the TokenSale,
    // simply pointing out the incompatibility of paymentsInOtherCurrency (ie, the amount of ETH + BTC collection)
    // and the actual transactions in BTC. The company strictly adheres to the described principles of openness.

    // The company administrator is required to synchronize paymentsInOtherCurrency every working day (but you
    // cannot synchronize if there are no new BTC payments). In the case of unforeseen problems, such as
    // brakes on the Ethereum network, this operation may be difficult. You should only worry if the
    // administrator does not synchronize the amount for more than 96 hours in a row, and the BTC wallet
    // receives significant amounts.

    // This scenario ensures that for the sum of all fees in all currencies this value does not exceed hardcap.

    // ** QUINTILLIONS ** 10^18 / 1**18 / 1e18

    // @ Do I have to use the function      no
    // @ When it is possible to call        during active rounds
    // @ When it is launched automatically  every day from cryptob2b token software
    // @ Who can call the function          admins + observer
    function paymentsInOtherCurrency(uint256 _token, uint256 _value) public {
        //require(wallets[uint8(Roles.observer)] == msg.sender || wallets[uint8(Roles.manager)] == msg.sender);
        onlyAdmin(true);
        bool withinPeriod = (now >= startTime && now <= endTime.add(renewal));

        bool withinCap = _value.add(ethWeiRaised) <= hardCap.add(overLimit);
        require(withinPeriod && withinCap && isInitialized);

        nonEthWeiRaised = _value;
        tokenReserved = _token;

    }

    function lokedMint(address _beneficiary, uint256 _value, uint256 _freezeTime) internal {
        if(_freezeTime > 0){

            uint256 totalBloked = token.freezedTokenOf(_beneficiary).add(_value);
            uint256 pastDateUnfreeze = token.defrostDate(_beneficiary);
            uint256 newDateUnfreeze = _freezeTime.add(now);
            newDateUnfreeze = (pastDateUnfreeze > newDateUnfreeze ) ? pastDateUnfreeze : newDateUnfreeze;

            token.freezeTokens(_beneficiary,totalBloked,newDateUnfreeze);
        }
        token.mint(_beneficiary,_value);
    }


    // The function for obtaining smart contract funds in ETH. If all the checks are true, the token is
    // transferred to the buyer, taking into account the current bonus.
    function buyTokens(address beneficiary) public payable {
        require(beneficiary != 0x0);
        require(validPurchase());

        uint256 weiAmount = msg.value;

        uint256 ProfitProcent = getProfitPercent();

        uint256 value;
        uint256 percent;
        uint256 freezeTime;

        (value,
        percent,
        freezeTime) = getBonuses(weiAmount);

        Bonus memory curBonus = Bonus(value,percent,freezeTime);

        uint256 bonus = curBonus.procent;

        // --------------------------------------------------------------------------------------------
        // *** Scenario 1 - select max from all bonuses + check maxAllProfit
        uint256 totalProfit = (ProfitProcent < bonus) ? bonus : ProfitProcent;
        // *** Scenario 2 - sum both bonuses + check maxAllProfit
        //uint256 totalProfit = bonus.add(ProfitProcent);
        // --------------------------------------------------------------------------------------------
        totalProfit = (totalProfit > maxAllProfit) ? maxAllProfit : totalProfit;

        // calculate token amount to be created
        uint256 tokens = weiAmount.mul(rate).mul(totalProfit.add(100)).div(100 ether);

        // update state
        ethWeiRaised = ethWeiRaised.add(weiAmount);

        lokedMint(beneficiary, tokens, curBonus.freezeTime);

        emit TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

        forwardFunds();
    }

    // buyTokens alias
    function () public payable {
        buyTokens(msg.sender);
    }



}
