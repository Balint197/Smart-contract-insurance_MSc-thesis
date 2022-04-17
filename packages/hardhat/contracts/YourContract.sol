pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; 
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract YourContract {

  event NewContract(uint contractId, string name);
  event Deposit(uint id, address depositor, uint amount);
  event Withdraw(uint id, address withdrawer, uint amount);
  event Redeem(uint id, address redeemer, uint amount);
  event Updated(uint id, uint value);
  event StateChange(uint id, uint stage);

  error FunctionInvalidAtThisStage();

  enum ContractStates {
    Funding, 
    Withdraw, 
    Active, 
    Payout
  }

  struct contractParameters { // @TODO oracle datafeed?
    uint contractId;
    string name;
    ContractStates contractState;
    uint variableThreshold;
    uint variableValue;
    bool greaterThanThreshold; // if true, insured wins if final variable is greater than threshold, if false insured wins if lower than or equal to threshold
    uint totalDeposits;
    address payable owner;
    uint creationTime;
    uint contractLength;
    mapping (address => uint) balance; // maps the insurers addresses to their deposits
    mapping (address => bool) hasWithdrawn; 
  }

  contractParameters[] public insuranceContracts;

//  uint depositLength = 1 days;
//  uint withdrawLength = 1 days;
  
  uint depositLength = 1 minutes;
  uint withdrawLength = 1 minutes;

  //@dev ensures a function can only be called at a certain stage
  //     receives multiple enabled stages in an array
  modifier atStage(uint id, ContractStates[2] memory _stage) {
      bool stageOK;
      for (uint i = 0; i < _stage.length; i++){
        if (insuranceContracts[id].contractState == _stage[i])
          stageOK = true;          
      }
      if (!stageOK)
        revert FunctionInvalidAtThisStage();
      _;
  }

  //@dev transitions selected contract to next state
  function nextStage(uint _id) internal {
    insuranceContracts[_id].contractState = ContractStates(uint(insuranceContracts[_id].contractState) + 1);
    emit StateChange(_id, uint(insuranceContracts[_id].contractState));
  }

  modifier timedTransitions(uint _id) {
    if (insuranceContracts[_id].contractState == ContractStates.Funding && 
        block.timestamp >= insuranceContracts[_id].creationTime + depositLength)
      nextStage(_id);
    if (insuranceContracts[_id].contractState == ContractStates.Withdraw && 
        block.timestamp >= insuranceContracts[_id].creationTime + depositLength + withdrawLength)
      nextStage(_id);
    if (insuranceContracts[_id].contractState == ContractStates.Active && 
        block.timestamp >= insuranceContracts[_id].creationTime + depositLength + withdrawLength + insuranceContracts[_id].contractLength)
      nextStage(_id);
    _;
  }

  // Onlyowner
  function owner(uint id) public view virtual returns (address) {
      return insuranceContracts[id].owner;
  }

  modifier onlyContractOwner(uint id) {
    require(owner(id) == msg.sender, "Ownable: caller is not the owner");
    _;
  }


  function createInsuranceContract(uint _contractLength, 
                                    uint _variableThreshold, 
                                    bool _greaterThanThreshold, 
                                    string memory _name) payable public {
    contractParameters storage newContract = insuranceContracts.push();
    newContract.creationTime = block.timestamp;
    //newContract.contractLength = _contractLength * 1 days;
    newContract.contractLength = _contractLength * 1 minutes;
    newContract.variableThreshold = _variableThreshold;
    newContract.greaterThanThreshold = _greaterThanThreshold;
    newContract.owner = payable(msg.sender);
    newContract.name = _name;
    newContract.contractState = ContractStates.Funding;
    newContract.contractId = insuranceContracts.length - 1;
    newContract.balance[msg.sender] = msg.value;
    newContract.totalDeposits = msg.value;

    emit NewContract(newContract.contractId, _name);
  }

  function totalContracts() public view returns (uint){
    return insuranceContracts.length;
  }
  
  function addressDeposits(uint _id, address _address) public view returns (uint){
    return insuranceContracts[_id].balance[_address];
  }

  function addressPayout(uint _id, address _address) public view returns (uint){
    if (_address != insuranceContracts[_id].owner){ 
      // insurer receives rewards proportional to other insurers
      return insuranceContracts[_id].balance[_address] * insuranceContracts[_id].totalDeposits / (insuranceContracts[_id].totalDeposits - insuranceContracts[_id].balance[insuranceContracts[_id].owner]);
    } else { 
      // caller is owner, gets all deposits
      return insuranceContracts[_id].totalDeposits;
    }

  }

  // TODO more involved logic...
  function setValue(uint _id, uint _value) private {
    insuranceContracts[_id].variableValue = _value;
    emit Updated(_id, _value);
  }

  function addressMaxWithdraw(uint _id, address _address) public view returns (uint){
    uint maxAmount = insuranceContracts[_id].balance[_address];

    if (block.timestamp > insuranceContracts[_id].creationTime + depositLength){      // state: withdraw or after
      require(insuranceContracts[_id].hasWithdrawn[_address] == false, "Can't withdraw any more, user has already withdrawn once");
      maxAmount = insuranceContracts[_id].balance[_address]*(insuranceContracts[_id].creationTime+depositLength+withdrawLength-block.timestamp)/withdrawLength;
    }

    if (block.timestamp > insuranceContracts[_id].creationTime + depositLength + withdrawLength){      // state: active or after
      maxAmount = 0;
    }

    return maxAmount;
  }

  // ---------------
  // STATE FUNCTIONS
  // ---------------

  function deposit(uint _id) public payable timedTransitions(_id) atStage(_id, [ContractStates.Funding, ContractStates.Funding]) { 
    uint amount = msg.value;
    // check for overflow
    require(insuranceContracts[_id].balance[msg.sender] + amount >= insuranceContracts[_id].balance[msg.sender] && 
      insuranceContracts[_id].totalDeposits + amount >= insuranceContracts[_id].totalDeposits); 
    insuranceContracts[_id].balance[msg.sender] += amount;
    insuranceContracts[_id].totalDeposits += amount;
    emit Deposit(_id, msg.sender, amount);
  }

  // can withdraw any amount, any times in funding, 
  // can only withdraw once in only withdraw phase, with decreasing max amount to withdraw until contract begins
function withdraw(uint _id, uint _withdrawAmount) public timedTransitions(_id) atStage(_id, [ContractStates.Funding, ContractStates.Withdraw]) {
    uint withdrawAmount = _withdrawAmount;
    uint maxWithdraw = addressMaxWithdraw(_id, msg.sender);

    if (insuranceContracts[_id].contractState == ContractStates.Withdraw){
      insuranceContracts[_id].hasWithdrawn[msg.sender] = true; 
      // if there are no depositors, refund insured, and go to redemption (end contract)
      // (totaldeposits == owner balance)
      if (insuranceContracts[_id].totalDeposits == insuranceContracts[_id].balance[insuranceContracts[_id].owner]){
        withdrawAmount = insuranceContracts[_id].totalDeposits;
        nextStage(_id);
        nextStage(_id);
        console.log("No insurers, owner withdrew in withdraw phase!");
      }
    }

    require(maxWithdraw >= withdrawAmount, "Trying to withdraw more than the allowed");

    (bool success, ) = msg.sender.call{value: withdrawAmount}("");
    require(success, "Failed to send Ether");
    insuranceContracts[_id].balance[msg.sender] -= withdrawAmount;
    insuranceContracts[_id].totalDeposits -= withdrawAmount;
    emit Withdraw(_id, msg.sender, withdrawAmount);
  }


  function active(uint _id, uint _value) public onlyContractOwner(_id) timedTransitions(_id) atStage(_id, [ContractStates.Active, ContractStates.Active]) {
    // if there are no insurers, go to redemption
    if (insuranceContracts[_id].totalDeposits == insuranceContracts[_id].balance[insuranceContracts[_id].owner]){
      uint greaterThanThresh = insuranceContracts[_id].greaterThanThreshold ? uint(1) : uint(0); // casting bool to uint
      setValue(_id, insuranceContracts[_id].variableThreshold+greaterThanThresh); // set value so insured wins and they can redeem
      nextStage(_id); // skip active phase
      console.log("next stage!");
    } else {
      setValue(_id, _value);
    }
  }

  function redeem(uint _id) public timedTransitions(_id) atStage(_id, [ContractStates.Payout, ContractStates.Payout]) {
    bool resultIsGreater;
    uint amount;
    require(insuranceContracts[_id].totalDeposits > 0, "Zero total deposit in contract");
    require(insuranceContracts[_id].balance[msg.sender] > 0, "This account doesn't have redeemable deposits in this contract");

    if (insuranceContracts[_id].variableValue > insuranceContracts[_id].variableThreshold){
      resultIsGreater = true; 
    }

    if (resultIsGreater == insuranceContracts[_id].greaterThanThreshold){
      // insured wins
      // (final value is greater than threshold AND contract pays if its greater) OR (... smaller AND ... smaller)
      require(msg.sender == insuranceContracts[_id].owner, "You are an insurer, and the insured won the contract");
      amount = insuranceContracts[_id].totalDeposits;
      (bool success, ) = msg.sender.call{value: amount}("");
      require(success, "Failed to send Ether");
      insuranceContracts[_id].totalDeposits = 0;
    } else {
      // insurers win
      require(msg.sender != insuranceContracts[_id].owner, "You are the insured, and the insurers won the contract");
      amount = insuranceContracts[_id].balance[msg.sender] * insuranceContracts[_id].totalDeposits / (insuranceContracts[_id].totalDeposits - insuranceContracts[_id].balance[insuranceContracts[_id].owner]);
      (bool success, ) = msg.sender.call{value: amount}("");
      require(success, "Failed to send Ether");
      insuranceContracts[_id].balance[msg.sender] = 0;
    }
    emit Redeem(_id, msg.sender, amount);
  }
}
