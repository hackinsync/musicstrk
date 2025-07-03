use starknet::ContractAddress;
use contract_::governance::types::{VoteType};
use crate::IRevenueDistribution::Category;

#[derive(Drop, starknet::Event)]
pub struct SeasonCreated {
    #[key]
    pub season_id: felt252,
    #[key]
    pub genre: felt252,
    pub name: felt252,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AuditionCreated {
    #[key]
    pub audition_id: felt252,
    pub season_id: felt252,
    #[key]
    pub genre: felt252,
    pub name: felt252,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AuditionPaused {
    #[key]
    pub audition_id: felt252,
    pub timestamp: u64
}

#[derive(Drop, starknet::Event)]
pub struct AuditionResumed {
    #[key]
    pub audition_id: felt252,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AuditionEnded {
    #[key]
    pub audition_id: felt252,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ResultsSubmitted {
    #[key]
    pub audition_id: felt252,
    pub top_performers: felt252,
    pub shares: felt252,
    pub timestamp: u64,
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
    pub audition_id: felt252,
    pub performer: felt252,
    pub voter: felt252,
    pub weight: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct PausedAll {
    pub timestamp: u64
}

#[derive(Drop, starknet::Event)]
pub struct ResumedAll {
    pub timestamp: u64
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
    proposal_system: ContractAddress,
    voting_mechanism: ContractAddress,
    factory_contract: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ProposalSubmitted {
    #[key]
    proposal_id: u64,
    token_contract: ContractAddress,
    proposer: ContractAddress,
    category: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct VoteCast {
    #[key]
    proposal_id: u64,
    voter: ContractAddress,
    vote_type: VoteType,
    weight: u256,
}

#[derive(Drop, starknet::Event)]
pub struct VoteDelegated {
    #[key]
    pub delegator: ContractAddress,
    #[key]
    pub delegate: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ArtistResponse {
    #[key]
    proposal_id: u64,
    #[key]
    artist: ContractAddress,
    status: u8,
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
pub struct ThresholdUpdated {
    pub new_threshold: u8,
    pub timestamp: u64
}

#[derive(Drop, starknet::Event)]
pub struct ArtistRegistered {
    #[key]
    pub artist: ContractAddress,
    pub token: ContractAddress
}

#[derive(Drop, starknet::Event)]
pub struct TokenShareTransferred {
    #[key]
    pub new_holder: ContractAddress,
    pub amount: u256
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
    pub timestamp: u64
}

pub mod EventCategories {
    use super::{RoleGranted, RoleRevoked, SeasonCreated, PausedAll, ResumedAll, AuditionCreated, AuditionPaused, AuditionResumed, 
        AuditionEnded, ResultsSubmitted, OracleAdded, OracleRemoved, TokenDeployedEvent, TokenInitializedEvent, BurnEvent, TokenShareTransferred,
        GovernanceInitialized, ProposalCreated, ProposalStatusChanged, ProposalSubmitted, ThresholdUpdated, ArtistResponse, CommentAdded,
        VoteCast, VoteDelegated, VoteRecorded, RevenueAddedEvent, RevenueDistributedEvent
    };

    pub enum AccessControlEvents {
        RoleGranted: RoleGranted,
        RoleRevoked: RoleRevoked,
    }

    pub enum SeasonEvents {
        SeasonCreated: SeasonCreated,
        PausedAll: PausedAll,
        ResumedAll: ResumedAll,
    }

    pub enum AuditionEvents {
        AuditionCreated: AuditionCreated,
        AuditionPaused: AuditionPaused,
        AuditionResumed: AuditionResumed,
        AuditionEnded: AuditionEnded,
        ResultsSubmitted: ResultsSubmitted
    }

    pub enum OracleEvents {
        OracleAdded: OracleAdded,
        OracleRemoved: OracleRemoved,
    }

    pub enum TokenEvents {
        TokenDeployedEvent: TokenDeployedEvent,
        TokenInitializedEvent: TokenInitializedEvent,
        BurnEvent: BurnEvent,
        TokenShareTransferred: TokenShareTransferred,
    }

    pub enum VotingEvents {
        GovernanceInitialized: GovernanceInitialized,
        ProposalCreated: ProposalCreated,
        ProposalStatusChanged: ProposalStatusChanged,
        ProposalSubmitted: ProposalSubmitted,
        ThresholdUpdated: ThresholdUpdated,
        ArtistResponse: ArtistResponse,
        CommentAdded: CommentAdded,
        VoteCast: VoteCast,
        VoteDelegated: VoteDelegated,
        VoteRecorded: VoteRecorded,

    }

    pub enum PaymentEvents {
        RevenueAddedEvent: RevenueAddedEvent,
        RevenueDistributedEvent: RevenueDistributedEvent  
    }
}

pub mod Categories {
    pub const ACCESSCONTROLEVENTS: felt252 = selector!("ACCESSCONTROLEVENTS");
    pub const SEASONEVENTS: felt252 = selector!("SEASONEVENTS");
    pub const AUDITIONEVENTS: felt252 = selector!("AUDITIONEVENTS");
    pub const ORACLEEVENTS: felt252 = selector!("ORACLEEVENTS");
    pub const TOKENEVENTS: felt252 = selector!("TOKENEVENTS");
    pub const VOTINGEVENTS: felt252 = selector!("VOTINGEVENTS");
    pub const PAYMENTEVENTS: felt252 = selector!("PAYMENTEVENTS");
}

#[starknet::interface]
pub trait IEventAggregator<TContractState> {
    fn record_event(ref self: TContractState, category: felt252);
    fn aggregate_events(ref self: TContractState);
    fn set_aggregation_threshold(ref self: TContractState, new_threshold: u128);
    fn get_aggregation_theshold(self: @TContractState) -> u128;
    fn get_events_count(self: @TContractState, category: felt252) -> u128;
    fn should_aggregate(self: @TContractState, category: felt252) -> bool;
}

#[starknet::component]
pub mod EventAggregator {
    use starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,};
    use super::{IEventAggregator, Categories};
    use starknet::{ContractAddress, get_block_timestamp};

    #[storage]
    pub struct Storage {
        events_count: Map::<felt252, u128>,
        last_aggregation: u64, //timestamp
        aggregation_threshold: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AggregatedEventsSummary: AggregatedEventsSummary,   
    }

    #[derive(Drop, starknet::Event)]
    pub struct AggregatedEventsSummary {
        #[key]
        pub time_period_start: u64,
        #[key]
        pub time_period_end: u64,
        #[key]
        pub category: felt252,
        pub total_count: u128,
    }

    #[embeddable_as(EventAggregator)]
    pub impl EventAggregatorImpl<
        TContractState,
        +HasComponent<TContractState>
        // +Drop<TContractState>,
    > of IEventAggregator<ComponentState<TContractState>>{
        fn record_event(ref self: ComponentState<TContractState>, category: felt252) {
            let current_count = self.events_count.entry(category).read();
            self.events_count.entry(category).write(current_count + 1);
        }
        fn aggregate_events(ref self: ComponentState<TContractState>) {
            let start_time = self.last_aggregation.read();
            let categories = array![
                Categories::ACCESSCONTROLEVENTS,
                Categories::AUDITIONEVENTS, 
                Categories::ORACLEEVENTS,
                Categories::PAYMENTEVENTS,
                Categories::SEASONEVENTS,
                Categories::TOKENEVENTS,
                Categories::VOTINGEVENTS
            ];

            for i in 0..(categories.len() - 1) {
                let category_count = self.events_count.entry(*categories.at(i)).read();
                if category_count > 0 {
                    self.emit(
                        AggregatedEventsSummary {
                            time_period_start: start_time,
                            time_period_end: get_block_timestamp(),
                            category: *categories.at(i),
                            total_count: category_count
                        }
                    );
                }
            };

            self.last_aggregation.write(get_block_timestamp());
        }
        fn should_aggregate(self: @ComponentState<TContractState>, category: felt252) -> bool {
            let events_count = self.events_count.entry(category).read();
            
            events_count >= self.aggregation_threshold.read()
        }
        fn set_aggregation_threshold(ref self: ComponentState<TContractState>, new_threshold: u128) {
            self.aggregation_threshold.write(new_threshold);
        }
        fn get_aggregation_theshold(self: @ComponentState<TContractState>) -> u128 {
            self.aggregation_threshold.read()
        }
        fn get_events_count(self: @ComponentState<TContractState>, category: felt252) -> u128 {
            self.events_count.entry(category).read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn _initialize(ref self: ComponentState<TContractState>, aggregation_threshold: u128) {
            self.aggregation_threshold.write(aggregation_threshold);
            self.last_aggregation.write(get_block_timestamp());
        }
    }
}