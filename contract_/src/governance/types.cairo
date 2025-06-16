use starknet::ContractAddress;

// Core proposal types (removed Array field to fix storage error)
#[derive(Drop, Serde, starknet::Store)]
pub struct Proposal {
    pub id: u64,
    pub title: ByteArray,
    pub description: ByteArray,
    pub category: felt252, // "REVENUE", "MARKETING", "CREATIVE", "OTHER"
    pub status: u8, // 0=Pending, 1=Approved, 2=Rejected, 3=Implemented, 4=Vetoed
    pub proposer: ContractAddress,
    pub token_contract: ContractAddress,
    pub timestamp: u64,
    pub votes_for: u256,
    pub votes_against: u256,
    pub artist_response: ByteArray,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Comment {
    pub id: u64,
    pub proposal_id: u64,
    pub commenter: ContractAddress,
    pub content: ByteArray,
    pub timestamp: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ProposalMetrics {
    pub comment_count: u64,
    pub total_voters: u64,
    pub total_votes: u64,
    pub approval_rating: u64,
}

// Voting-related types
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum VoteType {
    #[default]
    None: (),
    For: (),
    Against: (),
    Abstain: (),
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Vote {
    pub vote_type: VoteType,
    pub weight: u256,
    pub timestamp: u64,
    pub delegated: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct VoteTally {
    pub total_for: u256,
    pub total_against: u256,
    pub total_abstain: u256,
}

#[derive(Drop, Serde)]
pub struct VoteBreakdown {
    pub votes_for: u256,
    pub votes_against: u256,
    pub votes_abstain: u256,
    pub total_voters: u64,
}

// Integration types for factory and revenue distribution
#[derive(Drop, Serde)]
pub struct TokenInfo {
    pub token_address: ContractAddress,
    pub artist_address: ContractAddress,
    pub total_supply: u256,
    pub name: felt252,
    pub symbol: felt252,
}

#[derive(Drop, Serde)]
pub struct GovernanceIntegration {
    pub factory_contract: ContractAddress,
    pub revenue_contract: ContractAddress,
    pub proposal_system: ContractAddress,
    pub voting_mechanism: ContractAddress,
}
