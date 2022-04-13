pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; 
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract YourContract {

  event NewContract(uint contractId, string name);
  error FunctionInvalidAtThisStage();

  enum ContractStates {Funding, 
                       Withdraw, 
                       Active, 
                       Payout}

  struct contractParameters { // @TODO oracle datafeed?
    uint contractId;
    string name;
    ContractStates contractState;
    uint variableThreshold;
    uint variableValue;
    bool greaterThanThreshold; // if true, insured wins if final variable is greater than threshold, if false insured wins if lower than or equal to threshold
    uint totalDeposits;
    address owner;
    uint creationTime;
    uint contractLength;
    mapping (address => uint) balance; // maps the insurers addresses to their deposits
    mapping (address => bool) hasWithdrawn; 
  }

  contractParameters[] public insuranceContracts;

  mapping (uint => address) public contractToOwner;

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

  //@dev transitions state after the function [UNUSED]
  modifier transitionNext(uint _id)
  {
      _;
      nextStage(_id);
  }


  // Onlyowner
  function owner(uint id) public view virtual returns (address) {
      return insuranceContracts[id].owner;
  }

  modifier onlyContractOwner(uint id) {
    require(owner(id) == msg.sender, "Ownable: caller is not the owner");
    _;
  }

  // TODO add deposit or make non payable
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
    newContract.owner = msg.sender;
    newContract.name = _name;
    newContract.contractState = ContractStates.Funding;
    newContract.contractId = insuranceContracts.length - 1;
    newContract.balance[msg.sender] = msg.value;
    newContract.totalDeposits = msg.value;

    contractToOwner[newContract.contractId] = msg.sender;
    emit NewContract(newContract.contractId, _name);
  }

  // DEBUG
  function totalContracts() public view returns (uint){
    return insuranceContracts.length;
  }
  
  function myDeposits(uint _id, address _address) public view returns (uint){
    return insuranceContracts[_id].balance[_address];
  }

  function myPayoutInsurer(uint _id, address _address) public view returns (uint){
    return insuranceContracts[_id].balance[_address] * insuranceContracts[_id].totalDeposits / (insuranceContracts[_id].totalDeposits - insuranceContracts[_id].balance[insuranceContracts[_id].owner]);
  }

  // TODO more involved logic...
  function setValue(uint _id, uint _value) private {
    insuranceContracts[_id].variableValue = _value;
  }

  function blocktimestamp() public view returns (uint){
    return block.timestamp;
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

  // TODO using same argument as 2nd parameter where applicable 
  // until solution to passing arbitrary values to array
  function deposit(uint _id) public payable timedTransitions(_id) atStage(_id, [ContractStates.Funding, ContractStates.Funding]) { 
    insuranceContracts[_id].balance[msg.sender] += msg.value;
    insuranceContracts[_id].totalDeposits += msg.value;
  }

  // can withdraw any amount, any times in funding, 
  // can only withdraw once in only withdraw phase, with decreasing max amount to withdraw until contract begins
  function withdraw(uint _id, uint _withdrawAmount) public timedTransitions(_id) atStage(_id, [ContractStates.Funding, ContractStates.Withdraw]) {
    uint maxAmount = insuranceContracts[_id].balance[msg.sender];
    uint withdrawAmount = _withdrawAmount;

    if (insuranceContracts[_id].contractState == ContractStates.Withdraw){
      require(insuranceContracts[_id].hasWithdrawn[msg.sender] == false, "User has already withdrawn once");
      uint withdrawMultiplier = 2-(block.timestamp-insuranceContracts[_id].creationTime+depositLength)/(withdrawLength);
      uint maxWithdraw = withdrawMultiplier * maxAmount;
      if (maxWithdraw < withdrawAmount) {
        withdrawAmount = maxWithdraw; // set withdrawable amount to maximum allowed by time
      }
      // if there are no depositors, refund insured, go to redemption
      if (insuranceContracts[_id].totalDeposits == insuranceContracts[_id].balance[insuranceContracts[_id].owner]){
        withdrawAmount = maxAmount;
        nextStage(_id);
        nextStage(_id);
        console.log("No insurers, owner withdrew in withdraw phase!");
      }
      insuranceContracts[_id].hasWithdrawn[msg.sender] = true; // @!!! what if tx later reverts? does this get written still?
    }

    require(maxAmount >= withdrawAmount, "Trying to withdraw too much");
    (bool success, ) = msg.sender.call{value: withdrawAmount}("");
    require(success, "Failed to send Ether");
    insuranceContracts[_id].balance[msg.sender] -= withdrawAmount;
    insuranceContracts[_id].totalDeposits -= withdrawAmount;
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
    if (insuranceContracts[_id].variableValue > insuranceContracts[_id].variableThreshold){
      resultIsGreater = true; 
    }

    if (resultIsGreater == insuranceContracts[_id].greaterThanThreshold){
      // insured wins
      // (final value is greater than threshold AND contract pays if its greater) OR (... smaller AND ... smaller)
      (bool success, ) = insuranceContracts[_id].owner.call{value: insuranceContracts[_id].totalDeposits}("");
      require(success, "Failed to send Ether");
      insuranceContracts[_id].totalDeposits = 0;
    } else {
      // insurers win
      require(msg.sender != insuranceContracts[_id].owner, "You are the insured, and the insurers won the contract");
      uint amount = insuranceContracts[_id].balance[msg.sender] * insuranceContracts[_id].totalDeposits / (insuranceContracts[_id].totalDeposits - insuranceContracts[_id].balance[insuranceContracts[_id].owner]);
      (bool success, ) = msg.sender.call{value: amount}("");
      require(success, "Failed to send Ether");
      insuranceContracts[_id].balance[msg.sender] = 0;
    }
  }
}
