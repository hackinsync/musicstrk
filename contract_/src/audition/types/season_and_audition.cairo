use core::num::traits::Zero;
use starknet::ContractAddress;

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Season {
    pub season_id: u256,
    pub name: felt252,
    pub start_timestamp: u64,
    pub end_timestamp: u64,
    pub last_updated_timestamp: u64,
    pub paused: bool,
    pub ended: bool,
}

#[derive(Drop, Serde, Default, starknet::Store, Copy)]
pub struct Audition {
    pub audition_id: u256,
    pub season_id: u256,
    pub name: felt252,
    pub genre: Genre,
    pub start_timestamp: u64,
    pub end_timestamp: u64,
    pub paused: bool,
}

#[derive(Drop, Serde, starknet::Store, Copy, Clone, PartialEq, Default)]
pub enum Genre {
    #[default]
    Generic,
    Pop,
    Rock,
    Jazz,
    Classical,
    HipHop,
    Electronic,
    Country,
    AfroHouse,
    RnB,
    Reggae,
    Other,
}


#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Vote {
    pub audition_id: u256,
    pub performer: ContractAddress,
    pub voter: ContractAddress,
    pub weight: felt252,
}

#[derive(Drop, Serde, starknet::Store, PartialEq, Clone, Copy)]
#[allow(starknet::store_no_default_variant)]
pub enum VoteType {
    Judge,
    Staker,
}

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct UnifiedVote {
    pub voter: ContractAddress,
    pub artist_id: u256,
    pub audition_id: u256,
    pub weight: u256,
    pub vote_type: VoteType,
    pub ipfs_content_hash: felt252,
    pub timestamp: u64,
}

#[derive(Drop, Serde, Default, starknet::Store, Copy)]
pub struct VotingConfig {
    pub voting_start_time: u64,
    pub voting_end_time: u64,
    pub staker_base_weight: u256,
    pub judge_base_weight: u256,
    pub celebrity_weight_multiplier: u256,
}

#[derive(Drop, Serde, Default, starknet::Store, Copy)]
pub struct ArtistScore {
    pub artist_id: u256,
    pub total_score: u256,
    pub judge_votes: u32,
    pub staker_votes: u32,
    pub last_updated: u64,
}

/// @notice Evaluation struct for storing performer evaluations
/// @param audition_id The ID of the audition being evaluated
/// @param performer The address of the performer being evaluated
/// @param voter The address of the voter submitting the evaluation
/// @param weight The weight of each evaluation (e.g. (40%, 30%, 30%))
/// @param criteria A tuple containing technical skills, creativity, and presentation scores
#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Evaluation {
    pub audition_id: u256,
    pub performer: ContractAddress,
    pub criteria: (u256, u256, u256),
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Appeal {
    pub evaluation_id: u256,
    pub appellant: ContractAddress,
    pub reason: felt252,
    pub resolved: bool,
    pub resolution_comment: felt252,
}

impl DefaultVoteType of Default<VoteType> {
    fn default() -> VoteType {
        VoteType::Staker
    }
}

// Implement default for contract address type
impl DefaultImpl of Default<ContractAddress> {
    fn default() -> ContractAddress {
        Zero::zero()
    }
}
