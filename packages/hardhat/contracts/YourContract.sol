pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract YourContract is ChainlinkClient, ConfirmedOwner{
    using Chainlink for Chainlink.Request;

    bool internal locked;
    address private _owner;

    uint256 public depositLength = 1 days;
    uint256 public withdrawLength = 1 days;
    //uint256 public depositLength = 1 minutes;
    //uint256 public withdrawLength = 1 minutes;

    uint256 private constant ORACLE_PAYMENT = 1 * LINK_DIVISIBILITY; // 1 * 10**18

    mapping(bytes32 => uint256) requestToId;

    enum ContractStates {
        Funding,
        Withdraw,
        Active,
        Payout
    }

    struct ContractParameters {
        string name;
        ContractStates contractState;
        bool greaterThanThreshold; // if true, insured wins if final variable is greater than threshold, if false insured wins if lower than or equal to threshold
        bool temperatureSet;
        address payable owner;
        address oracle;
        uint256[6] contractDetails; // variableThreshold, variableValue, id, totalDeposits, creationTime, contractLength
        int256[2] latlon; // in an array, otherwise too many local variables and the stack becomes too deep
        mapping(address => uint256) balance; // maps the insurers addresses to their deposits
        mapping(address => bool) hasWithdrawn;
        bytes32[2] jobData; // requestId, jobId
    }
    ContractParameters[] public insurance;

    event NewContract(uint256 id, string name);
    event Deposit(uint256 id, address depositor, uint256 amount);
    event Withdraw(uint256 id, address withdrawer, uint256 amount);
    event Redeem(uint256 id, address redeemer, uint256 amount);
    event Updated(uint256 id, uint256 value);
    event StateChange(uint256 id, uint256 stage);
    event RequestIotTemperatureFulfilled(bytes32 indexed requestId, uint256 indexed temperature);

    error FunctionInvalidAtThisStage();

    //@dev ensures a function can only be called at a certain stage
    //         receives multiple enabled stages in an array
    modifier atStage(uint256 id, ContractStates[2] memory _stage) {
        bool stageOK;
        for (uint8 i = 0; i < _stage.length; i++) {
            if (insurance[id].contractState == _stage[i]) stageOK = true;
        }
        if (!stageOK) revert FunctionInvalidAtThisStage();
        _;
    }

    modifier timedTransitions(uint256 _id) {
        if (
            insurance[_id].contractState == ContractStates.Funding &&
            block.timestamp >= insurance[_id].contractDetails[4] + depositLength
        ) nextStage(_id);
        if (
            insurance[_id].contractState == ContractStates.Withdraw &&
            block.timestamp >=
            insurance[_id].contractDetails[4] + depositLength + withdrawLength
        ) nextStage(_id);
        if (
            insurance[_id].contractState == ContractStates.Active &&
            block.timestamp >=
            insurance[_id].contractDetails[4] +
                depositLength +
                withdrawLength +
                insurance[_id].contractDetails[5]
        ) nextStage(_id);
        _;
    }

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyContractOwner(uint256 id) {
        require(insuranceOwner(id) == msg.sender, "Ownable: caller is not the owner of the specified contract");
        _;
    }

    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
    }


    function createInsuranceContract(
        uint256 _contractLength,
        uint256 _variableThreshold,
        bool _greaterThanThreshold,
        int256 _latitude,
        int256 _longitude, 
        string memory _name, 
        string memory _jobId,
        address _oracle
    ) public payable {
        ContractParameters storage newContract = insurance.push();
        newContract.contractDetails[4] = block.timestamp;
        newContract.contractDetails[5] = _contractLength * 1 minutes;
        //newContract.contractDetails[5] = _contractLength * 1 days;
        newContract.contractDetails[0] = _variableThreshold;
        newContract.greaterThanThreshold = _greaterThanThreshold;
        require(_latitude<900000 && _latitude>-900000 && _longitude<1800000 && _longitude>-1800000);
        newContract.latlon = [_latitude, _longitude];
        newContract.owner = payable(msg.sender);
        newContract.name = _name;
        newContract.contractState = ContractStates.Funding;
        newContract.contractDetails[2] = insurance.length - 1;
        newContract.balance[msg.sender] = msg.value;
        newContract.contractDetails[3] = msg.value;
        newContract.jobData[1] = stringToBytes32(_jobId);
        newContract.oracle = _oracle;

        emit NewContract(newContract.contractDetails[2], _name);
    }

    // ---------------
    // STATE FUNCTIONS
    // ---------------

    function deposit(uint256 _id)
        public
        payable
        timedTransitions(_id)
        atStage(_id, [ContractStates.Funding, ContractStates.Funding])
    {
        uint256 amount = msg.value;
        // check for overflow - not needed from solidity 0.8.0
        // require(insurance[_id].balance[msg.sender] + amount >= insurance[_id].balance[msg.sender] && insurance[_id].totalDeposits + amount >= insurance[_id].totalDeposits);
        insurance[_id].balance[msg.sender] += amount;
        insurance[_id].contractDetails[3] += amount;
        emit Deposit(_id, msg.sender, amount);
    }

    // can withdraw any amount, any times in funding,
    // can only withdraw once in only withdraw phase, with decreasing max amount to withdraw until contract begins
    function withdraw(uint256 _id, uint256 _withdrawAmount)
        public
        noReentrant
        timedTransitions(_id)
        atStage(_id, [ContractStates.Funding, ContractStates.Withdraw])
    {
        uint256 withdrawAmount = _withdrawAmount;
        uint256 maxWithdraw = addressMaxWithdraw(_id, msg.sender);

        if (insurance[_id].contractState == ContractStates.Withdraw) {
            uint256 totalDeposits = insurance[_id].contractDetails[3];
            insurance[_id].hasWithdrawn[msg.sender] = true;
            // if there are no depositors, refund insured, and go to redemption (end contract)
            // (totaldeposits == owner balance)
            if (
                totalDeposits == insurance[_id].balance[insurance[_id].owner]
            ) {
                withdrawAmount = totalDeposits;
                nextStage(_id);
                nextStage(_id);
                console.log("No insurers, owner withdrew in withdraw phase!");
            }
        }

        require(maxWithdraw >= withdrawAmount, "Withdrawing more than allowed");

        (bool success, ) = msg.sender.call{value: withdrawAmount}("");
        require(success, "Failed to send Ether");
        insurance[_id].balance[msg.sender] -= withdrawAmount;
        insurance[_id].contractDetails[3] -= withdrawAmount;
        emit Withdraw(_id, msg.sender, withdrawAmount);
    }

    function active(uint256 _id, uint256 _value)
        public
        onlyContractOwner(_id)
        timedTransitions(_id)
        atStage(_id, [ContractStates.Active, ContractStates.Active])
    {
        // if there are no insurers, go to redemption
        if (
            insurance[_id].contractDetails[3] ==
            insurance[_id].balance[insurance[_id].owner]
        ) {
            uint256 greaterThanThresh = insurance[_id].greaterThanThreshold
                ? uint256(1)
                : uint256(0); // casting bool to uint
            setValue(_id, insurance[_id].contractDetails[0] + greaterThanThresh); // set value so insured wins and they can redeem
            nextStage(_id); // skip active phase
            console.log("next stage!");
        } else {
            setValue(_id, _value);
        }
    }

    function redeem(uint256 _id)
        public
        noReentrant
        timedTransitions(_id)
        atStage(_id, [ContractStates.Payout, ContractStates.Payout])
    {
        bool resultIsGreater;
        uint256 amount;
        require(
            insurance[_id].contractDetails[3] > 0,
            "Zero total deposit in contract"
        );
        require(
            insurance[_id].balance[msg.sender] > 0,
            "No redeemable deposits"
        );
        require(
            insurance[_id].temperatureSet,
            "Temperature not set, call requestIotTemperature()"
        ); // must call requestIotTemperature() before redeeming to set final temperature

        if (insurance[_id].contractDetails[1] > insurance[_id].contractDetails[0]) {
            resultIsGreater = true;
        }

        if (resultIsGreater == insurance[_id].greaterThanThreshold) {
            // insured wins
            // (final value is greater than threshold AND contract pays if its greater) OR (... smaller AND ... smaller)
            require(
                msg.sender == insurance[_id].owner,
                "The insured won the contract"
            );
            amount = insurance[_id].contractDetails[3];
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "Failed to send Ether");
            insurance[_id].contractDetails[3] = 0;
        } else {
            // insurers win
            require(
                msg.sender != insurance[_id].owner,
                "The insurers won the contract"
            );
            // calculate deposit-proportional winnings
            amount =
                (insurance[_id].balance[msg.sender] *
                    insurance[_id].contractDetails[3]) /
                (insurance[_id].contractDetails[3] -
                    insurance[_id].balance[insurance[_id].owner]);
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "Failed to send Ether");
            insurance[_id].balance[msg.sender] = 0;
        }
        emit Redeem(_id, msg.sender, amount);
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }

    function cancelRequest(
        bytes32 _requestId,
        uint256 _payment,
        bytes4 _callbackFunctionId,
        uint256 _expiration
    ) public onlyOwner {
        cancelChainlinkRequest(_requestId, _payment, _callbackFunctionId, _expiration);
    }


    function requestIotTemperature(uint256 _id)
        public
        timedTransitions(_id)
        atStage(_id, [ContractStates.Payout, ContractStates.Payout]) // only callable at redeem stage
        {
        require(insurance[_id].temperatureSet == false, "Temperature already set");
        Chainlink.Request memory req = buildChainlinkRequest(
            insurance[_id].jobData[1], // jobId
            address(this),
            this.fulfillIotTemperature.selector);
        insurance[_id].jobData[0] = sendChainlinkRequestTo(insurance[_id].oracle, req, ORACLE_PAYMENT);
        requestToId[insurance[_id].jobData[0]] = _id;
        }

    // TODO on contract end, call request → fulfill → payout (instead of just setting)
    function fulfillIotTemperature(bytes32 requestId, uint256 _temperature)
        public 
        recordChainlinkFulfillment(requestId) {
        emit RequestIotTemperatureFulfilled(requestId, _temperature);
        insurance[requestToId[requestId]].contractDetails[1] = _temperature;
        insurance[requestToId[requestId]].temperatureSet = true;
    }


    function insuranceOwner(uint256 id) public view virtual returns (address) {
        return insurance[id].owner;
    }
    
    function totalContracts() public view returns (uint256) {
        return insurance.length;
    }

    function addressDeposits(uint256 _id, address _address)
        public
        view
        returns (uint256)
    {
        return insurance[_id].balance[_address];
    }

    function addressPayout(uint256 _id, address _address)
        public
        view
        returns (uint256)
    {
        uint256 totalDeposits = insurance[_id].contractDetails[3];
        if (_address != insurance[_id].owner) {
            // insurer receives rewards proportional to other insurers
            return
                (insurance[_id].balance[_address] *
                    totalDeposits) / (totalDeposits -
                    insurance[_id].balance[insurance[_id].owner]);
        } else {
            // caller is owner, gets all deposits
            return totalDeposits;
        }
    }

    function addressMaxWithdraw(uint256 _id, address _address)
        public
        view
        returns (uint256)
    {
        uint256 maxAmount = insurance[_id].balance[_address];

        if (block.timestamp > insurance[_id].contractDetails[4] + depositLength) {
            // state: withdraw or after
            require(
                insurance[_id].hasWithdrawn[_address] == false,
                "User has already withdrawn once"
            );
            maxAmount =
                (insurance[_id].balance[_address] *
                    (insurance[_id].contractDetails[4] +
                        depositLength +
                        withdrawLength -
                        block.timestamp)) /
                withdrawLength;
        }

        if (
            block.timestamp >
            insurance[_id].contractDetails[4] + depositLength + withdrawLength
        ) {
            // state: active or after
            maxAmount = 0;
        }
        return maxAmount;
    }

    function getChainlinkToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    //@dev transitions selected contract to next state
    function nextStage(uint256 _id) internal {
        insurance[_id].contractState = ContractStates(
            uint8(insurance[_id].contractState) + 1
        );
        emit StateChange(_id, uint8(insurance[_id].contractState));
    }

    // TODO delete for production (only for tests)
    function setValue(uint256 _id, uint256 _value) private onlyContractOwner(_id) {
        insurance[_id].contractDetails[1] = _value;
        emit Updated(_id, _value);
    }

    function stringToBytes32(string memory source) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            //solhint-disable-line no-inline-assembly
            result := mload(add(source, 32))
        }
    }
}