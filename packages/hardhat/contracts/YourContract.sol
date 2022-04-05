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
    bool greaterThanThreshold; // if true, contract pays out if final variable is greater than threshold, if false pays if lower than threshold
    address insured;
    string name;
    uint insureeDeposit; // delet
    ContractStates contractState;
    uint contractId;
    mapping (address => uint) balance; // maps the insurers addresses to their deposits
  }

  contractParameters[] public insuranceContracts;

  mapping (uint => address) public contractToOwner;

  uint depositLength = 1 days;
  uint withdrawLength = 1 days;

  // uint[] test = uint[uint(ContractStates.Funding)];
  

  //@dev ensures a function can only be called at a certain stage
  //     receives multiple enabled stages in an array
  modifier atStage(uint id, ContractStates[2] memory _stage) {//ContractStates _stage) {
      uint stageRevert;
      for (uint i = 0; i < _stage.length; i++){
        if (insuranceContracts[id].contractState != _stage[i])
          stageRevert++;
        if (stageRevert > _stage.length - 1) // if at least one stage is allowed
          revert FunctionInvalidAtThisStage();
        _;
      }
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

  // TODO using same argument as 2nd parameter until solution to passing arbitrary values to array
  function deposit(uint _id) public payable timedTransitions(_id) atStage(_id, [ContractStates.Funding, ContractStates.Funding]) { 
    insuranceContracts[_id].balance[msg.sender] += msg.value;
  }

  function withdraw(uint _id, uint withdrawAmount) public timedTransitions(_id) atStage(_id, [ContractStates.Funding, ContractStates.Withdraw]) {
    uint maxAmount = insuranceContracts[_id].balance[msg.sender];

    if (insuranceContracts[_id].contractState == ContractStates.Withdraw){
      uint withdrawMultiplier = (block.timestamp-insuranceContracts[_id].creationTime+depositLength)/(withdrawLength)-1;
      // ...
    }


    require(maxAmount >= withdrawAmount, "Trying to withdraw too much");
    (bool success, ) = msg.sender.call{value: withdrawAmount}("");
    require(success, "Failed to send Ether");
  }

  function active(uint _id) public timedTransitions(_id) atStage(_id, [ContractStates.Active, ContractStates.Active]) {
    // ...
  }

  function redeem(uint _id) public timedTransitions(_id) atStage(_id, [ContractStates.Payout, ContractStates.Payout]) {
    // ...
  }




}
