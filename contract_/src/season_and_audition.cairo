#[derive(Copy, Drop, Serde, Default, PartialEq, starknet::Store)]
pub enum Genre {
    #[default]
    All,
    Pop,
    Rock,
    Electronic,
}

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Season {
    pub season_id: felt252,
    pub genre: Genre,
    pub price: felt252,
    pub start_timestamp: felt252,
    pub end_timestamp: felt252,
    pub paused: bool,
}

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Audition {
    pub audition_id: felt252,
    pub season_id: felt252,
    pub genre: Genre,
    pub price: felt252,
    pub start_timestamp: felt252,
    pub end_timestamp: felt252,
    pub paused: bool,
}

// Define the contract interface
#[starknet::interface]
pub trait ISeasonAndAudition<TContractState> {
    fn create_season(ref self: TContractState, season_id: felt252,genre: Genre, price: felt252, start_timestamp: felt252, end_timestamp: felt252, paused: bool);
    fn read_season(self: @TContractState, season_id: felt252) -> Season;
    fn update_season(ref self: TContractState, season_id: felt252, season: Season);
    fn delete_season(ref self: TContractState, season_id: felt252);

    fn create_audition(ref self: TContractState, audition_id: felt252,season_id: felt252, genre: Genre, price: felt252, start_timestamp: felt252, end_timestamp: felt252, paused: bool);
    fn read_audition(self: @TContractState, audition_id: felt252) -> Audition;
    fn update_audition(ref self: TContractState, audition_id: felt252, audition: Audition);
    fn delete_audition(ref self: TContractState, audition_id: felt252);
}

#[starknet::contract]
pub mod SeasonAndAudition {
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{ISeasonAndAudition, Season, Audition, Genre};
    use OwnableComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;

    // Integrates OpenZeppelin ownership component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        seasons: Map<felt252, Season>,
        auditions: Map<felt252, Audition>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SeasonCreated: SeasonCreated,
        AuditionCreated: AuditionCreated,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SeasonCreated {
        pub season_id: felt252,
        pub genre: Genre,
        pub price: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuditionCreated {
        pub audition_id: felt252,
        pub season_id: felt252,
        pub genre: Genre,
        pub price: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl ISeasonAndAuditionImpl of ISeasonAndAudition<ContractState> {
        fn create_season(ref self: ContractState, season_id: felt252,genre: Genre, price: felt252, start_timestamp: felt252,end_timestamp: felt252, paused: bool) {
            self.ownable.assert_only_owner();

            self.seasons.entry(season_id).write(
                Season {
                    season_id,
                    genre,
                    price,
                    start_timestamp,
                    end_timestamp,
                    paused
                }
            );

            self.emit(SeasonCreated {
                season_id,
                genre,
                price
            });
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

        fn create_audition(ref self: ContractState, audition_id: felt252,season_id: felt252, genre: Genre, price: felt252, start_timestamp: felt252, end_timestamp: felt252, paused: bool) {
            self.ownable.assert_only_owner();

            self.auditions.entry(audition_id).write(
                Audition {
                    audition_id,
                    season_id,
                    genre,
                    price,
                    start_timestamp,
                    end_timestamp,
                    paused
                }
            );

            self.emit(AuditionCreated {
                audition_id,
                season_id,
                genre,
                price
            });
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
    }
}
