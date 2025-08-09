use contract_::audition::session_and_audition::{
    Audition, ISessionAndAuditionDispatcher, ISessionAndAuditionDispatcherTrait, Session,
    SessionAndAudition,
};
use contract_::events::{PausedAll, ResumedAll};
use core::result::ResultTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, get_block_timestamp};

// Test account addresses
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn USER() -> ContractAddress {
    'USER'.try_into().unwrap()
}

fn ORACLE() -> ContractAddress {
    'ORACLE'.try_into().unwrap()
}

fn NON_ORACLE() -> ContractAddress {
    'NON_ORACLE'.try_into().unwrap()
}

// Helper function to deploy the contract
fn deploy_contract() -> ISessionAndAuditionDispatcher {
    // declare the contract
    let contract_class = declare("SessionAndAudition")
        .expect('Failed to declare contract')
        .contract_class();

    // serialize constructor
    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);

    // deploy the contract
    let (contract_address, _) = contract_class
        .deploy(@calldata)
        .expect('Failed to deploy contract');

    let contract_dispatcher = ISessionAndAuditionDispatcher { contract_address };

    contract_dispatcher
}

// Helper function to create test season data
fn create_test_season(session_id: felt252) -> Session {
    Session {
        session_id,
        genre: 'Pop',
        name: 'Summer Hits',
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: false,
        ended: false,
    }
}

// Helper function to create test audition data
fn create_test_audition(audition_id: felt252, session_id: felt252) -> Audition {
    Audition {
        audition_id,
        session_id,
        genre: 'Afro House',
        name: 'Deep Cuts',
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: false,
    }
}

