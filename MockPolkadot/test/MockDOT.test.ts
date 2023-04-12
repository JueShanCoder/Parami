import { ethers } from "hardhat";
import { expect } from "chai";
import { Contract, BigNumber } from "ethers";
const { parseEther } = ethers.utils;

describe("MockDOT", () => {
  let MockDOT: Contract;
  // owner
  let owner: any;
  // staker
  let addr1: any;
  // yes voter1
  let addr2: any;
  // yes voter2
  let addr3: any;
  // no voter1
  let addr4: any;


  beforeEach(async () => {
    const MockDOTFactory = await ethers.getContractFactory("MockDOT");
    MockDOT = await MockDOTFactory.deploy();
    await MockDOT.deployed();
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
    await MockDOT.transfer(addr1.address, 40);
    await MockDOT.transfer(addr2.address, 40);
    await MockDOT.transfer(addr3.address, 40);
    await MockDOT.transfer(addr4.address, 40);
  });

  it("Should have correct initial state", async () => {
    const name = await MockDOT.name();
    const symbol = await MockDOT.symbol();
    const ownerBalance = await MockDOT.balanceOf(owner.address);
    const addr1Balance = await MockDOT.balanceOf(addr1.address);
    const addr2Balance = await MockDOT.balanceOf(addr2.address);
    const addr3Balance = await MockDOT.balanceOf(addr3.address);
    const addr4Balance = await MockDOT.balanceOf(addr4.address);

    expect(name).to.equal("Mock DOT Token");
    expect(symbol).to.equal("mDOT");
    expect(ownerBalance.toString()).to.equal("40");
    expect(addr1Balance.toString()).to.equal("40");
    expect(addr2Balance.toString()).to.equal("40");
    expect(addr3Balance.toString()).to.equal("40");
    expect(addr4Balance.toString()).to.equal("40");
  });

  it("Should be able to stake tokens", async () => {
    await MockDOT.stake(20);
    const lockedAmount = (await MockDOT.stakeTokens(owner.address)).amount;

    expect(lockedAmount).to.equal(20);
  });

  it("Should be able to create a proposal", async () => {
    const tx = await MockDOT.createProposal();
    const proposalId = (await tx.wait()).events[0].args.proposalId;
    const proposal = await MockDOT.proposals(proposalId);
    expect(proposal.proposer).to.equal(owner.address);
  });

  it("Should be able to vote on a proposal", async () => {
    await MockDOT.createProposal();
    await MockDOT.connect(addr2).vote(0, true, 20);
    await MockDOT.connect(addr4).vote(0, false, 20);

    const proposal = await MockDOT.proposals(0);
    expect(proposal.yesVotes).to.equal(20);
    expect(proposal.noVotes).to.equal(20);
  });

  it("Should be able to execute a proposal with a successful quorum", async () => {
    // addr1 stakes 20 tokens
    const amountToStake = 20;
    // addr2 and addr3 addr4 vote 20 tokens each 
    // addr2 and addr3 vote yes , addr4 votes no
    const amountToVote = 20;

    await MockDOT.connect(addr1).stake(amountToStake);

    // Fast forward time by 7 days to simulate staking period ending
    await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    await MockDOT.createProposal();
    await MockDOT.connect(addr2).vote(0, true, amountToVote);
    await MockDOT.connect(addr3).vote(0, true, amountToVote);
    await MockDOT.connect(addr4).vote(0, false, amountToVote);
    // Fast forward time by 3 days to simulate voting period ending
    await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    const proposalBefore = await MockDOT.proposals(0);
    const beforeFrozenBalance = await MockDOT.connect(addr1).frozenBalancesOf();
    await MockDOT.executeProposal(0, addr1.address, amountToStake);
    const proposalAfter = await MockDOT.proposals(0);
    const afterFrozenBalance = await MockDOT.connect(addr1).frozenBalancesOf();
    expect(proposalBefore.executed).to.equal(false);
    expect(proposalAfter.executed).to.equal(true);
    expect(afterFrozenBalance).to.equal(beforeFrozenBalance - amountToStake);
  });
});

