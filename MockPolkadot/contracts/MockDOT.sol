// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MockDOT is ERC20, Ownable {

    using SafeMath for uint256;

    uint256 public constant LOCK_DURATION = 7 days;
    uint256 public constant VOTE_DURATION = 3 days;
    uint256 public constant MIN_VOTE_QUORUM = 51;

    struct Proposal {
        address proposer;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes;
        bool executed;
    }

    struct StakeLock {
        uint256 amount;
        uint256 releaseTime;
    }

    mapping(address => uint256) private _frozenBalances;
    mapping(uint256 => mapping(address => uint256)) public proposalsVotes;
    mapping(address => StakeLock) public stakeTokens;
    Proposal[] public proposals;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer);
    event Voted(uint256 indexed proposalId, address indexed voter, bool vote);

    constructor() ERC20("Mock DOT Token", "mDOT") {
        _mint(msg.sender, 200);
    }

    modifier onlyProposer(uint256 proposalId) {
        require(msg.sender == proposals[proposalId].proposer , "Only Proposer can call this function");
        _;
    }

    function stake(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        stakeTokens[msg.sender].amount = stakeTokens[msg.sender].amount.add(amount);
        stakeTokens[msg.sender].releaseTime = block.timestamp.add(LOCK_DURATION);
        _frozenBalances[msg.sender] = _frozenBalances[msg.sender].add(amount);
        emit Staked(msg.sender, amount);
    }

    function _unstake(address staker, uint256 amount) internal {
        require(stakeTokens[staker].amount >= amount, "Insufficient staked balance");
        require(stakeTokens[staker].releaseTime <= block.timestamp, "Tokens are still locked");
        _mint(staker, amount);
        stakeTokens[staker].amount = stakeTokens[staker].amount.sub(amount);
        _frozenBalances[staker] = _frozenBalances[staker].sub(amount);
        emit Unstaked(staker, amount);
    }

    function createProposal() public{ 
        proposals.push(Proposal({
            proposer: msg.sender,
            endTime: block.timestamp.add(VOTE_DURATION),
            yesVotes: 0,
            noVotes: 0,
            executed: false
        }));
        emit ProposalCreated(proposals.length - 1, msg.sender);
    }

    function vote(uint256 proposalId, bool support, uint256 amount) public {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp <= proposal.endTime, "Voting period has ended");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to vote");

        if (support) {
            proposal.yesVotes = proposal.yesVotes.add(amount);
        } else {
            proposal.noVotes = proposal.noVotes.add(amount);
        }
        _burn(msg.sender, amount);
        proposalsVotes[proposalId][msg.sender] = proposalsVotes[proposalId][msg.sender].add(amount);
        _frozenBalances[msg.sender] = _frozenBalances[msg.sender].add(amount);
        emit Voted(proposalId, msg.sender, support);
    }

    function releaseVotedTokens(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.endTime < block.timestamp && !proposal.executed, "Voting period has not ended");
        uint256 amount = proposalsVotes[proposalId][msg.sender];
        require(amount > 0, "No token to release");
        _mint(msg.sender, amount);
        proposalsVotes[proposalId][msg.sender] = 0;
        _frozenBalances[msg.sender] = _frozenBalances[msg.sender].sub(amount);
    }

    function executeProposal(uint256 proposalId, address target, uint256 unstakeAmount) public onlyProposer(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp > proposal.endTime, "Voting period not ended");

        uint256 totalVotes = proposal.yesVotes
        .add(proposal.noVotes);
        uint256 quorum = proposal.yesVotes.mul(100).div(totalVotes);
        require(quorum >= MIN_VOTE_QUORUM, "Proposal did not meet the minimum vote quorum");

        _unstake(target, unstakeAmount);
        proposal.executed = true;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override{
        if (from != address(0)) {
            uint256 availableBalance = balanceOf(from).sub(_frozenBalances[from]);
            require(availableBalance >= amount, "ERC20: transfer amount exceeds available balance");
        }
        super._beforeTokenTransfer(from, to, amount);
    }

    function frozenBalancesOf() public view returns (uint256) {
        return _frozenBalances[msg.sender];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
}
