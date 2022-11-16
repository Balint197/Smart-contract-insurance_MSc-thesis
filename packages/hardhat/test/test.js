const { expect, should } = require("chai");
const { ethers } = require("hardhat");

describe("Insurance", function () {

  let Insurance;
  let insurance;
  let owner;
  let addr1;
  let addr2;
  let oracle;

  let balanceBefore0;
  let balanceBefore1;
  let balanceBefore2;

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    Insurance = await ethers.getContractFactory("YourContract");
    [owner, addr1, addr2, oracle] = await ethers.getSigners();

    insurance = await Insurance.deploy();

    // save balances 
    balanceBefore0 = await ethers.provider.getBalance(owner.address);
    balanceBefore1 = await ethers.provider.getBalance(addr1.address);
    balanceBefore2 = await ethers.provider.getBalance(addr2.address);

    // create insurance contract and fund with 2 ETH
    const createInsuranceTx = await insurance.connect(owner).createInsuranceContract(3, 15, 1, 12, -23, "Test contract", "23adb8e036b04b18895440e174a9e329", oracle.address, { value: ethers.utils.parseEther("2.0") });
    await createInsuranceTx.wait();
  });

  it("Should test time incrementing works", async function () {
    await incrementTime(oneDay);
    await incrementTime(oneHour);
    await incrementTime(oneDay);
  });

  it("Should return the total number of contracts as 1 after deployment and 1 contract", async function () {
    expect(await insurance.totalContracts()).to.equal(1);
  });

  it("Should create a new insurance contract with correct balances", async function () {

    expect(await insurance.totalContracts()).to.equal(1);
    expect(await insurance.insuranceOwner(0)).to.equal(owner.address);

    expect(await insurance.addressDeposits(0, owner.address)).to.equal(ethers.utils.parseEther("2.0"));
    expect(await insurance.addressMaxWithdraw(0, owner.address)).to.equal(ethers.utils.parseEther("2.0"));

    expect(await insurance.addressDeposits(0, addr1.address)).to.equal(ethers.utils.parseEther("0.0"));
    expect(await insurance.addressMaxWithdraw(0, addr1.address)).to.equal(ethers.utils.parseEther("0.0"));
  });
  
  it("Should make sure withdraws work", async function () {

    expect(await insurance.insuranceOwner(0)).to.equal(owner.address);

    // checking deposits
    expect(await insurance.connect(owner).addressDeposits(0, owner.address)).to.equal(ethers.utils.parseEther("2.0"));
    expect(await insurance.connect(addr1).addressDeposits(0, addr1.address)).to.equal(ethers.utils.parseEther("0.0"));

    expect(await insurance.connect(owner).addressMaxWithdraw(0, owner.address)).to.equal(ethers.utils.parseEther("2.0"));
    expect(await insurance.connect(addr1).addressMaxWithdraw(0, addr1.address)).to.equal(ethers.utils.parseEther("0.0"));

    // withdraw 0.4 from owner (1.6 left)
    const validWithdrawTx = await insurance.connect(owner).withdraw(0, ethers.utils.parseEther("0.4"));
    await validWithdrawTx.wait();
    expect(await insurance.addressDeposits(0, owner.address)).to.equal(ethers.utils.parseEther("1.6"));

    // try to withdraw 0.4 from addr1 (has no deposits)
    await expect(insurance.connect(addr1).withdraw(0, ethers.utils.parseEther("0.4"))).to.be.revertedWith("Withdrawing more than allowed");
  });

  it("Should make sure withdraws work at deposit and withdraw stages", async function () {

    // wait 1 hour from contract start -> deposit and withdraw phase
    await incrementTime(oneHour);
    // insurers deposit
    const depositTx1 = await insurance.connect(addr1).deposit(0, { value: ethers.utils.parseEther("0.4") });
    await depositTx1.wait();
    const depositTx2 = await insurance.connect(addr2).deposit(0, { value: ethers.utils.parseEther("0.7") });
    await depositTx2.wait();

    // wait 1 hour -> still deposit and withdraw phase
    await incrementTime(oneHour);
    // withdraw 0.4 from owner in deposit stage (1.6 left)
    const depositWithdrawTx = await insurance.connect(owner).withdraw(0, ethers.utils.parseEther("0.4"));
    await depositWithdrawTx.wait();
    expect(await insurance.addressDeposits(0, owner.address)).to.equal(ethers.utils.parseEther("1.6"));
    // withdraw 0.1 from addr1 in deposit stage (0.3 left)
    const depositWithdrawTx1 = await insurance.connect(addr1).withdraw(0, ethers.utils.parseEther("0.1"));
    await depositWithdrawTx1.wait();
    expect(await insurance.addressDeposits(0, addr1.address)).to.equal(ethers.utils.parseEther("0.3"));
    
    // -----------------------------------
    // wait 1 day -> withdraw only phase
    await incrementTime(oneDay);
    // withdraw 0.05 from addr1 in withdraw stage (0.25 left)
    const withdrawWithdrawTx1 = await insurance.connect(addr1).withdraw(0, ethers.utils.parseEther("0.05"));
    await withdrawWithdrawTx1.wait();
    expect(await insurance.addressDeposits(0, addr1.address)).to.equal(ethers.utils.parseEther("0.25"));
    // withdraw 0.1 from owner in withdraw stage (1.5 left)
    const withdrawWithdrawTx2 = await insurance.connect(owner).withdraw(0, ethers.utils.parseEther("0.1"));
    await withdrawWithdrawTx2.wait();
    expect(await insurance.addressDeposits(0, owner.address)).to.equal(ethers.utils.parseEther("1.5"));
    // withdraw 0.2 from addr2 in withdraw stage (0.5 left)
    const withdrawWithdrawTx3 = await insurance.connect(addr2).withdraw(0, ethers.utils.parseEther("0.2"));
    await withdrawWithdrawTx3.wait();
    expect(await insurance.addressDeposits(0, addr2.address)).to.equal(ethers.utils.parseEther("0.5"));
    
    // testing deposits during withdraw only phase
    await expect(insurance.connect(owner).deposit(0, ethers.utils.parseEther("0.4"))).to.be.reverted;
    await expect(insurance.connect(addr1).deposit(0, ethers.utils.parseEther("0.4"))).to.be.reverted;

    // -----------------------------------
    // wait 1 day -> active phase (no withdraw, no deposit)
    await incrementTime(oneDay);
    // try to withdraw in active stage
    await expect(insurance.connect(owner).withdraw(0, ethers.utils.parseEther("0.05"))).to.be.reverted;
    await expect(insurance.connect(addr1).withdraw(0, ethers.utils.parseEther("0.05"))).to.be.reverted;

    // try to deposit during active phase
    await expect(insurance.connect(owner).deposit(0, ethers.utils.parseEther("0.4"))).to.be.reverted;
    await expect(insurance.connect(addr1).deposit(0, ethers.utils.parseEther("0.4"))).to.be.reverted;

    // -----------------------------------
    // wait 3 day (length of contract) -> redeem phase (no withdraw, no deposit)
    await incrementTime(3 * oneDay);
    // try to withdraw in redeem stage
    await expect(insurance.connect(owner).withdraw(0, ethers.utils.parseEther("0.05"))).to.be.reverted;
    await expect(insurance.connect(addr1).withdraw(0, ethers.utils.parseEther("0.05"))).to.be.reverted;

    // try to deposit during redeem phase
    await expect(insurance.connect(owner).deposit(0, ethers.utils.parseEther("0.4"))).to.be.reverted;
    await expect(insurance.connect(addr1).deposit(0, ethers.utils.parseEther("0.4"))).to.be.reverted;

  });

  it("Should make sure setting values works and payout is correct - 1, lower", async function () {

    // wait 1 hour from contract start -> deposit and withdraw phase
    await incrementTime(oneHour);
    
    // insurers deposit - total 1.7
    const depositTx1 = await insurance.connect(addr1).deposit(0, { value: ethers.utils.parseEther("0.8") });
    await depositTx1.wait();
    const depositTx2 = await insurance.connect(addr2).deposit(0, { value: ethers.utils.parseEther("0.9") });
    await depositTx2.wait();

    // wait 1 hour -> still deposit and withdraw phase
    await incrementTime(oneHour);
    
    // -----------------------------------
    // wait 1 day -> withdraw only phase
    await incrementTime(oneDay);
    // insurers withdraw - total 1.4
    const withdrawTx1 = await insurance.connect(addr1).withdraw(0, ethers.utils.parseEther("0.2"));
    await withdrawTx1.wait();
    const withdrawTx2 = await insurance.connect(addr2).withdraw(0, ethers.utils.parseEther("0.1"));
    await withdrawTx2.wait();

    // -----------------------------------
    // wait 1 day -> active phase (no withdraw, no deposit)
    await incrementTime(oneDay);
    // set value lower so insurer wins
    const setValueTx = await insurance.connect(owner).active(0, 10);
    await setValueTx.wait();

    // -----------------------------------
    // wait 3 days (length of contract) -> redeem phase
    await incrementTime(3 * oneDay);
    // try to redeem 
    //  addr1 wins 0.85714285714285714285714285714286 
    //  addr2 wins 1.1428571428571428571428571428571

    await expect(insurance.connect(owner).redeem(0)).to.be.reverted;
    const balanceAfter0 = await ethers.provider.getBalance(owner.address);
    const diff0 = ethers.utils.formatEther((balanceAfter0 - balanceBefore0).toString());

    const redeemTx1 = await insurance.connect(addr1).redeem(0);
    await redeemTx1.wait();
    const balanceAfter1 = await ethers.provider.getBalance(addr1.address);
    const diff1 = ethers.utils.formatEther((balanceAfter1 - balanceBefore1).toString());
    
    const redeemTx2 = await insurance.connect(addr2).redeem(0);
    await redeemTx2.wait();
    const balanceAfter2 = await ethers.provider.getBalance(addr2.address);
    const diff2 = ethers.utils.formatEther((balanceAfter2 - balanceBefore2).toString());

    const sum = (parseFloat(diff2) + parseFloat(diff1)).toString();

    expect(parseFloat(diff0)).to.be.closeTo(-2, 0.01);
    expect(parseFloat(diff1)).to.be.closeTo(0.8571428, 0.01);
    expect(parseFloat(diff2)).to.be.closeTo(1.142857, 0.01);
    expect(parseFloat(sum)).to.be.closeTo(2, 0.01);
  });

  it("Should make sure setting values works and payout is correct - 1, higher", async function () {

    // wait 1 hour from contract start -> deposit and withdraw phase
    await incrementTime(oneHour);
    
    // insurers deposit - total 1.7
    const depositTx1 = await insurance.connect(addr1).deposit(0, { value: ethers.utils.parseEther("0.8") });
    await depositTx1.wait();
    const depositTx2 = await insurance.connect(addr2).deposit(0, { value: ethers.utils.parseEther("0.9") });
    await depositTx2.wait();

    // wait 1 hour -> still deposit and withdraw phase
    await incrementTime(oneHour);
    
    // -----------------------------------
    // wait 1 day -> withdraw only phase
    await incrementTime(oneDay);
    // insurers withdraw - total 1.4
    const withdrawTx1 = await insurance.connect(addr1).withdraw(0, ethers.utils.parseEther("0.2"));
    await withdrawTx1.wait();
    const withdrawTx2 = await insurance.connect(addr2).withdraw(0, ethers.utils.parseEther("0.1"));
    await withdrawTx2.wait();

    // -----------------------------------
    // wait 1 day -> active phase (no withdraw, no deposit)
    await incrementTime(oneDay);
    // set value higher so insured wins
    const setValueTx = await insurance.connect(owner).active(0, 20);
    await setValueTx.wait();

    // -----------------------------------
    // wait 3 days (length of contract) -> redeem phase
    await incrementTime(3 * oneDay);
    // try to redeem 
    //  owner wins 1.1

    const redeemTx0 = await insurance.connect(owner).redeem(0);
    await redeemTx0.wait();
    const balanceAfter0 = await ethers.provider.getBalance(owner.address);
    const diff0 = ethers.utils.formatEther((balanceAfter0 - balanceBefore0).toString());
    
    await expect(insurance.connect(addr1).redeem(0)).to.be.reverted;
    const balanceAfter1 = await ethers.provider.getBalance(addr1.address);
    const diff1 = ethers.utils.formatEther((balanceAfter1 - balanceBefore1).toString());
    
    await expect(insurance.connect(addr1).redeem(0)).to.be.reverted;
    const balanceAfter2 = await ethers.provider.getBalance(addr2.address);
    const diff2 = ethers.utils.formatEther((balanceAfter2 - balanceBefore2).toString());

    expect(parseFloat(diff0)).to.be.closeTo(1.4, 0.01);
    expect(parseFloat(diff1)).to.be.closeTo(-0.6, 0.01);
    expect(parseFloat(diff2)).to.be.closeTo(-0.8, 0.01);
  });


  it("Should make sure setting values works and payout is correct - 0, lower", async function () {

    // deploying new insurance, so need to save balances again
    balanceBefore0 = await ethers.provider.getBalance(owner.address);
    balanceBefore1 = await ethers.provider.getBalance(addr1.address);
    balanceBefore2 = await ethers.provider.getBalance(addr2.address);
    // deploy new insurance contract, id = 1
    // create insurance contract and fund with 2 ETH
    const createInsuranceTx = await insurance.connect(owner).createInsuranceContract(3, 15, 0, 12, -23, "Test contract", "23adb8e036b04b18895440e174a9e329", oracle.address, { value: ethers.utils.parseEther("2.0") });
    await createInsuranceTx.wait();

    // wait 1 hour from contract start -> deposit and withdraw phase
    await incrementTime(oneHour);
    
    // insurers deposit - total 1.7
    const depositTx1 = await insurance.connect(addr1).deposit(1, { value: ethers.utils.parseEther("0.8") });
    await depositTx1.wait();
    const depositTx2 = await insurance.connect(addr2).deposit(1, { value: ethers.utils.parseEther("0.9") });
    await depositTx2.wait();

    // wait 1 hour -> still deposit and withdraw phase
    await incrementTime(oneHour);
    
    // -----------------------------------
    // wait 1 day -> withdraw only phase
    await incrementTime(oneDay);
    // insurers withdraw - total 1.4
    const withdrawTx1 = await insurance.connect(addr1).withdraw(1, ethers.utils.parseEther("0.2"));
    await withdrawTx1.wait();
    const withdrawTx2 = await insurance.connect(addr2).withdraw(1, ethers.utils.parseEther("0.1"));
    await withdrawTx2.wait();

    // -----------------------------------
    // wait 1 day -> active phase (no withdraw, no deposit)
    await incrementTime(oneDay);
    // set value lower so insurer wins
    const setValueTx = await insurance.connect(owner).active(1, 10);
    await setValueTx.wait();

    // -----------------------------------
    // wait 3 days (length of contract) -> redeem phase
    await incrementTime(3 * oneDay);
    // try to redeem 
    //  owner wins 1.1

    const redeemTx0 = await insurance.connect(owner).redeem(1);
    await redeemTx0.wait();
    const balanceAfter0 = await ethers.provider.getBalance(owner.address);
    const diff0 = ethers.utils.formatEther((balanceAfter0 - balanceBefore0).toString());
    
    await expect(insurance.connect(addr1).redeem(1)).to.be.reverted;
    const balanceAfter1 = await ethers.provider.getBalance(addr1.address);
    const diff1 = ethers.utils.formatEther((balanceAfter1 - balanceBefore1).toString());
    
    await expect(insurance.connect(addr1).redeem(1)).to.be.reverted;
    const balanceAfter2 = await ethers.provider.getBalance(addr2.address);
    const diff2 = ethers.utils.formatEther((balanceAfter2 - balanceBefore2).toString());

    expect(parseFloat(diff0)).to.be.closeTo(1.4, 0.01);
    expect(parseFloat(diff1)).to.be.closeTo(-0.6, 0.01);
    expect(parseFloat(diff2)).to.be.closeTo(-0.8, 0.01);
  });

  it("Should make sure setting values works and payout is correct - 0, higher", async function () {

    // deploying new insurance, so need to save balances again
    balanceBefore0 = await ethers.provider.getBalance(owner.address);
    balanceBefore1 = await ethers.provider.getBalance(addr1.address);
    balanceBefore2 = await ethers.provider.getBalance(addr2.address);
    // deploy new insurance contract, id = 1
    // create insurance contract and fund with 2 ETH
    const createInsuranceTx = await insurance.connect(owner).createInsuranceContract(3, 15, 0, 12, -23, "Test contract", "23adb8e036b04b18895440e174a9e329", oracle.address, { value: ethers.utils.parseEther("2.0") });
    await createInsuranceTx.wait();

    // wait 1 hour from contract start -> deposit and withdraw phase
    await incrementTime(oneHour);
    
    // insurers deposit - total 1.7
    const depositTx1 = await insurance.connect(addr1).deposit(1, { value: ethers.utils.parseEther("0.8") });
    await depositTx1.wait();
    const depositTx2 = await insurance.connect(addr2).deposit(1, { value: ethers.utils.parseEther("0.9") });
    await depositTx2.wait();

    // wait 1 hour -> still deposit and withdraw phase
    await incrementTime(oneHour);
    
    // -----------------------------------
    // wait 1 day -> withdraw only phase
    await incrementTime(oneDay);
    // insurers withdraw - total 1.4
    const withdrawTx1 = await insurance.connect(addr1).withdraw(1, ethers.utils.parseEther("0.2"));
    await withdrawTx1.wait();
    const withdrawTx2 = await insurance.connect(addr2).withdraw(1, ethers.utils.parseEther("0.1"));
    await withdrawTx2.wait();

    // -----------------------------------
    // wait 1 day -> active phase (no withdraw, no deposit)
    await incrementTime(oneDay);
    // set value lower so insured wins
    const setValueTx = await insurance.connect(owner).active(1, 20);
    await setValueTx.wait();

    // -----------------------------------
    // wait 3 days (length of contract) -> redeem phase
    await incrementTime(3 * oneDay);
    // try to redeem 
    //  addr1 wins 0.85714285714285714285714285714286 
    //  addr2 wins 1.1428571428571428571428571428571

    await expect(insurance.connect(owner).redeem(1)).to.be.reverted;
    const balanceAfter0 = await ethers.provider.getBalance(owner.address);
    const diff0 = ethers.utils.formatEther((balanceAfter0 - balanceBefore0).toString());

    const redeemTx1 = await insurance.connect(addr1).redeem(1);
    await redeemTx1.wait();
    const balanceAfter1 = await ethers.provider.getBalance(addr1.address);
    const diff1 = ethers.utils.formatEther((balanceAfter1 - balanceBefore1).toString());
    
    const redeemTx2 = await insurance.connect(addr2).redeem(1);
    await redeemTx2.wait();
    const balanceAfter2 = await ethers.provider.getBalance(addr2.address);
    const diff2 = ethers.utils.formatEther((balanceAfter2 - balanceBefore2).toString());

    const sum = (parseFloat(diff2) + parseFloat(diff1)).toString();

    expect(parseFloat(diff0)).to.be.closeTo(-2, 0.01);
    expect(parseFloat(diff1)).to.be.closeTo(0.8571428, 0.01);
    expect(parseFloat(diff2)).to.be.closeTo(1.142857, 0.01);
    expect(parseFloat(sum)).to.be.closeTo(2, 0.01);
  });

