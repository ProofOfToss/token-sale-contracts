pragma solidity ^0.4.21;

import '../SafeMath.sol';
import '../Token/TossToken.sol';
import './RefundVault.sol';
import './TossSVTAllocation.sol';

// (A1)
// The main contract for the sale and management of rounds.
// 0000000000000000000000000000000000000000000000000000000000000000

contract TossCrowdsale{

    // ether = token:
    uint256 constant TEAM_PAY    =  70000000 ether; //  70M =  7% = Team, freeze for 2 year
    uint256 constant BOUNTY_PAY  =  10000000 ether; //  10M =  1% = Bounty
    uint256 constant COMPANY_PAY = 220000000 ether; // 220M = 22% = (1% White List) + (21% company reserve)
    uint256 public TOTAL_TOKENS  = 700000000 ether; // 700M = 70% = Total for TokenSale

    uint256 constant USER_UNPAUSE_TOKEN_TIMEOUT =  60 days;
    uint256 constant FORCED_REFUND_TIMEOUT1     = 400 days;
    uint256 constant FORCED_REFUND_TIMEOUT2     = 600 days;

    using SafeMath for uint256;

    enum TokenSaleType {round1, round2}
    enum Roles {beneficiary, accountant, manager, observer, bounty, team, company}

    TossToken public token;

    bool public isFinalized;
    bool public isInitialized;
    bool public isPausedCrowdsale;

    // Initially, all next 7 roles/wallets are given to the Manager. The Manager is an employee of the company
    // with knowledge of IT, who publishes the contract and sets it up. However, money and tokens require
    // a Beneficiary and other roles (Accountant, Team, etc.). The Manager will not have the right
    // to receive them. To enable this, the Manager must either enter specific wallets here, or perform
    // this via method changeWallet. In the finalization methods it is written which wallet and
    // what percentage of tokens are received.
    address[7] public wallets = [

    // beneficiary
    // Receives all the money (when finalizing Round1 & Round2)
    0x0000000000000000000000000000000000000000,  // TODO !!!!

    // accountant
    // Receives all the tokens for non-ETH investors (when finalizing Round1 & Round2)
    0x0000000000000000000000000000000000000000,  // TODO !!!!

    // manager
    // All rights except the rights to receive tokens or money. Has the right to change any other
    // wallets (Beneficiary, Accountant, ...), but only if the round has not started. Once the
    // round is initialized, the Manager has lost all rights to change the wallets.
    // If the TokenSale is conducted by one person, then nothing needs to be changed. Permit all 7 roles
    // point to a single wallet.
    msg.sender,

    // observer
    // Has only the right to call paymentsInOtherCurrency (please read the document)
    0x0000000000000000000000000000000000000000,  // TODO !!!!

    // bounty
    0x0000000000000000000000000000000000000000,  // TODO !!!!

    // team
    // When the round is finalized, all team tokens are transferred to a special freezing
    // contract. As soon as defrosting is over, only the Team wallet will be able to
    // collect all the tokens. It does not store the address of the freezing contract,
    // but the final wallet of the project team.
    0x0000000000000000000000000000000000000000, // TODO !!!!

    // company
    0x0000000000000000000000000000000000000000  // TODO !!!!
    ];


    struct Profit{
    uint256 min;    // percent from 0 to 50
    uint256 max;    // percent from 0 to 50
    uint256 step;   // percent step, from 1 to 50 (please, read doc!)
    uint256 maxAllProfit;
    }
    struct Bonus {
    uint256 value;
    uint256 procent;
    uint256 freezeTime;
    }
    struct Freezed {
    uint256 value;
    uint256 dateTo;
    }

    uint256 public overall;

    mapping(address => uint256) public shares;
    mapping(address => Freezed) public freezedShares;

    bool public startMint;

    Bonus[] public bonuses;



    //TODO!!!
    uint256 public startTime= (now/600 + ((now - now/600 * 600 < 300) ? 2 : 3))*600;
    uint256 public endDiscountTime = startTime + 1800;
    uint256 public endTime = endDiscountTime;

    // How many tokens (excluding the bonus) are transferred to the investor in exchange for 1 ETH
    // **THOUSANDS** 10^3 for human, *10**3 for Solidity, 1e3 for MyEtherWallet (MEW).
    // Example: if 1ETH = 40.5 Token ==> use 40500
    uint256 public rate = 1000;

    // If the round does not attain this value before the closing date, the round is recognized as a
    // failure and investors take the money back (the founders will not interfere in any way).
    // **QUINTILLIONS** 10^18 / *10**18 / 1e18. Example: softcap=15ETH ==> use 15*10**18 (Solidity) or 15e18 (MEW)
    uint256 public softCap = 5000 ether;

    // The maximum possible amount of income
    // **QUINTILLIONS** 10^18 / *10**18 / 1e18. Example: hardcap=123.45ETH ==> use 123450*10**15 (Solidity) or 12345e15 (MEW)
    uint256 public hardCap = 41666 ether;

    // If the last payment is slightly higher than the hardcap, then the usual contracts do
    // not accept it, because it goes beyond the hardcap. However it is more reasonable to accept the
    // last payment, very slightly raising the hardcap. The value indicates by how many ETH the
    // last payment can exceed the hardcap to allow it to be paid. Immediately after this payment, the
    // round closes. The funders should write here a small number, not more than 1% of the CAP.
    // Can be equal to zero, to cancel.
    // **QUINTILLIONS** 10^18 / *10**18 / 1e18
    uint256 public overLimit = 10 ether;

    // The minimum possible payment from an investor in ETH. Payments below this value will be rejected.
    // **QUINTILLIONS** 10^18 / *10**18 / 1e18. Example: minPay=0.1ETH ==> use 100*10**15 (Solidity) or 100e15 (MEW)
    uint256 public minPay = 70 finney;

    uint256 ethWeiRaised;
    uint256 nonEthWeiRaised;
    uint256 weiRound1;
    uint256 public tokenReserved;

    RefundVault public vault;
    TossSVTAllocation public lockedAllocation;

    TokenSaleType TokenSale = TokenSaleType.round1;

    bool public bounty;
    bool public team;
    bool public company;
    //bool public partners;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    event Finalized();
    event Initialized();

    function TossCrowdsale(TossToken _token) public
    {


        token = _token;
        token.setOwner();

        token.pause(); // block exchange tokens

        token.addUnpausedWallet(wallets[uint8(Roles.accountant)]);
        token.addUnpausedWallet(wallets[uint8(Roles.manager)]);
        token.addUnpausedWallet(wallets[uint8(Roles.bounty)]);
        token.addUnpausedWallet(wallets[uint8(Roles.company)]);
        token.addUnpausedWallet(wallets[uint8(Roles.observer)]);

        token.setFreezingManager(wallets[uint8(Roles.accountant)]);

        // For payments > ~$100 000 (1000 ETH):
        //    1) lock (freeze) tokens for 5 months
        // 	  2) add +30% bonus tokens
        bonuses.push(Bonus(1000000 finney, 30, 30*5 days));

    }


    // Returns the name of the current round in plain text. Constant.
    function getTokenSaleType()  public constant returns(string){
        return (TokenSale == TokenSaleType.round1)?'round1':'round2';
    }

    // Transfers the funds of the investor to the contract of return of funds. Internal.
    function forwardFunds() internal {
        vault.deposit.value(msg.value)(msg.sender);
    }

    // Check for the possibility of buying tokens. Inside. Constant.
    function validPurchase() internal constant returns (bool) {

        // The round started and did not end
        bool withinPeriod = (now > startTime && now < endTime);

        // Rate is greater than or equal to the minimum
        bool nonZeroPurchase = msg.value >= minPay;

        // hardCap is not reached, and in the event of a transaction, it will not be exceeded by more than OverLimit
        bool withinCap = msg.value <= hardCap.sub(weiRaised()).add(overLimit);

        // round is initialized and no "Pause of trading" is set
        return withinPeriod && nonZeroPurchase && withinCap && isInitialized && !isPausedCrowdsale;
    }

    // Check for the ability to finalize the round. Constant.
    function hasEnded() public constant returns (bool) {

        bool timeReached = now > endTime;

        bool capReached = weiRaised() >= hardCap;

        return (timeReached || capReached) && isInitialized;
    }

    function finalizeAll() external {
        finalize();
        finalize1();
        finalize2();
        finalize3();
    }

    // Finalize. Only available to the Manager and the Beneficiary. If the round failed, then
    // anyone can call the finalization to unlock the return of funds to investors
    // You must call a function to finalize each round (after the Round1 & after the Round2)
    function finalize() public {

        require(wallets[uint8(Roles.manager)] == msg.sender || wallets[uint8(Roles.beneficiary)] == msg.sender || !goalReached());
        require(!isFinalized);
        require(hasEnded());

        isFinalized = true;
        finalization();
        Finalized();
    }

    // The logic of finalization. Internal
    function finalization() internal {

        // If the goal of the achievement
        if (goalReached()) {

            // Send ether to Beneficiary
            vault.close(wallets[uint8(Roles.beneficiary)]);

            // if there is anything to give
            if (tokenReserved > 0) {

                //token.mint(wallets[uint8(Roles.accountant)],tokenReserved);
                setShare(wallets[uint8(Roles.accountant)],tokenReserved,0);

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
                bounty = true;
                team = true;
                company = true;

                startMint = true;

                getCashFrom(wallets[uint8(Roles.accountant)]);
                //partners = true;

            }

        }
        else // If they failed round
        {
            // Allow investors to withdraw their funds
            vault.enableRefunds();
        }
    }

    // The Manager freezes the tokens for the Team.
    // You must call a function to finalize Round 2 (only after the Round2)
    function finalize1() public {
        require(wallets[uint8(Roles.manager)] == msg.sender || wallets[uint8(Roles.beneficiary)] == msg.sender);
        require(team);
        team = false;
        lockedAllocation = new TossSVTAllocation(token, wallets[uint8(Roles.team)]);
        token.addUnpausedWallet(lockedAllocation);
        // 7% - tokens to Team wallet after freeze
        token.mint(lockedAllocation, TEAM_PAY);
    }

    function finalize2() public {
        require(wallets[uint8(Roles.manager)] == msg.sender || wallets[uint8(Roles.beneficiary)] == msg.sender);
        require(bounty);
        bounty = false;
        // 1% - tokens to bounty wallet
        token.mint(wallets[uint8(Roles.bounty)], BOUNTY_PAY);
    }

    // For marketing, referral, reserve, white list
    // You must call a function to finalize Round 2 (only after the Round2)
    function finalize3() public {
        require(wallets[uint8(Roles.manager)] == msg.sender || wallets[uint8(Roles.beneficiary)] == msg.sender);
        require(company);
        company = false;
        // 1% - tokens to company wallet
        token.mint(wallets[uint8(Roles.company)], COMPANY_PAY);
    }


    // Initializing the round. Available to the manager. After calling the function,
    // the Manager loses all rights: Manager can not change the settings (setup), change
    // wallets, prevent the beginning of the round, etc. You must call a function after setup
    // for the initial round (before the Round1 and before the Round2)
    function initialize() public {

        // Only the Manager
        require(wallets[uint8(Roles.manager)] == msg.sender);

        // If not yet initialized
        require(!isInitialized);

        // And the specified start time has not yet come
        // If initialization return an error, check the start date!
        require(now <= startTime);

        initialization();

        Initialized();

        isInitialized = true;
    }

    function initialization() internal {
        if (address(vault) != 0x0){
            vault.del(wallets[uint8(Roles.beneficiary)]);
        }
        vault = new RefundVault();
    }

    // At the request of the investor, we raise the funds (if the round has failed because of the hardcap)
    function claimRefund() public{
        vault.refund(msg.sender);
    }

    function getCashFrom(address _beneficiary) public {
        require(startMint);
        if(shares[_beneficiary] == 0) return;

        uint256 _amount = TOTAL_TOKENS.mul(shares[_beneficiary]).div(overall);


        if(freezedShares[_beneficiary].value > 0){
            token.freezeTokens(_beneficiary,TOTAL_TOKENS.mul(freezedShares[_beneficiary].value).div(overall),freezedShares[_beneficiary].dateTo);
            freezedShares[_beneficiary].value = 0;
        }

        overall = overall.sub(shares[_beneficiary]);
        TOTAL_TOKENS = TOTAL_TOKENS.sub(_amount);
        shares[_beneficiary] = 0;

        token.mint(_beneficiary,_amount);
    }

    function getCash() public {
        getCashFrom(msg.sender);
    }

    // We check whether we collected the necessary minimum funds. Constant.
    function goalReached() public constant returns (bool) {
        return weiRaised() >= softCap;
    }

    // Customize. The arguments are described in the constructor above.
    function setup(uint256 _startTime, uint256 _endDiscountTime, uint256 _endTime, uint256 _softCap, uint256 _hardCap, uint256 _rate, uint256 _overLimit, uint256 _minPay, uint256[] _value, uint256[] _procent,uint256[] _freezeTime) public{
        changePeriod(_startTime, _endDiscountTime, _endTime);
        changeTargets(_softCap, _hardCap);
        changeRate(_rate, _overLimit, _minPay);
        setBonuses(_value, _procent,_freezeTime);
    }

    // Change the date and time: the beginning of the round, the end of the bonus, the end of the round. Available to Manager
    // Description in the Crowdsale constructor
    function changePeriod(uint256 _startTime, uint256 _endDiscountTime, uint256 _endTime) public{

        require(wallets[uint8(Roles.manager)] == msg.sender);

        require(!isInitialized);

        // Date and time are correct
        require(now <= _startTime);
        require(_endDiscountTime > _startTime && _endDiscountTime <= _endTime);

        startTime = _startTime;
        endTime = _endTime;
        endDiscountTime = _endDiscountTime;

    }

    // We change the purpose of raising funds. Available to the manager.
    // Description in the Crowdsale constructor.
    function changeTargets(uint256 _softCap, uint256 _hardCap) public {

        require(wallets[uint8(Roles.manager)] == msg.sender);

        require(!isInitialized);

        // The parameters are correct
        require(_softCap <= _hardCap);

        softCap = _softCap;
        hardCap = _hardCap;
    }

    // Change the price (the number of tokens per 1 eth), the maximum hardCap for the last bet,
    // the minimum bet. Available to the Manager.
    // Description in the Crowdsale constructor
    function changeRate(uint256 _rate, uint256 _overLimit, uint256 _minPay) public {

        require(wallets[uint8(Roles.manager)] == msg.sender);

        require(!isInitialized);

        require(_rate > 0);

        rate = _rate;
        overLimit = _overLimit;
        minPay = _minPay;
    }

    function setBonuses(uint256[] _value, uint256[] _procent, uint256[] _freezeTime) public {

        require(wallets[uint8(Roles.manager)] == msg.sender);
        require(!isInitialized);

        require(_value.length == _procent.length && _value.length == _freezeTime.length);
        bonuses.length = _value.length;
        for(uint256 i = 0; i < _value.length; i++){
            bonuses[i] = Bonus(_value[i],_procent[i],_freezeTime[i]);
        }
    }

    // Collected funds for the current round. Constant.
    function weiRaised() public constant returns(uint256){
        return ethWeiRaised.add(nonEthWeiRaised);
    }

    // Returns the amount of fees for both phases. Constant.
    function weiTotalRaised() public constant returns(uint256){
        return weiRound1.add(weiRaised());
    }

    // Returns the percentage of the bonus on the current date. Constant.
    function getProfitPercent() public constant returns (uint256){
        return getProfitPercentForData(now);
    }

    // Returns the percentage of the bonus on the given date. Constant.
    function getProfitPercentForData(uint256 timeNow) public constant returns (uint256){
        if       (timeNow < startTime + 1 days) {  return 15; }
        else if  (timeNow < startTime + 4 days) {  return 10; }
        else if  (timeNow < startTime + 7 days) {  return 5;  }
        else                                    {  return 0;  }
    }

    function getBonuses(uint256 _value) public constant returns (Bonus){
        if(bonuses.length == 0 || bonuses[0].value > _value){
            return Bonus(0,0,0);
        }
        uint16 i = 1;
        for(i; i < bonuses.length; i++){
            if(bonuses[i].value > _value){
                break;
            }
        }
        return bonuses[i-1];
    }

    // The ability to quickly check Round1 (only for Round1, only 1 time). Completes the Round1 by
    // transferring the specified number of tokens to the Accountant's wallet. Available to the Manager.
    // Use only if this is provided by the script and white paper. In the normal scenario, it
    // does not call and the funds are raised normally. We recommend that you delete this
    // function entirely, so as not to confuse the auditors. Initialize & Finalize not needed.
    // ** QUINTILIONS **  10^18 / 1**18 / 1e18
    function fastTokenSale(uint256 _totalSupply) public {
        require(wallets[uint8(Roles.manager)] == msg.sender);
        require(TokenSale == TokenSaleType.round1 && !isInitialized);
        setShare(wallets[uint8(Roles.accountant)], _totalSupply, 0);
        TokenSale = TokenSaleType.round2;
    }

    // Remove the "Pause of exchange". Available to the manager at any time. If the
    // manager refuses to remove the pause, then 30-120 days after the successful
    // completion of the TokenSale, anyone can remove a pause and allow the exchange to continue.
    // The manager does not interfere and will not be able to delay the term.
    // He can only cancel the pause before the appointed time.
    function tokenUnpause() public {
        require(wallets[uint8(Roles.manager)] == msg.sender || (now > endTime + USER_UNPAUSE_TOKEN_TIMEOUT && startMint));
        token.unpause();
    }

    // Enable the "Pause of exchange". Available to the manager until the TokenSale is completed.
    // The manager cannot turn on the pause, for example, 3 years after the end of the TokenSale.
    function tokenPause() public {
        require(wallets[uint8(Roles.manager)] == msg.sender && !isFinalized);
        token.pause();
    }

    // Pause of sale. Available to the manager.
    function crowdsalePause() public {
        require(wallets[uint8(Roles.manager)] == msg.sender);
        require(isPausedCrowdsale == false);
        isPausedCrowdsale = true;
    }

    // Withdrawal from the pause of sale. Available to the manager.
    function crowdsaleUnpause() public {
        require(wallets[uint8(Roles.manager)] == msg.sender);
        require(isPausedCrowdsale == true);
        isPausedCrowdsale = false;
    }

    // Checking whether the rights to address ignore the "Pause of exchange". If the
    // wallet is included in this list, it can translate tokens, ignoring the pause. By default,
    // only the following wallets are included:
    //    - Accountant wallet (he should immediately transfer tokens, but not to non-ETH investors)
    //    - Contract for freezing the tokens for the Team (but Team wallet not included)
    // Inside. Constant.
    function unpausedWallet(address _wallet) internal constant returns(bool) {
        bool _accountant = wallets[uint8(Roles.accountant)] == _wallet;
        bool _manager = wallets[uint8(Roles.manager)] == _wallet;
        bool _bounty = wallets[uint8(Roles.bounty)] == _wallet;
        bool _company = wallets[uint8(Roles.company)] == _wallet;
        bool _observer = wallets[uint8(Roles.observer)] == _wallet;
        return _accountant || _manager || _bounty || _company || _observer;
    }

    // For example - After 5 years of the project's existence, all of us suddenly decided collectively
    // (company + investors) that it would be more profitable for everyone to switch to another smart
    // contract responsible for tokens. The company then prepares a new token, investors
    // disassemble, study, discuss, etc. After a general agreement, the manager allows any investor:
    //      - to burn the tokens of the previous contract
    //      - generate new tokens for a new contract
    // It is understood that after a general solution through this function all investors
    // will collectively (and voluntarily) move to a new token.
    function moveTokens(address _migrationAgent) public {
        require(wallets[uint8(Roles.manager)] == msg.sender);
        token.setMigrationAgent(_migrationAgent);
    }

    function migrateAll(address[] _holders) public {
        require(wallets[uint8(Roles.manager)] == msg.sender);
        token.migrateAll(_holders);
    }

    // Change the address for the specified role.
    // Available to any wallet owner except the observer.
    // Available to the manager until the round is initialized.
    // The Observer's wallet or his own manager can change at any time.
    function changeWallet(Roles _role, address _wallet) public
    {
        require(
        (msg.sender == wallets[uint8(_role)] && _role != Roles.observer)
        ||
        (msg.sender == wallets[uint8(Roles.manager)] && (!isInitialized || _role == Roles.observer))
        );
        address oldWallet = wallets[uint8(_role)];
        wallets[uint8(_role)] = _wallet;
        if(!unpausedWallet(oldWallet))
        token.delUnpausedWallet(oldWallet);
        if(unpausedWallet(_wallet))
        token.addUnpausedWallet(_wallet);
        if(_role == Roles.accountant)
        token.setFreezingManager(wallets[uint8(Roles.accountant)]);
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
    function distructVault() public {
        if (wallets[uint8(Roles.beneficiary)] == msg.sender && (now > startTime + FORCED_REFUND_TIMEOUT1)) {
            vault.del(wallets[uint8(Roles.beneficiary)]);
        }
        if (wallets[uint8(Roles.manager)] == msg.sender && (now > startTime + FORCED_REFUND_TIMEOUT2)) {
            vault.del(wallets[uint8(Roles.manager)]);
        }
    }

    function setShare(address _beneficiary, uint256 _value, uint256 _freezeTime) internal {
        shares[_beneficiary] = shares[_beneficiary].add(_value);
        overall = overall.add(_value);
        if(_freezeTime > 0){
            freezedShares[_beneficiary].value = freezedShares[_beneficiary].value.add(_value);
            if(freezedShares[_beneficiary].dateTo < now + _freezeTime){
                freezedShares[_beneficiary].dateTo = now + _freezeTime;
            }
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

    // BTC - TODO!!!
    // LTC - TODO!!!
    // DASH - TODO!!!
    // *** - TODO!!!
    // Впишите сюда как комментарий все не эфирные кошельки. Их можно будет проверить (желающим провести аудит,
    // когда токенсейл уже запущен).

    // ** QUINTILLIONS ** 10^18 / 1**18 / 1e18
    function paymentsInOtherCurrency(uint256 _token, uint256 _value) public {
        require(wallets[uint8(Roles.observer)] == msg.sender || wallets[uint8(Roles.manager)] == msg.sender);
        bool withinPeriod = (now >= startTime && now <= endTime);

        bool withinCap = _value.add(ethWeiRaised) <= hardCap.add(overLimit);
        require(withinPeriod && withinCap && isInitialized);

        nonEthWeiRaised = _value;
        tokenReserved = _token;

    }


    // The function for obtaining smart contract funds in ETH. If all the checks are true, the token is
    // transferred to the buyer, taking into account the current bonus.
    function buyTokens(address beneficiary) public payable {
        require(beneficiary != 0x0);
        require(validPurchase());

        uint256 weiAmount = msg.value;

        uint256 ProfitProcent = getProfitPercent();

        Bonus memory curBonus = getBonuses(weiAmount);

        uint256 bonus = curBonus.procent;

        // Scenario 1 - select max from all bonuses + check profit.maxAllProfit
        uint256 totalProfit = (ProfitProcent < bonus) ? bonus : ProfitProcent;

        // Scenario 2 - sum both bonuses + check profit.maxAllProfit
        // uint256 totalProfit = bonus.add(ProfitProcent);
        // totalProfit = (totalProfit > profit.maxAllProfit)? profit.maxAllProfit: totalProfit;

        // calculate token amount to be created
        uint256 tokens = weiAmount.mul(rate).mul(totalProfit + 100).div(100000);

        // update state
        ethWeiRaised = ethWeiRaised.add(weiAmount);

        setShare(beneficiary, tokens, curBonus.freezeTime);

        TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

        forwardFunds();
    }

    // buyTokens alias
    function () public payable {
        buyTokens(msg.sender);
    }

}
