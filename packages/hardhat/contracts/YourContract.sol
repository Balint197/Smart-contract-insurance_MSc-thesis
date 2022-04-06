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
    uint creationTime;
    uint contractLength;
    uint variableThreshold;
    uint variableValue;
    bool greaterThanThreshold; // if true, insured wins if final variable is greater than threshold, if false pays insured if lower than threshold
    address insured;
    string name;
    uint insureeDeposit; // delet
    ContractStates contractState;
    uint contractId;
    uint totalDeposits;
    mapping (address => uint) balance; // maps the insurers addresses to their deposits
    mapping (address => bool) hasWithdrawn; 
  }

  contractParameters[] public insuranceContracts;

  mapping (uint => address) public contractToOwner;

  uint depositLength = 1 days;
  uint withdrawLength = 1 days;

  // uint[] test = uint[uint(ContractStates.Funding)];
  

  //@dev ensures a function can only be called at a certain stage
  //     receives multiple enabled stages in an array
  modifier atStage(uint id, ContractStates[2] memory _stage) {//ContractStates _stage) {
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

  // TODO
  modifier onlyContractOwner(uint id){
    _;
    }

  function createInsuranceContract(uint _contractLength, 
                                    uint _variableThreshold, 
                                    bool _greaterThanThreshold, 
                                    string memory _name) payable public {
    contractParameters storage newContract = insuranceContracts.push();
    newContract.creationTime = block.timestamp;
    newContract.contractLength = _contractLength * 1 days;
    newContract.variableThreshold = _variableThreshold;
    newContract.greaterThanThreshold = _greaterThanThreshold;
    newContract.insured = msg.sender;
    newContract.name = _name;
    newContract.contractState = ContractStates.Funding;
    newContract.contractId = insuranceContracts.length - 1;

    contractToOwner[newContract.contractId] = msg.sender;
    emit NewContract(newContract.contractId, _name);
  }

  // DEBUG
  function totalContracts() public view returns (uint){
    return insuranceContracts.length;
  }

  // TODO more involved logic...
  function setValue(uint _value, uint _id) public onlyContractOwner(_id) {
    insuranceContracts[_id].variableValue = _value;
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

  function withdraw(uint _id, uint _withdrawAmount) public timedTransitions(_id) atStage(_id, [ContractStates.Funding, ContractStates.Withdraw]) {
    uint maxAmount = insuranceContracts[_id].balance[msg.sender];
    uint withdrawAmount = _withdrawAmount;

    if (insuranceContracts[_id].contractState == ContractStates.Withdraw){
      uint withdrawMultiplier = 2-(block.timestamp-insuranceContracts[_id].creationTime+depositLength)/(withdrawLength);
      uint maxWithdraw = withdrawMultiplier * maxAmount;
      if (maxWithdraw < withdrawAmount) {
        withdrawAmount = maxWithdraw; // set withdrawable amount to maximum allowed by time
      }
    }

    require(maxAmount >= withdrawAmount, "Trying to withdraw too much");
    (bool success, ) = msg.sender.call{value: withdrawAmount}("");
    require(success, "Failed to send Ether");
    insuranceContracts[_id].balance[msg.sender] -= withdrawAmount;
    insuranceContracts[_id].totalDeposits -= withdrawAmount;
  }

  function active(uint _id) public timedTransitions(_id) atStage(_id, [ContractStates.Active, ContractStates.Active]) {
    // update variable 
  }

  function redeem(uint _id) public timedTransitions(_id) atStage(_id, [ContractStates.Payout, ContractStates.Payout]) {
    bool resultIsGreater;
    if (insuranceContracts[_id].variableValue > insuranceContracts[_id].variableThreshold){
      resultIsGreater = true;
    }

    if (resultIsGreater == insuranceContracts[_id].greaterThanThreshold){
      // insured wins
      // (final value is greater than threshold AND contract pays if its greater) OR (... smaller AND ... smaller)
      require(msg.sender == insuranceContracts[_id].insured);
      (bool success, ) = msg.sender.call{value: insuranceContracts[_id].totalDeposits}("");
      require(success, "Failed to send Ether");
      insuranceContracts[_id].totalDeposits = 0;
    } else {
      // insurers win
      require(msg.sender != insuranceContracts[_id].insured);
      uint amount = insuranceContracts[_id].balance[msg.sender] / (insuranceContracts[_id].totalDeposits - insuranceContracts[_id].balance[insuranceContracts[_id].insured]) * insuranceContracts[_id].totalDeposits;
      (bool success, ) = msg.sender.call{value: amount}("");
      require(success, "Failed to send Ether");
      insuranceContracts[_id].balance[msg.sender] = 0;
    }

  }
}
