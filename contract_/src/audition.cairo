use starknet::ContractAddress;
use starknet::{get_caller_address, get_block_timestamp};

#[starknet::interface]
trait IAudition<TContractState> {
    fn initialize(ref self: TContractState, organizer: ContractAddress);
    fn create_audition(ref self: TContractState, audition_id: felt252) -> felt252;
    fn pause_audition(ref self: TContractState, audition_id: felt252);
    fn resume_audition(ref self: TContractState, audition_id: felt252);
    fn end_audition(ref self: TContractState, audition_id: felt252);
    fn register_for_audition(ref self: TContractState, audition_id: felt252);
    fn vote_for_audition(ref self: TContractState, audition_id: felt252, participant: ContractAddress);
    fn is_paused(self: @TContractState, audition_id: felt252) -> bool;
    fn is_ended(self: @TContractState, audition_id: felt252) -> bool;
    fn get_organizer(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod Audition {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AuditionCreated: AuditionCreated,
        AuditionPaused: AuditionPaused,
        AuditionResumed: AuditionResumed,
        AuditionEnded: AuditionEnded,
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct AuditionCreated {
        audition_id: felt252,
        organizer: ContractAddress,
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct AuditionPaused {
        audition_id: felt252,
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct AuditionResumed {
        audition_id: felt252,
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct AuditionEnded {
        audition_id: felt252,
        timestamp: u64
    }

    #[derive(Drop, starknet::Store)]
    struct AuditionData {
        paused: bool,
        ended: bool,
        start_timestamp: u64,
        end_timestamp: u64
    }

    #[storage]
    struct Storage {
        organizer: ContractAddress,
        initialized: bool,
        auditions: LegacyMap<felt252, AuditionData>,
        #[substorage(v0)]
        ownable_component: OwnableComponent::Storage
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable_component.initializer(owner);
    }

    #[external(v0)]
    impl AuditionImpl of super::IAudition<ContractState> {
        fn initialize(ref self: ContractState, organizer: ContractAddress) {
            // Ensure contract is not already initialized
            assert(!self.initialized.read(), 'Already initialized');
            
            // Set the organizer
            self.organizer.write(organizer);
            self.initialized.write(true);
            
            // Transfer ownership to the organizer
            self.ownable_component.transfer_ownership(organizer);
        }

        fn create_audition(ref self: ContractState, audition_id: felt252) -> felt252 {
            // Only organizer can create auditions
            assert(get_caller_address() == self.organizer.read(), 'Only organizer can create');
            
            // Ensure audition doesn't already exist
            assert(!self.auditions.read(audition_id).paused, 'Audition already exists');
            assert(!self.auditions.read(audition_id).ended, 'Audition already exists');
            
            // Create new audition
            let current_time = get_block_timestamp();
            let audition_data = AuditionData {
                paused: false,
                ended: false,
                start_timestamp: current_time,
                end_timestamp: 0
            };
            
            self.auditions.write(audition_id, audition_data);
            
            // Emit event
            self.emit(Event::AuditionCreated(AuditionCreated {
                audition_id,
                organizer: self.organizer.read(),
                timestamp: current_time
            }));
            
            audition_id
        }

        fn pause_audition(ref self: ContractState, audition_id: felt252) {
            // Only organizer can pause auditions
            assert(get_caller_address() == self.organizer.read(), 'Only organizer can pause');
            
            // Get current audition data
            let mut audition_data = self.auditions.read(audition_id);
            
            // Ensure audition exists and is not ended
            assert(!audition_data.ended, 'Audition already ended');
            
            // Ensure audition is not already paused
            assert(!audition_data.paused, 'Audition already paused');
            
            // Update audition state
            audition_data.paused = true;
            self.auditions.write(audition_id, audition_data);
            
            // Emit event
            self.emit(Event::AuditionPaused(AuditionPaused {
                audition_id,
                timestamp: get_block_timestamp()
            }));
        }

        fn resume_audition(ref self: ContractState, audition_id: felt252) {
            // Only organizer can resume auditions
            assert(get_caller_address() == self.organizer.read(), 'Only organizer can resume');
            
            // Get current audition data
            let mut audition_data = self.auditions.read(audition_id);
            
            // Ensure audition exists and is not ended
            assert(!audition_data.ended, 'Audition already ended');
            
            // Ensure audition is paused
            assert(audition_data.paused, 'Audition not paused');
            
            // Update audition state
            audition_data.paused = false;
            self.auditions.write(audition_id, audition_data);
            
            // Emit event
            self.emit(Event::AuditionResumed(AuditionResumed {
                audition_id,
                timestamp: get_block_timestamp()
            }));
        }

        fn end_audition(ref self: ContractState, audition_id: felt252) {
            // Only organizer can end auditions
            assert(get_caller_address() == self.organizer.read(), 'Only organizer can end');
            
            // Get current audition data
            let mut audition_data = self.auditions.read(audition_id);
            
            // Ensure audition exists and is not already ended
            assert(!audition_data.ended, 'Audition already ended');
            
            // Update audition state
            let current_time = get_block_timestamp();
            audition_data.ended = true;
            audition_data.end_timestamp = current_time;
            self.auditions.write(audition_id, audition_data);
            
            // Emit event
            self.emit(Event::AuditionEnded(AuditionEnded {
                audition_id,
                timestamp: current_time
            }));
        }

        fn register_for_audition(ref self: ContractState, audition_id: felt252) {
            // Get current audition data
            let audition_data = self.auditions.read(audition_id);
            
            // Ensure audition is not paused or ended
            assert(!audition_data.paused, 'Audition is paused');
            assert(!audition_data.ended, 'Audition has ended');
            
            // Registration logic would go here
            // For now, just validate the state
        }

        fn vote_for_audition(ref self: ContractState, audition_id: felt252, participant: ContractAddress) {
            // Get current audition data
            let audition_data = self.auditions.read(audition_id);
            
            // Ensure audition is not paused or ended
            assert(!audition_data.paused, 'Audition is paused');
            assert(!audition_data.ended, 'Audition has ended');
            
            // Voting logic would go here
            // For now, just validate the state
        }

        fn is_paused(self: @ContractState, audition_id: felt252) -> bool {
            self.auditions.read(audition_id).paused
        }

        fn is_ended(self: @ContractState, audition_id: felt252) -> bool {
            self.auditions.read(audition_id).ended
        }

        fn get_organizer(self: @ContractState) -> ContractAddress {
            self.organizer.read()
        }
    }
}