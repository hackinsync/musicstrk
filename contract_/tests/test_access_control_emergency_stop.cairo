use contract_::audition::interfaces::iseason_and_audition::ISeasonAndAuditionDispatcherTrait;
use contract_::audition::season_and_audition::SeasonAndAudition;
use contract_::audition::types::season_and_audition::Genre;
use contract_::events::{PausedAll, ResumedAll};
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::get_block_timestamp;
use crate::test_utils::*;

#[test]
fn test_owner_access_control() {
    let (dispatcher, _, _) = deploy_contract();

    // Test owner functions
    start_cheat_caller_address(dispatcher.contract_address, OWNER());

    // Owner can create a season
    default_contract_create_season(dispatcher);

    // Owner can create an audition
    dispatcher.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // Owner can add oracles
    dispatcher.add_oracle(ORACLE());

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_non_owner_cannot_create_season() {
    let (dispatcher, _, _) = deploy_contract();

    // Non-owner tries to create a season
    start_cheat_caller_address(dispatcher.contract_address, USER());

    default_contract_create_season(dispatcher);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_non_owner_cannot_create_audition() {
    let (dispatcher, _, _) = deploy_contract();

    // Non-owner tries to create an audition
    start_cheat_caller_address(dispatcher.contract_address, USER());

    dispatcher.create_audition('Summer Hits', Genre::Pop, 1675123200);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_non_owner_cannot_add_oracle() {
    let (dispatcher, _, _) = deploy_contract();

    // Non-owner tries to add an oracle
    start_cheat_caller_address(dispatcher.contract_address, USER());
    dispatcher.add_oracle(ORACLE());

    stop_cheat_caller_address(dispatcher.contract_address);
}


#[test]
fn test_emergency_stop() {
    let (dispatcher, _, _) = deploy_contract();
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
                    SeasonAndAudition::Event::PausedAll(
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
                    SeasonAndAudition::Event::ResumedAll(
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
    let (dispatcher, _, _) = deploy_contract();

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
    let (dispatcher, _, _) = deploy_contract();

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
    let (dispatcher, _, _) = deploy_contract();

    // Owner pauses the contract
    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.pause_all();

    // Try to create a season when paused
    default_contract_create_season(dispatcher);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Contract is paused')]
fn test_cannot_create_audition_when_paused() {
    let (dispatcher, _, _) = deploy_contract();

    // Owner pauses the contract
    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.pause_all();

    dispatcher.create_audition('Summer Hits', Genre::Pop, 1675123200);

    stop_cheat_caller_address(dispatcher.contract_address);
}