it("Should make sure withdraw time-cap works", async function () {

  // wait 1 hour from contract start -> deposit and withdraw phase
  await incrementTime(oneHour);
  
  // insurers deposit - total 1.7
  const depositTx1 = await insurance.connect(addr1).deposit(0, { value: ethers.utils.parseEther("0.8") });
  await depositTx1.wait();
  const depositTx2 = await insurance.connect(addr2).deposit(0, { value: ethers.utils.parseEther("0.9") });
  await depositTx2.wait();

  // wait 1 hour -> still deposit and withdraw phase
  await incrementTime(oneHour);
  
  // -----------------------------------
  // wait 1 day -> withdraw only phase
  await incrementTime(oneDay);
  // wait 6 hours for withdraw testing
  // time: 8/24 hours -> 2/3 withdrawable
  await incrementTime(6 * oneHour);

  // addr1 tries to withdraw more than 2/3 
  const failedWithdraw1 = (0.8 * 2 / 3).toString();
  await expect(insurance.connect(addr1).withdraw(0, ethers.utils.parseEther(failedWithdraw1))).to.be.reverted;
  
  // save accounts deposit before withdrawing
  const depositBefore = await insurance.connect(addr1).addressDeposits(0, addr1.address);
  
  // withdraw bit less than failed 
  const successWithdraw1 = (parseFloat(failedWithdraw1) - 0.001).toString();
  const withdrawTx1 = await insurance.connect(addr1).withdraw(0, ethers.utils.parseEther(successWithdraw1));
  await withdrawTx1.wait();
  
  const depositAfter = await insurance.connect(addr1).addressDeposits(0, addr1.address);
  expect(depositAfter).to.equal(267666666666666700n); 
  
  // testing if withdrawing again fails correctly
  await expect(insurance.connect(addr1).withdraw(0, ethers.utils.parseEther("0.001"))).to.be.reverted;
});

