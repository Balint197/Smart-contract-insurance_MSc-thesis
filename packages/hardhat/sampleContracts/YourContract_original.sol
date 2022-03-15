pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; 
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract YourContract {

  event SetPurpose(address sender, string purpose);

  string public purpose = "Building Unstoppable Apps!!!";
  address payable public owner;

  struct contractParameters {
    uint contractLength;
    uint variableThreshold;
    bool biggerThanThreshold; // if true, contract pays out if final variable is greater than threshold, if false pays if lower than threshold
    address payable insured;
    string name;
    mapping (address => uint) insurerDeposit; // maps the insurers addresses to their deposits
    uint insureeDeposit;
    uint contractState;
  }

  constructor() payable {
    owner = payable(msg.sender);
}

  function setPurpose(string memory newPurpose) public {
      purpose = newPurpose;
      console.log(msg.sender,"set purpose to",purpose);
      emit SetPurpose(msg.sender, purpose);
  }

  function deposit() public payable{}

  function withdraw() public {
    uint amount = address(this).balance;
    (bool success, ) = owner.call{value: amount}("");
    require(success, "Failed to withdraw");
  }

  function balanceOf(address balance_account) public view returns(uint){
    return balance_account.balance;
  }

  // to support receiving ETH by default
  receive() external payable {}
  fallback() external payable {}
}

