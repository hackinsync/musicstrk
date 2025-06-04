use starknet::ContractAddress;

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Season {
    pub season_id: felt252,
    pub genre: felt252,
    pub name: felt252,
    pub start_timestamp: felt252,
    pub end_timestamp: felt252,
    pub paused: bool,
}

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Audition {
    pub audition_id: felt252,
    pub season_id: felt252,
    pub genre: felt252,
    pub name: felt252,
    pub start_timestamp: felt252,
    pub end_timestamp: felt252,
    pub paused: bool,
}

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Vote {
    pub audition_id: felt252,
    pub performer: felt252,
    pub voter: felt252,
    pub weight: felt252,
}

// Define the contract interface
#[starknet::interface]
pub trait ISeasonAndAudition<TContractState> {
    fn create_season(
        ref self: TContractState,
        season_id: felt252,
        genre: felt252,
        name: felt252,
        start_timestamp: felt252,
        end_timestamp: felt252,
        paused: bool,
    );
    fn read_season(self: @TContractState, season_id: felt252) -> Season;
    fn update_season(ref self: TContractState, season_id: felt252, season: Season);
    fn delete_season(ref self: TContractState, season_id: felt252);

    fn create_audition(
        ref self: TContractState,
        audition_id: felt252,
        season_id: felt252,
        genre: felt252,
        name: felt252,
        start_timestamp: felt252,
        end_timestamp: felt252,
        paused: bool,
    );
    fn read_audition(self: @TContractState, audition_id: felt252) -> Audition;
    fn update_audition(ref self: TContractState, audition_id: felt252, audition: Audition);
    fn delete_audition(ref self: TContractState, audition_id: felt252);
    fn submit_results(
        ref self: TContractState, audition_id: felt252, top_performers: felt252, shares: felt252,
    );
    fn only_oracle(ref self: TContractState);
    fn add_oracle(ref self: TContractState, oracle_address: ContractAddress);
    fn remove_oracle(ref self: TContractState, oracle_address: ContractAddress);

    // Vote recording functionality
    fn record_vote(
        ref self: TContractState,
        audition_id: felt252,
        performer: felt252,
        voter: felt252,
        weight: felt252,
    );
    fn get_vote(
        self: @TContractState, audition_id: felt252, performer: felt252, voter: felt252,
    ) -> Vote;
}

#[starknet::contract]
pub mod SeasonAndAudition {
    use OwnableComponent::InternalTrait;
    use contract_::errors::errors;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use super::{Audition, ISeasonAndAudition, Season, Vote};

    // Integrates OpenZeppelin ownership component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        whitelisted_oracles: Map<ContractAddress, bool>,
        seasons: Map<felt252, Season>,
        auditions: Map<felt252, Audition>,
        votes: Map<(felt252, felt252, felt252), Vote>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SeasonCreated: SeasonCreated,
        AuditionCreated: AuditionCreated,
        ResultsSubmitted: ResultsSubmitted,
        OracleAdded: OracleAdded,
        OracleRemoved: OracleRemoved,
        VoteRecorded: VoteRecorded,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SeasonCreated {
        pub season_id: felt252,
        pub genre: felt252,
        pub name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuditionCreated {
        pub audition_id: felt252,
        pub season_id: felt252,
        pub genre: felt252,
        pub name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ResultsSubmitted {
        pub audition_id: felt252,
        pub top_performers: felt252,
        pub shares: felt252,
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
        pub audition_id: felt252,
        pub performer: felt252,
        pub voter: felt252,
        pub weight: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl ISeasonAndAuditionImpl of ISeasonAndAudition<ContractState> {
        fn create_season(
            ref self: ContractState,
            season_id: felt252,
            genre: felt252,
            name: felt252,
            start_timestamp: felt252,
            end_timestamp: felt252,
            paused: bool,
        ) {
            self.ownable.assert_only_owner();

            self
                .seasons
                .entry(season_id)
                .write(Season { season_id, genre, name, start_timestamp, end_timestamp, paused });

            self.emit(SeasonCreated { season_id, genre, name });
        }

        fn read_season(self: @ContractState, season_id: felt252) -> Season {
            self.ownable.assert_only_owner();

            self.seasons.entry(season_id).read()
        }

        fn update_season(ref self: ContractState, season_id: felt252, season: Season) {
            self.ownable.assert_only_owner();

            self.seasons.entry(season_id).write(season);
        }

        fn delete_season(ref self: ContractState, season_id: felt252) {
            self.ownable.assert_only_owner();

            let default_season: Season = Default::default();

            self.seasons.entry(season_id).write(default_season);
        }

        fn create_audition(
            ref self: ContractState,
            audition_id: felt252,
            season_id: felt252,
            genre: felt252,
            name: felt252,
            start_timestamp: felt252,
            end_timestamp: felt252,
            paused: bool,
        ) {
            self.ownable.assert_only_owner();

            self
                .auditions
                .entry(audition_id)
                .write(
                    Audition {
                        audition_id, season_id, genre, name, start_timestamp, end_timestamp, paused,
                    },
                );

            self.emit(AuditionCreated { audition_id, season_id, genre, name });
        }

        fn read_audition(self: @ContractState, audition_id: felt252) -> Audition {
            self.ownable.assert_only_owner();

            self.auditions.entry(audition_id).read()
        }

        fn update_audition(ref self: ContractState, audition_id: felt252, audition: Audition) {
            self.ownable.assert_only_owner();

            self.auditions.entry(audition_id).write(audition);
        }

        fn delete_audition(ref self: ContractState, audition_id: felt252) {
            self.ownable.assert_only_owner();

            let default_audition: Audition = Default::default();

            self.auditions.entry(audition_id).write(default_audition);
        }

        fn submit_results(
            ref self: ContractState, audition_id: felt252, top_performers: felt252, shares: felt252,
        ) {
            self.only_oracle();

            self
                .emit(
                    Event::ResultsSubmitted(
                        ResultsSubmitted { audition_id, top_performers, shares },
                    ),
                );
        }

        fn only_oracle(ref self: ContractState) {
            let caller = get_caller_address(); // Get the caller address
            let is_whitelisted = self.whitelisted_oracles.read(caller);
            // Check if caller is whitelisted
            assert(is_whitelisted, 'Not Authorized');
        }

        fn add_oracle(ref self: ContractState, oracle_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.whitelisted_oracles.write(oracle_address, true);
            self.emit(Event::OracleAdded(OracleAdded { oracle_address }));
        }

        fn remove_oracle(ref self: ContractState, oracle_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.whitelisted_oracles.write(oracle_address, false);
            self.emit(Event::OracleRemoved(OracleRemoved { oracle_address }));
        }

        fn record_vote(
            ref self: ContractState,
            audition_id: felt252,
            performer: felt252,
            voter: felt252,
            weight: felt252,
        ) {
            self.only_oracle();

            // Check if vote already exists (duplicate vote prevention)
            let vote_key = (audition_id, performer, voter);
            let existing_vote = self.votes.entry(vote_key).read();

            // If the vote has a non-zero audition_id, it means a vote already exists
            assert(existing_vote.audition_id == 0, errors::DUPLICATE_VOTE);

            self.votes.entry(vote_key).write(Vote { audition_id, performer, voter, weight });

            self.emit(Event::VoteRecorded(VoteRecorded { audition_id, performer, voter, weight }));
        }

        fn get_vote(
            self: @ContractState, audition_id: felt252, performer: felt252, voter: felt252,
        ) -> Vote {
            self.ownable.assert_only_owner();

            self.votes.entry((audition_id, performer, voter)).read()
        }
    }
}