it("Shouldn't allow non-owners to set value", async function () {
  
    // wait 1 hour from contract start -> deposit and withdraw phase
    await incrementTime(oneHour);
    
    // insurers deposit - total 1.7
    const depositTx1 = await insurance.connect(addr1).deposit(0, { value: ethers.utils.parseEther("0.8") });
    await depositTx1.wait();
    const depositTx2 = await insurance.connect(addr2).deposit(0, { value: ethers.utils.parseEther("0.9") });
    await depositTx2.wait();

    // wait 1 hour -> still deposit and withdraw phase
    await incrementTime(oneHour);
    
    // -----------------------------------
    // wait 1 day -> withdraw only phase
    await incrementTime(oneDay);
    // insurers withdraw - total 1.4
    const withdrawTx1 = await insurance.connect(addr1).withdraw(0, ethers.utils.parseEther("0.2"));
    await withdrawTx1.wait();
    const withdrawTx2 = await insurance.connect(addr2).withdraw(0, ethers.utils.parseEther("0.1"));
    await withdrawTx2.wait();

    // -----------------------------------
    // wait 1 day -> active phase (no withdraw, no deposit)
    await incrementTime(oneDay);
    // set value lower so insurer wins
    await expect(insurance.connect(addr1).active(0, 10)).to.be.reverted;
});

});

// helpers

const oneHour = 60 * 60; // one hour in seconds
const oneDay = oneHour * 24; // one day in seconds

async function incrementTime(time) {

  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  
  await ethers.provider.send("evm_mine", [blockBefore.timestamp + time]);
  // or in 2 steps (increase time -> mine block): 
  //await ethers.provider.send('evm_increaseTime', [time]);
  //await ethers.provider.send('evm_mine');
  
  const blockNumAfter = await ethers.provider.getBlockNumber();
  const blockAfter = await ethers.provider.getBlock(blockNumAfter);
  const timestampAfter = blockAfter.timestamp;

  expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
  expect(timestampAfter).to.be.equal(timestampBefore + time);

}