#[test]
fn test_owner_access_control() {
    let dispatcher = deploy_contract();

    // Test owner functions
    start_cheat_caller_address(dispatcher.contract_address, OWNER());

    // Owner can create a season
    let season_id = 1;
    let test_season = create_test_season(season_id);
    dispatcher.create_season(test_season.genre, test_season.name, test_season.end_timestamp);

    // Owner can create an audition
    let audition_id = 1;
    let test_audition = create_test_audition(audition_id, session_id);
    dispatcher
        .create_audition(
            season_id, test_audition.genre, test_audition.name, test_audition.end_timestamp,
        );

    // Owner can add oracles
    dispatcher.add_oracle(ORACLE());

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_non_owner_cannot_create_season() {
    let dispatcher = deploy_contract();

    // Non-owner tries to create a season
    start_cheat_caller_address(dispatcher.contract_address, USER());

    let season_id = 1;
    let test_season = create_test_season(season_id);
    dispatcher.create_season(test_season.genre, test_season.name, test_season.end_timestamp);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_non_owner_cannot_create_audition() {
    let dispatcher = deploy_contract();

    // Non-owner tries to create an audition
    start_cheat_caller_address(dispatcher.contract_address, USER());

    let audition_id = 1;
    let session_id = 1;
    let test_audition = create_test_audition(audition_id, session_id);
    dispatcher
        .create_audition(
            season_id, test_audition.genre, test_audition.name, test_audition.end_timestamp,
        );

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_non_owner_cannot_add_oracle() {
    let dispatcher = deploy_contract();

    // Non-owner tries to add an oracle
    start_cheat_caller_address(dispatcher.contract_address, USER());
    dispatcher.add_oracle(ORACLE());

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_oracle_access_control() {
    let dispatcher = deploy_contract();

    // Add an oracle as owner
    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.add_oracle(ORACLE());
    stop_cheat_caller_address(dispatcher.contract_address);

    // Oracle can submit results
    start_cheat_caller_address(dispatcher.contract_address, ORACLE());
    let audition_id = 1;
    dispatcher.submit_results(audition_id, 10, 100);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Not Authorized')]
fn test_non_oracle_cannot_submit_results() {
    let dispatcher = deploy_contract();

    // Add an oracle as owner
    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.add_oracle(ORACLE());
    stop_cheat_caller_address(dispatcher.contract_address);

    // Non-oracle tries to submit results
    start_cheat_caller_address(dispatcher.contract_address, NON_ORACLE());
    let audition_id = 1;
    dispatcher.submit_results(audition_id, 10, 100);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_emergency_stop() {
    let dispatcher = deploy_contract();
    let mut spy = spy_events();

    // Owner pauses the contract
    start_cheat_caller_address(dispatcher.contract_address, OWNER());

    // Check initial state
    assert(!dispatcher.is_paused(), 'Contract should not be paused');

    // Pause the contract
    dispatcher.pause_all();

    // Verify contract is paused
    assert(dispatcher.is_paused(), 'Contract should be paused');

    // Check pause event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    dispatcher.contract_address,
                    SessionAndAudition::Event::PausedAll(
                        PausedAll { timestamp: get_block_timestamp() },
                    ),
                ),
            ],
        );

    // Resume the contract
    dispatcher.resume_all();

    // Verify contract is no longer paused
    assert(!dispatcher.is_paused(), 'Contract should be resumed');

    // Check resume event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    dispatcher.contract_address,
                    SessionAndAudition::Event::ResumedAll(
                        ResumedAll { timestamp: get_block_timestamp() },
                    ),
                ),
            ],
        );

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_non_owner_cannot_pause() {
    let dispatcher = deploy_contract();

    // Non-owner tries to pause the contract
    start_cheat_caller_address(dispatcher.contract_address, USER());
    dispatcher.pause_all();
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify contract is not paused
    assert(!dispatcher.is_paused(), 'Contract should be paused');
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_non_owner_cannot_resume() {
    let dispatcher = deploy_contract();

    // Owner pauses the contract
    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.pause_all();
    stop_cheat_caller_address(dispatcher.contract_address);

    // Non-owner tries to resume the contract
    start_cheat_caller_address(dispatcher.contract_address, USER());
    dispatcher.resume_all();
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify contract is still paused
    assert(dispatcher.is_paused(), 'Contract should still be paused');
}

#[test]
#[should_panic(expect: 'Contract is paused')]
fn test_cannot_create_season_when_paused() {
    let dispatcher = deploy_contract();

    // Owner pauses the contract
    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.pause_all();

    // Try to create a season when paused
    let season_id = 1;
    let test_season = create_test_season(season_id);
    dispatcher.create_season(test_season.genre, test_season.name, test_season.end_timestamp);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Contract is paused')]
fn test_cannot_create_audition_when_paused() {
    let dispatcher = deploy_contract();

    // Owner pauses the contract
    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.pause_all();

    // Try to create an audition when paused
    let audition_id = 1;
    let session_id = 1;
    let test_audition = create_test_audition(audition_id, session_id);
    dispatcher
        .create_audition(
            season_id, test_audition.genre, test_audition.name, test_audition.end_timestamp,
        );

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Contract is paused')]
fn test_oracle_cannot_submit_results_when_paused() {
    let dispatcher = deploy_contract();

    // Add an address as owner
    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.add_oracle(ORACLE());

    // Pause the contract
    dispatcher.pause_all();
    stop_cheat_caller_address(dispatcher.contract_address);

    // Oracle tries to submit results when paused
    start_cheat_caller_address(dispatcher.contract_address, ORACLE());
    let audition_id = 1;
    dispatcher.submit_results(audition_id, 10, 100);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_can_perform_operations_after_resume() {
    let dispatcher = deploy_contract();

    // Owner operations
    start_cheat_caller_address(dispatcher.contract_address, OWNER());

    // Pause the contract
    dispatcher.pause_all();
    assert(dispatcher.is_paused(), 'Contract should be paused');

    // Resume the contract
    dispatcher.resume_all();
    assert(!dispatcher.is_paused(), 'Contract should be resumed');

    // Create a season after resuming
    let season_id = 1;
    let test_season = create_test_season(season_id);
    dispatcher.create_season(test_season.genre, test_season.name, test_season.end_timestamp);

    // Create an audition after resuming
    let audition_id = 1;
    let test_audition = create_test_audition(audition_id, session_id);
    dispatcher
        .create_audition(
            season_id, test_audition.genre, test_audition.name, test_audition.end_timestamp,
        );

    // Verify season was created
    let read_session = dispatcher.read_session(session_id);
    assert(read_session.session_id == session_id, 'Session should be created');

    // Verify audition was created
    let read_audition = dispatcher.read_audition(audition_id);
    assert(read_audition.audition_id == audition_id, 'Audition should be created');

    // Add an oracle
    dispatcher.add_oracle(ORACLE());
    stop_cheat_caller_address(dispatcher.contract_address);

    // Oracle can perform operations after resume
    start_cheat_caller_address(dispatcher.contract_address, ORACLE());
    dispatcher.submit_results(audition_id, 10, 100);
    stop_cheat_caller_address(dispatcher.contract_address);
}

