pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; 
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract contractFactory is Ownable {

  event NewContract(uint contractId, string name);

  struct contractParameters { // @TODO oracle datafeed?
    uint contractLength;
    uint variableThreshold;
    bool greaterThanThreshold; // if true, contract pays out if final variable is greater than threshold, if false pays if lower than threshold
    address insured;
    string name;
    uint insureeDeposit;
    uint contractState;
    uint contractId;
    mapping (address => uint) insurerDeposit; // maps the insurers addresses to their deposits
  }

  contractParameters[] public insuranceContracts;

  mapping (uint => address) public contractToOwner;

  function createInsuranceContract(uint _contractLength, 
                                    uint _variableThreshold, 
                                    bool _greaterThanThreshold, 
                                    string memory _name) payable public {
    contractParameters storage newContract = insuranceContracts.push();
    newContract.contractLength = _contractLength;
    newContract.variableThreshold = _variableThreshold;
    newContract.greaterThanThreshold = _greaterThanThreshold;
    newContract.insured = msg.sender;
    newContract.name = _name;
    newContract.contractId = insuranceContracts.length + 1;
    
    //contractToOwner[newContract.insured] = msg.sender;
    emit NewContract(newContract.contractId, _name);
  }
}
