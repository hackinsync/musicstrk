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

#[derive(Drop, Serde, Default, Copy, starknet::Store)]
pub struct Audition {
    pub audition_id: u256,
    pub season_id: u256,
    pub name: felt252,
    pub genre: Genre,
    pub start_timestamp: u64,
    pub end_timestamp: u64,
    pub paused: bool,
}

#[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
pub struct RegistrationConfig {
    pub fee_amount: u256,
    pub fee_token: ContractAddress,
    pub registration_open: bool,
    pub max_participants: u32,
}

impl RegistrationConfigDefault of Default<RegistrationConfig> {
    /// @notice update default if necessary. Initializes with default
    /// values and first checks if RegistrationConfig is none
    /// This allows for additional flexibility.
    #[inline(always)]
    fn default() -> RegistrationConfig {
        RegistrationConfig {
            fee_amount: 100_000_000, // 100 usdc to it's 6 decimals
            // usdc on starknet mainnet.
            fee_token: 0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
                .try_into()
                .unwrap(),
            registration_open: false,
            max_participants: 25,
        }
    }
}

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct ArtistRegistration {
    pub wallet_address: ContractAddress,
    pub audition_id: u256,
    pub tiktok_id: felt252,
    pub tiktok_username: felt252, // Pre-verified off-chain
    pub email_hash: felt252, // Privacy hash
    pub registration_fee_paid: u256,
    pub registration_timestamp: u64,
    pub is_active: bool,
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
