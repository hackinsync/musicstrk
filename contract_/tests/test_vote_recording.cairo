use contract_::audition::season_and_audition::SeasonAndAudition;
use contract_::audition::season_and_audition_interface::{
    ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait,
    ISeasonAndAuditionSafeDispatcher,
}; //
use contract_::audition::season_and_audition_types::Genre;
use contract_::events::VoteRecorded;
use openzeppelin::access::ownable::interface::IOwnableDispatcher;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use crate::test_season_and_audition::create_default_season;
use crate::test_utils::*;

// Helper function to setup contract with oracle
fn setup_contract_with_oracle() -> ISeasonAndAuditionDispatcher {
    let (contract, _, _) = deploy_contract();

    // Add oracle
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.add_oracle(ORACLE());
    stop_cheat_caller_address(contract.contract_address);

    contract
}

// Helper function to create a default audition
fn create_test_audition(contract: ISeasonAndAuditionDispatcher, audition_id: u256) {
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.create_audition('Summer Hits', 1675123200);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_record_vote_success() {
    let contract = setup_contract_with_oracle();
    let mut spy = spy_events();

    let audition_id: u256 = 1;
    let performer: felt252 = 'performer1';
    let voter: felt252 = 'voter1';
    let weight: felt252 = 100;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    stop_cheat_caller_address(contract.contract_address);

    // Create audition first
    create_test_audition(contract, audition_id);

    // Record vote as oracle
    start_cheat_caller_address(contract.contract_address, ORACLE());
    contract.record_vote(audition_id, performer, voter, weight);
    stop_cheat_caller_address(contract.contract_address);

    // Verify vote was recorded
    start_cheat_caller_address(contract.contract_address, OWNER());
    let recorded_vote = contract.get_vote(audition_id, performer, voter);
    stop_cheat_caller_address(contract.contract_address);

    assert!(recorded_vote.audition_id == audition_id, "Audition ID mismatch");
    assert!(recorded_vote.performer == performer, "Performer mismatch");
    assert!(recorded_vote.voter == voter, "Voter mismatch");
    assert!(recorded_vote.weight == weight, "Weight mismatch");

    // Verify event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::VoteRecorded(
                        VoteRecorded { audition_id, performer, voter, weight },
                    ),
                ),
            ],
        );
}


#[test]
#[should_panic(expected: 'Season is paused')]
fn test_record_vote_should_panic_if_season_paused() {
    let contract = setup_contract_with_oracle();
    let mut spy = spy_events();

    let audition_id: u256 = 1;
    let performer: felt252 = 'performer1';
    let voter: felt252 = 'voter1';
    let weight: felt252 = 100;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    stop_cheat_caller_address(contract.contract_address);

    // Create audition first
    create_test_audition(contract, audition_id);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_season(season_id);
    stop_cheat_caller_address(contract.contract_address);

    // Record vote as oracle
    start_cheat_caller_address(contract.contract_address, ORACLE());
    contract.record_vote(audition_id, performer, voter, weight);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expect: ('Vote already exists',))]
fn test_record_vote_duplicate_should_fail() {
    let contract = setup_contract_with_oracle();

    let audition_id: u256 = 1;
    let performer: felt252 = 'performer1';
    let voter: felt252 = 'voter1';
    let weight: felt252 = 100;

    // Create audition first
    create_test_audition(contract, audition_id);

    // Record first vote as oracle
    start_cheat_caller_address(contract.contract_address, ORACLE());
    contract.record_vote(audition_id, performer, voter, weight);

    // Try to record duplicate vote - should fail
    contract.record_vote(audition_id, performer, voter, weight);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expect: ('Not Authorized',))]
