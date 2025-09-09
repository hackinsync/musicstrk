use contract_::governance::types::VoteType;
use starknet::ContractAddress;
use crate::IRevenueDistribution::Category;
use crate::audition::types::season_and_audition::Genre;

#[derive(Drop, starknet::Event)]
pub struct SeasonCreated {
    #[key]
    pub season_id: u256,
    pub name: felt252,
    pub start_timestamp: u64,
    pub end_timestamp: u64,
    pub last_updated_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SeasonUpdated {
    #[key]
    pub season_id: u256,
    pub last_updated_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SeasonDeleted {
    #[key]
    pub season_id: felt252,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AuditionCreated {
    #[key]
    pub audition_id: u256,
    pub season_id: u256,
    pub name: felt252,
    pub genre: Genre,
    pub end_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AuditionUpdated {
    #[key]
    pub audition_id: u256,
    pub end_timestamp: u64,
    pub name: felt252,
    pub genre: Genre,
}

#[derive(Drop, starknet::Event)]
pub struct AuditionDeleted {
    #[key]
    pub audition_id: u256,
    pub end_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AuditionPaused {
    #[key]
    pub audition_id: u256,
    pub end_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AuditionResumed {
    #[key]
    pub audition_id: u256,
    pub end_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AuditionEnded {
    #[key]
    pub audition_id: u256,
    pub end_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ResultsSubmitted {
    #[key]
    pub audition_id: u256,
    pub top_performers: ContractAddress,
    pub shares: felt252,
    pub end_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct OracleAdded {
    pub oracle_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct OracleRemoved {
    pub oracle_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct VoteRecorded {
    #[key]
    pub audition_id: u256,
    pub performer: ContractAddress,
    pub voter: ContractAddress,
    pub weight: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct PriceDistributed {
    pub audition_id: u256,
    pub winners: [ContractAddress; 3],
    pub shares: [u256; 3],
    pub token_address: ContractAddress,
    pub amounts: Span<u256>,
}

#[derive(Drop, starknet::Event)]
pub struct PriceDeposited {
    pub audition_id: u256,
    pub token_address: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct PausedAll {
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ResumedAll {
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct TokenDeployedEvent {
    #[key]
    pub deployer: ContractAddress,
    #[key]
    pub token_address: ContractAddress,
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub metadata_uri: ByteArray,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct GovernanceInitialized {
    pub proposal_system: ContractAddress,
    pub voting_mechanism: ContractAddress,
    pub factory_contract: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ProposalSubmitted {
    #[key]
    pub proposal_id: u64,
    pub token_contract: ContractAddress,
    pub proposer: ContractAddress,
    pub category: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct VoteCast {
    #[key]
    pub proposal_id: u64,
    pub voter: ContractAddress,
    pub vote_type: VoteType,
    pub weight: u256,
}

#[derive(Drop, starknet::Event)]
pub struct VoteDelegated {
    #[key]
    pub delegator: ContractAddress,
    #[key]
    pub delegate: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ProposalCreated {
    #[key]
    pub proposal_id: u64,
    #[key]
    pub token_contract: ContractAddress,
    pub proposer: ContractAddress,
    pub category: felt252,
    pub title: ByteArray,
}

#[derive(Drop, starknet::Event)]
pub struct ProposalStatusChanged {
    #[key]
    pub proposal_id: u64,
    pub old_status: u8,
    pub new_status: u8,
    pub responder: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct CommentAdded {
    #[key]
    pub proposal_id: u64,
    pub comment_id: u64,
    pub commenter: ContractAddress,
}

#[derive(Drop, starknet::Event)] // added
pub struct TokenInitializedEvent {
    #[key]
    pub recipient: ContractAddress,
    pub amount: u256,
    pub metadata_uri: ByteArray,
}

#[derive(Drop, starknet::Event)] // added
pub struct BurnEvent {
    #[key]
    pub from: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct RevenueAddedEvent { // added
    #[key]
    pub category: Category,
    pub amount: u256,
    pub time: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RevenueDistributedEvent { //added
    #[key]
    pub total_distributed: u256,
    pub time: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ArtistRegistered {
    #[key]
    pub artist: ContractAddress,
    pub token: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TokenShareTransferred {
    #[key]
    pub new_holder: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct RoleGranted {
    #[key]
    pub artist: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RoleRevoked {
    #[key]
    pub artist: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct VoteChanged {
    #[key]
    pub proposal_id: u64,
    #[key]
    pub voter: ContractAddress,
    pub old_vote_type: VoteType,
    pub new_vote_type: VoteType,
    pub weight: u256,
}

#[derive(Drop, starknet::Event)]
pub struct VotingPeriodStarted {
    #[key]
    pub proposal_id: u64,
    pub end_timestamp: u64,
    pub duration_seconds: u64,
}

#[derive(Drop, starknet::Event)]
pub struct VotingPeriodEnded {
    #[key]
    pub proposal_id: u64,
    pub final_status: u8,
    pub votes_for: u256,
    pub votes_against: u256,
    pub votes_abstain: u256,
}

#[derive(Drop, starknet::Event)]
pub struct ProposalFinalized {
    #[key]
    pub proposal_id: u64,
    pub final_status: u8, // 1=Approved, 2=Rejected
    pub threshold_met: bool,
    pub total_votes_for: u256,
    pub required_threshold: u256,
}

#[derive(Drop, starknet::Event)]
pub struct TokenTransferDuringVoting {
    #[key]
    pub proposal_id: u64,
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub amount: u256,
    pub affected_weight: bool,
}

#[derive(Drop, starknet::Event)]
pub struct JudgeAdded {
    #[key]
    pub audition_id: u256,
    pub judge_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct JudgeRemoved {
    #[key]
    pub audition_id: u256,
    pub judge_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct EvaluationSubmitted {
    #[key]
    pub audition_id: u256,
    pub performer: ContractAddress,
    pub criteria: (u256, u256, u256),
}

#[derive(Drop, starknet::Event)]
pub struct EvaluationWeightSet {
    #[key]
    pub audition_id: u256,
    pub weight: (u256, u256, u256),
}

#[derive(Drop, starknet::Event)]
pub struct AuditionCalculationCompleted {
    #[key]
    pub audition_id: u256,
}

#[derive(Drop, starknet::Event)]
pub struct AggregateScoreCalculated {
    #[key]
    pub audition_id: u256,
    pub aggregate_scores: Array<(u256, u256)>,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AppealSubmitted {
    pub evaluation_id: u256,
    pub appellant: ContractAddress,
    pub reason: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct AppealResolved {
    pub evaluation_id: u256,
    pub resolver: ContractAddress,
    pub resolution_comment: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct SeasonPaused {
    #[key]
    pub season_id: u256,
    pub last_updated_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SeasonResumed {
    #[key]
    pub season_id: u256,
    pub last_updated_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SeasonEnded {
    #[key]
    pub season_id: u256,
    pub last_updated_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ResultSubmitted {
    #[key]
    pub audition_id: u256,
    pub result_uri: ByteArray,
    pub performer: ContractAddress,
}

// Stake withdrawal events
#[derive(Drop, starknet::Event)]
pub struct StakeWithdrawn {
    #[key]
    pub staker: ContractAddress,
    #[key]
    pub audition_id: u256,
    pub amount: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct BatchStakeWithdrawn {
    #[key]
    pub staker: ContractAddress,
    pub audition_ids: Array<u256>,
    pub total_amount: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct EmergencyStakeWithdrawn {
    #[key]
    pub staker: ContractAddress,
    #[key]
    pub audition_id: u256,
    pub amount: u256,
    pub admin: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct StakerInfoCleared {
    #[key]
    pub staker: ContractAddress,
    #[key]
    pub audition_id: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct WithdrawalFailed {
    #[key]
    pub staker: ContractAddress,
    #[key]
    pub audition_id: u256,
    pub reason: felt252,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ResultsFinalized {
    #[key]
    pub audition_id: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct StakingConfigUpdated {
    #[key]
    pub audition_id: u256,
    pub config: contract_::audition::types::stake_to_vote::StakingConfig,
    pub timestamp: u64,
}

// Unified voting system events
#[derive(Drop, starknet::Event)]
pub struct UnifiedVoteCast {
    #[key]
    pub audition_id: u256,
    #[key]
    pub artist_id: u256,
    #[key]
    pub voter: ContractAddress,
    pub weight: u256,
    pub vote_type: contract_::audition::types::season_and_audition::VoteType,
    pub ipfs_content_hash: felt252,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct VotingConfigSet {
    #[key]
    pub audition_id: u256,
    pub voting_start_time: u64,
    pub voting_end_time: u64,
    pub staker_base_weight: u256,
    pub judge_base_weight: u256,
    pub celebrity_weight_multiplier: u256,
}

#[derive(Drop, starknet::Event)]
pub struct ArtistScoreUpdated {
    #[key]
    pub audition_id: u256,
    #[key]
    pub artist_id: u256,
    pub total_score: u256,
    pub judge_votes: u32,
    pub staker_votes: u32,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct CelebrityJudgeSet {
    #[key]
    pub audition_id: u256,
    #[key]
    pub celebrity_judge: ContractAddress,
    pub weight_multiplier: u256,
    pub timestamp: u64,
}
