const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Insurance", function () {

  let Insurance;
  let insurance;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    Insurance = await ethers.getContractFactory("Insurance");
    [owner, addr1, addr2] = await ethers.getSigners();

    insurance = await Insurance.deploy();
  });


  it("Should return the total number of contracts as 0 at deployment", async function () {
    expect(await insurance.totalContracts()).to.equal(0);
  });

  it("Should create a new insurance contract with correct balances", async function () {
    const createInsuranceTx = await insurance.createInsuranceContract(3, 15, 1, "Test contract", { value: ethers.utils.parseEther("1.0") });
    await createInsuranceTx.wait();

    expect(await insurance.totalContracts()).to.equal(1);
    
    //console.log(owner)
    expect(await insurance.owner(0)).to.equal(owner.address);

    //console.log(await insurance.insuranceContracts(0))

    expect(await insurance.addressDeposits(0, owner.address)).to.equal(ethers.utils.parseEther("1.0"));
    expect(await insurance.addressMaxWithdraw(0, owner.address)).to.equal(ethers.utils.parseEther("1.0"));
  });
  
  it("Should make sure withdraws work", async function () {

    const createInsuranceTx2 = await insurance.connect(addr1).createInsuranceContract(3, 15, 1, "Test contract", { value: ethers.utils.parseEther("1.0") });
    await createInsuranceTx2.wait();

    expect(await insurance.owner(0)).to.equal(addr1.address);

    expect(await insurance.connect(owner).addressDeposits(0, owner.address)).to.equal(ethers.utils.parseEther("0.0"));
    expect(await insurance.connect(addr1).addressDeposits(0, addr1.address)).to.equal(ethers.utils.parseEther("1.0"));

    expect(await insurance.connect(addr1).addressMaxWithdraw(0, addr1.address)).to.equal(ethers.utils.parseEther("1.0"));
    expect(await insurance.connect(owner).addressMaxWithdraw(0, owner.address)).to.equal(ethers.utils.parseEther("0.0"));

    const validWithdrawTx = await insurance.connect(addr1).withdraw(0, ethers.utils.parseEther("0.4"));
    await validWithdrawTx.wait();
    expect(await insurance.addressDeposits(0, addr1.address)).to.equal(ethers.utils.parseEther("0.6"));

    const invalidWithdrawTx = await insurance.connect(owner).withdraw(0, ethers.utils.parseEther("0.4"));
    await invalidWithdrawTx.wait();
    
    //await expect(insurance.addressDeposits(0, addr1.address)).to.be.reverted;
    await expect(insurance.addressDeposits(0, addr1.address)).to.be.revertedWith('Withdrawing more than allowed');
    
    //expect(await insurance.addressDeposits(0, addr1.address)).to.equal(ethers.utils.parseEther("0.6"));

    

//    expect(await insurance.addressMaxWithdraw(0, addr1.address)).to.equal(ethers.utils.parseEther("0.0"));

    
  });
  
  /*
  it("Should have correct deposit amounts", async function () {
    const depositTx = await insurance.deposit(3, 15, 1, "Test contract", { value: ethers.utils.parseEther("1.0") });
    await depositTx.wait();

    expect(await insurance.totalContracts()).to.equal(1);
    
    //console.log(owner)
    expect(await insurance.owner(0)).to.equal(owner.address);

    //console.log(await insurance.insuranceContracts(0))

    expect(await insurance.addressDeposits(0, owner.address)).to.equal(ethers.utils.parseEther("1.0"));
    expect(await insurance.addressMaxWithdraw(0, owner.address)).to.equal(ethers.utils.parseEther("1.0"));
  });
*/

});