fn test_record_vote_unauthorized_should_fail() {
    let contract = setup_contract_with_oracle();

    let audition_id: u256 = 1;
    let performer: felt252 = 'performer1';
    let voter: felt252 = 'voter1';
    let weight: felt252 = 100;

    // Create audition first
    create_test_audition(contract, audition_id);

    // Try to record vote as non-oracle - should fail
    start_cheat_caller_address(contract.contract_address, VOTER1());
    contract.record_vote(audition_id, performer, voter, weight);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_record_multiple_votes_different_combinations() {
    let contract = setup_contract_with_oracle();
    let audition_id: u256 = 1;
    let performer1: felt252 = 'performer1';
    let performer2: felt252 = 'performer2';
    let voter1: felt252 = 'voter1';
    let voter2: felt252 = 'voter2';
    let weight: felt252 = 100;

    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    stop_cheat_caller_address(contract.contract_address);
    // Create audition first
    create_test_audition(contract, audition_id);

    start_cheat_caller_address(contract.contract_address, ORACLE());

    // Record vote: voter1 -> performer1
    contract.record_vote(audition_id, performer1, voter1, weight);

    // Record vote: voter1 -> performer2 (same voter, different performer - should work)
    contract.record_vote(audition_id, performer2, voter1, weight);

    // Record vote: voter2 -> performer1 (different voter, same performer - should work)
    contract.record_vote(audition_id, performer2, voter2, weight);

    stop_cheat_caller_address(contract.contract_address);

    // Verify all votes were recorded
    start_cheat_caller_address(contract.contract_address, OWNER());

    let vote1 = contract.get_vote(audition_id, performer1, voter1);
    assert!(vote1.audition_id == audition_id, "Vote1 not recorded");

    let vote2 = contract.get_vote(audition_id, performer2, voter1);
    assert!(vote2.audition_id == audition_id, "Vote2 not recorded");

    let vote3 = contract.get_vote(audition_id, performer2, voter2);
    assert!(vote3.audition_id == audition_id, "Vote3 not recorded");

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_record_votes_different_auditions() {
    let contract = setup_contract_with_oracle();

    let audition_id1: u256 = 1;
    let audition_id2: u256 = 2;
    let performer: felt252 = 'performer1';
    let voter: felt252 = 'voter1';
    let weight: felt252 = 100;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    stop_cheat_caller_address(contract.contract_address);
    // Create auditions first
    create_test_audition(contract, audition_id1);
    create_test_audition(contract, audition_id2);

    start_cheat_caller_address(contract.contract_address, ORACLE());

    // Record vote for audition 1
    contract.record_vote(audition_id1, performer, voter, weight);

    // Record vote for audition 2 (same performer and voter, but different audition - should work)
    contract.record_vote(audition_id2, performer, voter, weight);

    stop_cheat_caller_address(contract.contract_address);

    // Verify both votes were recorded
    start_cheat_caller_address(contract.contract_address, OWNER());

    let vote1 = contract.get_vote(audition_id1, performer, voter);
    assert!(vote1.audition_id == audition_id1, "Vote1 not recorded");

    let vote2 = contract.get_vote(audition_id2, performer, voter);
    assert!(vote2.audition_id == audition_id2, "Vote2 not recorded");

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_vote_nonexistent_returns_default() {
    let contract = setup_contract_with_oracle();

    let audition_id: u256 = 1;
    let performer: felt252 = 'performer1';
    let voter: felt252 = 'voter1';
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());

    default_contract_create_season(contract);
    create_test_audition(contract, audition_id);

    stop_cheat_caller_address(contract.contract_address);

    // Try to get non-existent vote
    start_cheat_caller_address(contract.contract_address, OWNER());
    let vote = contract.get_vote(audition_id, performer, voter);
    stop_cheat_caller_address(contract.contract_address);

    // Should return default vote (all zeros)
    assert!(vote.audition_id == 0, "Should return default vote");
    assert!(vote.performer == 0, "Should return default vote");
    assert!(vote.voter == 0, "Should return default vote");
    assert!(vote.weight == 0, "Should return default vote");
}
