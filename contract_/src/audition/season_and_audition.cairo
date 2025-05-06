#[starknet::contract]
pub mod SeasonAndAudition {
    use OwnableComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::{Audition, IAudition, ISeasonAndAudition, Season};

    // Integrates OpenZeppelin ownership component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[derive(Drop, starknet::Store)]
    struct AuditionData {
        paused: bool,
        ended: bool,
        start_timestamp: u64,
        end_timestamp: u64,
    }

    #[storage]
    struct Storage {
        owner: ContractAddress,
        organizer: ContractAddress,
        initialized: bool,
        seasons: Map<felt252, Season>,
        auditions: Map<felt252, Audition>,
        audition_data: Map<felt252, AuditionData>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SeasonCreated: SeasonCreated,
        AuditionCreated: AuditionCreated,
        AuditionPaused: AuditionPaused,
        AuditionResumed: AuditionResumed,
        AuditionEnded: AuditionEnded,
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
    pub struct AuditionPaused {
        pub audition_id: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuditionResumed {
        pub audition_id: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuditionEnded {
        pub audition_id: felt252,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.organizer.write(owner);
        self.initialized.write(true);
    }

    #[abi(embed_v0)]
    impl AuditionImpl of super::IAudition<ContractState> {
        fn initialize(ref self: ContractState, organizer: ContractAddress) {
            assert(!self.initialized.read(), 'Already initialized');
            self.organizer.write(organizer);
            self.initialized.write(true);
            self.ownable.OwnableComponent::transfer_ownership(organizer);
        }

        fn create_audition(
            ref self: ContractState,
            audition_id: felt252,
            season_id: felt252,
            genre: felt252,
            name: felt252,
        ) -> felt252 {
            assert(get_caller_address() == self.organizer.read(), 'Only organizer can create');

            let current_time = get_block_timestamp();
            self
                .auditions
                .entry(audition_id)
                .write(
                    Audition {
                        audition_id,
                        season_id,
                        genre,
                        name,
                        start_timestamp: current_time,
                        end_timestamp: 0, // end_timestamp will be set when ended
                        paused: false // not paused initially
                    },
                );

            self
                .audition_data
                .entry(audition_id)
                .write(
                    AuditionData {
                        paused: false,
                        ended: false,
                        start_timestamp: current_time,
                        end_timestamp: 0,
                    },
                );

            self
                .emit(
                    Event::AuditionCreated(AuditionCreated { audition_id, season_id, genre, name }),
                );

            audition_id
        }

        fn pause_audition(ref self: ContractState, audition_id: felt252) {
            assert(get_caller_address() == self.organizer.read(), 'Only organizer can pause');

            let mut data = self.audition_data.entry(audition_id).read();
            assert(!data.ended, 'Audition has ended');

            // Create a new AuditionData with updated values
            let updated_data = AuditionData {
                paused: true,
                ended: data.ended,
                start_timestamp: data.start_timestamp,
                end_timestamp: data.end_timestamp,
            };

            // Write the updated data
            self.audition_data.entry(audition_id).write(updated_data);

            let current_time = get_block_timestamp();
            self
                .emit(
                    Event::AuditionPaused(AuditionPaused { audition_id, timestamp: current_time }),
                );
        }

        fn resume_audition(ref self: ContractState, audition_id: felt252) {
            assert(get_caller_address() == self.organizer.read(), 'Only organizer can resume');

            let mut audition = self.read_audition(audition_id);
            let mut data = self.audition_data.entry(audition_id).read();
            assert(!data.ended, 'Audition already ended');
            assert(data.paused, 'Audition not paused');

            audition.paused = false;
            data.paused = false;
            self.update_audition(audition_id, audition);
            self.audition_data.entry(audition_id).write(data);

            self
                .emit(
                    Event::AuditionResumed(
                        AuditionResumed { audition_id, timestamp: get_block_timestamp() },
                    ),
                );
        }

        fn end_audition(ref self: ContractState, audition_id: felt252) {
            assert(get_caller_address() == self.organizer.read(), 'Only organizer can end');

            let mut audition = self.read_audition(audition_id);
            let mut data = self.audition_data.entry(audition_id).read();
            assert(!data.ended, 'Audition already ended');

            let current_time = get_block_timestamp();
            audition.end_timestamp = current_time;
            data.ended = true;
            data.end_timestamp = current_time;
            self.update_audition(audition_id, audition);
            self.audition_data.entry(audition_id).write(data);

            self.emit(Event::AuditionEnded(AuditionEnded { audition_id, timestamp: current_time }));
        }

        fn register_for_audition(ref self: ContractState, audition_id: felt252) {
            let data = self.audition_data.entry(audition_id).read();
            assert(!data.paused, 'Audition is paused');
            assert(!data.ended, 'Audition has ended');
            // Registration logic would go here
        }

        fn vote_for_audition(
            ref self: ContractState, audition_id: felt252, participant: ContractAddress,
        ) {
            let data = self.audition_data.entry(audition_id).read();
            assert(!data.paused, 'Audition is paused');
            assert(!data.ended, 'Audition has ended');
            // Voting logic would go here
        }

        fn is_paused(self: @ContractState, audition_id: felt252) -> bool {
            self.audition_data.entry(audition_id).read().paused
        }

        fn is_ended(self: @ContractState, audition_id: felt252) -> bool {
            self.audition_data.entry(audition_id).read().ended
        }

        fn get_organizer(self: @ContractState) -> ContractAddress {
            self.organizer.read()
        }
    }

    #[abi(embed_v0)]
    impl SeasonAndAuditionImpl of super::ISeasonAndAudition<ContractState> {
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
    }
}
