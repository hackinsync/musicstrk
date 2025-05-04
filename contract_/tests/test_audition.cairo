use contract_::audition::{IAuditionDispatcher, IAuditionDispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, spy_events,
};
use starknet::{ContractAddress, contract_address_const};

// Helper functions for test addresses
fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn organizer() -> ContractAddress {
    contract_address_const::<'organizer'>()
}

fn participant() -> ContractAddress {
    contract_address_const::<'participant'>()
}

fn non_organizer() -> ContractAddress {
    contract_address_const::<'non_organizer'>()
}

// Helper function to deploy the audition contract
fn deploy_audition_contract() -> ContractAddress {
    let owner_address = owner();
    let season_audition_address = contract_address_const::<'season_audition'>();
    let contract_class = declare("Audition").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(owner_address);
    calldata.append_serde(season_audition_address);
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

#[test]
fn test_create_audition() {
    let contract_address = deploy_audition_contract();
    let audition = IAuditionDispatcher { contract_address };
    
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    audition.initialize(organizer());
    
    let audition_id = 1;
    let season_id = 1;
    let genre = 1;
    let name = 1;
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.create_audition(audition_id, season_id, genre, name);
    
    let mut event_spy = spy_events();
    
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.pause_audition(audition_id);
    
    assert(audition.is_paused(audition_id), 'Audition should be paused');
    
    let events = event_spy.get_events();
    assert(events.len() > 0, 'No events emitted');
}

#[test]
fn test_pause_audition() {
    // Deploy and initialize the contract
    let contract_address = deploy_audition_contract();
    let audition = IAuditionDispatcher { contract_address };
    
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    audition.initialize(organizer());
    
    // Create an audition
    let audition_id = 1;
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.create_audition(audition_id);
    
    // Spy on events
    let mut event_spy = spy_events();
    
    // Pause the audition
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.pause_audition(audition_id);
    
    // Verify audition is paused
    assert(audition.is_paused(audition_id), 'Audition should be paused');
    
    // Verify event was emitted (simplified check)
    let events = event_spy.get_events();
    assert(events.len() > 0, 'No events emitted');
}

#[test]
fn test_resume_audition() {
    // Deploy and initialize the contract
    let contract_address = deploy_audition_contract();
    let audition = IAuditionDispatcher { contract_address };
    
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    audition.initialize(organizer());
    
    // Create an audition
    let audition_id = 1;
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.create_audition(audition_id);
    
    // Pause the audition
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.pause_audition(audition_id);
    
    // Spy on events
    let mut event_spy = spy_events();
    
    // Resume the audition
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.resume_audition(audition_id);
    
    // Verify audition is not paused
    assert(!audition.is_paused(audition_id), 'Audition should not be paused');
    
    // Verify event was emitted (simplified check)
    let events = event_spy.get_events();
    assert(events.len() > 0, 'No events emitted');
}

#[test]
fn test_end_audition() {
    // Deploy and initialize the contract
    let contract_address = deploy_audition_contract();
    let audition = IAuditionDispatcher { contract_address };
    
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    audition.initialize(organizer());
    
    // Create an audition
    let audition_id = 1;
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.create_audition(audition_id);
    
    // Spy on events
    let mut event_spy = spy_events();
    
    // End the audition
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.end_audition(audition_id);
    
    // Verify audition is ended
    assert(audition.is_ended(audition_id), 'Audition should be ended');
    
    // Verify event was emitted (simplified check)
    let events = event_spy.get_events();
    assert(events.len() > 0, 'No events emitted');
}

#[test]
#[should_panic(expected: 'Audition is paused')]
fn test_register_when_paused() {
    // Deploy and initialize the contract
    let contract_address = deploy_audition_contract();
    let audition = IAuditionDispatcher { contract_address };
    
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    audition.initialize(organizer());
    
    // Create an audition
    let audition_id = 1;
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.create_audition(audition_id);
    
    // Pause the audition
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.pause_audition(audition_id);
    
    // Try to register - should fail
    cheat_caller_address(contract_address, participant(), CheatSpan::TargetCalls(1));
    audition.register_for_audition(audition_id);
}

#[test]
#[should_panic(expected: 'Audition has ended')]
fn test_register_when_ended() {
    // Deploy and initialize the contract
    let contract_address = deploy_audition_contract();
    let audition = IAuditionDispatcher { contract_address };
    
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    audition.initialize(organizer());
    
    // Create an audition
    let audition_id = 1;
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.create_audition(audition_id);
    
    // End the audition
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.end_audition(audition_id);
    
    // Try to register - should fail
    cheat_caller_address(contract_address, participant(), CheatSpan::TargetCalls(1));
    audition.register_for_audition(audition_id);
}

#[test]
#[should_panic(expected: 'Audition is paused')]
fn test_vote_when_paused() {
    // Deploy and initialize the contract
    let contract_address = deploy_audition_contract();
    let audition = IAuditionDispatcher { contract_address };
    
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    audition.initialize(organizer());
    
    // Create an audition
    let audition_id = 1;
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.create_audition(audition_id);
    
    // Pause the audition
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.pause_audition(audition_id);
    
    // Try to vote - should fail
    cheat_caller_address(contract_address, participant(), CheatSpan::TargetCalls(1));
    audition.vote_for_audition(audition_id, participant());
}

#[test]
#[should_panic(expected: 'Audition has ended')]
fn test_vote_when_ended() {
    // Deploy and initialize the contract
    let contract_address = deploy_audition_contract();
    let audition = IAuditionDispatcher { contract_address };
    
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    audition.initialize(organizer());
    
    // Create an audition
    let audition_id = 1;
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.create_audition(audition_id);
    
    // End the audition
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.end_audition(audition_id);
    
    // Try to vote - should fail
    cheat_caller_address(contract_address, participant(), CheatSpan::TargetCalls(1));
    audition.vote_for_audition(audition_id, participant());
}

#[test]
#[should_panic(expected: 'Only organizer can pause')]
fn test_unauthorized_pause() {
    // Deploy and initialize the contract
    let contract_address = deploy_audition_contract();
    let audition = IAuditionDispatcher { contract_address };
    
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    audition.initialize(organizer());
    
    // Create an audition
    let audition_id = 1;
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.create_audition(audition_id);
    
    // Try to pause as non-organizer - should fail
    cheat_caller_address(contract_address, non_organizer(), CheatSpan::TargetCalls(1));
    audition.pause_audition(audition_id);
}

#[test]
#[should_panic(expected: 'Only organizer can resume')]
fn test_unauthorized_resume() {
    // Deploy and initialize the contract
    let contract_address = deploy_audition_contract();
    let audition = IAuditionDispatcher { contract_address };
    
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    audition.initialize(organizer());
    
    // Create an audition
    let audition_id = 1;
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.create_audition(audition_id);
    
    // Pause the audition
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.pause_audition(audition_id);
    
    // Try to resume as non-organizer - should fail
    cheat_caller_address(contract_address, non_organizer(), CheatSpan::TargetCalls(1));
    audition.resume_audition(audition_id);
}

#[test]
#[should_panic(expected: 'Only organizer can end')]
fn test_unauthorized_end() {
    // Deploy and initialize the contract
    let contract_address = deploy_audition_contract();
    let audition = IAuditionDispatcher { contract_address };
    
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    audition.initialize(organizer());
    
    // Create an audition
    let audition_id = 1;
    cheat_caller_address(contract_address, organizer(), CheatSpan::TargetCalls(1));
    audition.create_audition(audition_id);
    
    // Try to end as non-organizer - should fail
    cheat_caller_address(contract_address, non_organizer(), CheatSpan::TargetCalls(1));
    audition.end_audition(audition_id);
}