use contract_::audition::season_and_audition::{
    Audition, ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait,
    ISeasonAndAuditionSafeDispatcher, ISeasonAndAuditionSafeDispatcherTrait, Season,
    SeasonAndAudition,
};
use openzeppelin::access::ownable::interface::IOwnableDispatcher;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

// Test account -> Owner
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

// Test account -> User
fn USER() -> ContractAddress {
    'USER'.try_into().unwrap()
}

// Helper function to deploy the contract
fn deploy_contract() -> (
    ISeasonAndAuditionDispatcher, IOwnableDispatcher, ISeasonAndAuditionSafeDispatcher,
) {
    // declare the contract
    let contract_class = declare("SeasonAndAudition")
        .expect("Failed to declare counter")
        .contract_class();

    // serialize constructor
    let mut calldata: Array<felt252> = array![];

    OWNER().serialize(ref calldata);

    // deploy the contract
    let (contract_address, _) = contract_class
        .deploy(@calldata)
        .expect("Failed to deploy contract");

    let contract = ISeasonAndAuditionDispatcher { contract_address };
    let ownable = IOwnableDispatcher { contract_address };
    let safe_dispatcher = ISeasonAndAuditionSafeDispatcher { contract_address };

    (contract, ownable, safe_dispatcher)
}

// Helper function to create a default Season struct
fn create_default_season(season_id: felt252) -> Season {
    Season {
        season_id,
        genre: 'Pop',
        name: 'Summer Hits',
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: false,
    }
}

// Helper function to create a default Audition struct
fn create_default_audition(audition_id: felt252, season_id: felt252) -> Audition {
    Audition {
        audition_id,
        season_id,
        genre: 'Pop',
        name: 'Live Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: false,
    }
}

#[test]
fn test_season_create() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define season ID
    let season_id: felt252 = 1;

    // Create default season
    let default_season = create_default_season(season_id);

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Season
    contract
        .create_season(
            season_id,
            default_season.genre,
            default_season.name,
            default_season.start_timestamp,
            default_season.end_timestamp,
            default_season.paused,
        );

    // READ Season
    let read_season = contract.read_season(season_id);

    assert!(read_season.season_id == season_id, "Failed to read season");
    assert!(read_season.genre == default_season.genre, "Failed to read season genre");
    assert!(read_season.name == default_season.name, "Failed to read season name");
    assert!(
        read_season.start_timestamp == default_season.start_timestamp,
        "Failed to read season start timestamp",
    );
    assert!(
        read_season.end_timestamp == default_season.end_timestamp,
        "Failed to read season end timestamp",
    );
    assert!(!read_season.paused, "Failed to read season paused");

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::SeasonCreated(
                        SeasonAndAudition::SeasonCreated {
                            season_id: default_season.season_id,
                            genre: default_season.genre,
                            name: default_season.name,
                        },
                    ),
                ),
            ],
        );

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_update_season() {
    let (contract, _, _) = deploy_contract();

    // Define season ID
    let season_id: felt252 = 1;

    // Create default season
    let default_season = create_default_season(season_id);

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Season
    contract
        .create_season(
            season_id,
            default_season.genre,
            default_season.name,
            default_season.start_timestamp,
            default_season.end_timestamp,
            default_season.paused,
        );

    // UPDATE Season
    let updated_season = Season {
        season_id,
        genre: 'Rock',
        name: 'Summer Hits',
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: true,
    };
    contract.update_season(season_id, updated_season);

    // READ Updated Season
    let read_updated_season = contract.read_season(season_id);

    assert!(read_updated_season.genre == 'Rock', "Failed to update season");
    assert!(read_updated_season.name == 'Summer Hits', "Failed to update season name");
    assert!(read_updated_season.paused, "Failed to update season paused");

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_delete_season() {
    let (contract, _, _) = deploy_contract();

    // Define season ID
    let season_id: felt252 = 1;

    // Create default season
    let default_season = create_default_season(season_id);

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Season
    contract
        .create_season(
            season_id,
            default_season.genre,
            default_season.name,
            default_season.start_timestamp,
            default_season.end_timestamp,
            default_season.paused,
        );

    // DELETE Season
    contract.delete_season(season_id);

    // READ Deleted Season
    let deleted_season = contract.read_season(season_id);

    assert!(deleted_season.name == '', "Failed to delete season");
    assert!(deleted_season.genre == '', "Failed to delete season genre");
    assert!(deleted_season.start_timestamp == 0, "Failed to delete season start timestamp");
    assert!(deleted_season.end_timestamp == 0, "Failed to delete season end timestamp");
    assert!(!deleted_season.paused, "Failed to delete season paused");

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_create_audition() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define audition ID and season ID
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    // Create default audition
    let default_audition = create_default_audition(audition_id, season_id);

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Audition
    contract
        .create_audition(
            audition_id,
            season_id,
            default_audition.genre,
            default_audition.name,
            default_audition.start_timestamp,
            default_audition.end_timestamp,
            default_audition.paused,
        );

    // READ Audition
    let read_audition = contract.read_audition(audition_id);

    assert!(read_audition.audition_id == audition_id, "Failed to read audition");
    assert!(read_audition.genre == default_audition.genre, "Failed to read audition genre");
    assert!(read_audition.name == default_audition.name, "Failed to read audition name");
    assert!(
        read_audition.start_timestamp == default_audition.start_timestamp,
        "Failed to read audition start timestamp",
    );
    assert!(
        read_audition.end_timestamp == default_audition.end_timestamp,
        "Failed to read audition end timestamp",
    );
    assert!(!read_audition.paused, "Failed to read audition paused");

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::AuditionCreated(
                        SeasonAndAudition::AuditionCreated {
                            audition_id: default_audition.audition_id,
                            season_id: default_audition.season_id,
                            genre: default_audition.genre,
                            name: default_audition.name,
                        },
                    ),
                ),
            ],
        );

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_update_audition() {
    let (contract, _, _) = deploy_contract();

    // Define audition ID and season ID
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    // Create default audition
    let default_audition = create_default_audition(audition_id, season_id);

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Audition
    contract
        .create_audition(
            audition_id,
            season_id,
            default_audition.genre,
            default_audition.name,
            default_audition.start_timestamp,
            default_audition.end_timestamp,
            default_audition.paused,
        );

    // UPDATE Audition
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: true,
    };
    contract.update_audition(audition_id, updated_audition);

    // READ Updated Audition
    let read_updated_audition = contract.read_audition(audition_id);

    assert!(read_updated_audition.genre == 'Rock', "Failed to update audition");
    assert!(read_updated_audition.name == 'Summer Audition', "Failed to update audition name");
    assert!(read_updated_audition.paused, "Failed to update audition paused");

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_delete_audition() {
    let (contract, _, _) = deploy_contract();

    // Define audition ID and season ID
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    // Create default audition
    let default_audition = create_default_audition(audition_id, season_id);

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Audition
    contract
        .create_audition(
            audition_id,
            season_id,
            default_audition.genre,
            default_audition.name,
            default_audition.start_timestamp,
            default_audition.end_timestamp,
            default_audition.paused,
        );

    // DELETE Audition
    contract.delete_audition(audition_id);

    // READ Deleted Audition
    let deleted_audition = contract.read_audition(audition_id);

    assert!(deleted_audition.name == '', "Failed to delete audition");
    assert!(deleted_audition.genre == '', "Failed to delete audition genre");
    assert!(deleted_audition.start_timestamp == 0, "Failed to delete audition start timestamp");
    assert!(deleted_audition.end_timestamp == 0, "Failed to delete audition end timestamp");
    assert!(!deleted_audition.paused, "Failed to delete audition paused");

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_all_crud_operations() {
    let (contract, _, _) = deploy_contract();

    // Define season and audition IDs
    let season_id: felt252 = 1;
    let audition_id: felt252 = 1;

    // Create default season and audition
    let default_season = create_default_season(season_id);
    let default_audition = create_default_audition(audition_id, season_id);

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Season
    contract
        .create_season(
            season_id,
            default_season.genre,
            default_season.name,
            default_season.start_timestamp,
            default_season.end_timestamp,
            default_season.paused,
        );

    // READ Season
    let read_season = contract.read_season(season_id);

    assert!(read_season.season_id == season_id, "Failed to read season");

    // UPDATE Season
    let updated_season = Season {
        season_id,
        genre: 'Rock',
        name: 'Summer Hits',
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: true,
    };
    contract.update_season(season_id, updated_season);
    let read_updated_season = contract.read_season(season_id);

    assert!(read_updated_season.genre == 'Rock', "Failed to update season");
    assert!(read_updated_season.name == 'Summer Hits', "Failed to update season name");
    assert!(read_updated_season.paused, "Failed to update season paused");

    // DELETE Season
    contract.delete_season(season_id);
    let deleted_season = contract.read_season(season_id);

    assert!(deleted_season.name == '', "Failed to delete season");

    // CREATE Audition
    contract
        .create_audition(
            audition_id,
            season_id,
            default_audition.genre,
            default_audition.name,
            default_audition.start_timestamp,
            default_audition.end_timestamp,
            default_audition.paused,
        );

    // READ Audition
    let read_audition = contract.read_audition(audition_id);

    assert!(read_audition.audition_id == audition_id, "Failed to read audition");

    // UPDATE Audition
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: true,
    };
    contract.update_audition(audition_id, updated_audition);
    let read_updated_audition = contract.read_audition(audition_id);

    assert!(read_updated_audition.genre == 'Rock', "Failed to update audition");
    assert!(read_updated_audition.name == 'Summer Audition', "Failed to update audition name");
    assert!(read_updated_audition.paused, "Failed to update audition paused");

    // DELETE Audition
    contract.delete_audition(audition_id);
    let deleted_audition = contract.read_audition(audition_id);

    assert!(deleted_audition.name == '', "Failed to delete audition");

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_dispatcher_only_owner_can_call_functions() {
    let (_, _, safe_dispatcher) = deploy_contract();

    // Start prank to simulate a non-owner calling the contract
    start_cheat_caller_address(safe_dispatcher.contract_address, USER());

    // Attempt to create a season
    match safe_dispatcher.create_season(1, 'Pop', 'Summer Hits', 1672531200, 1675123200, false) {
        Result::Ok(_) => panic!("Expected panic, but got success"),
        Result::Err(e) => assert(*e.at(0) == 'Caller is not the owner', *e.at(0)),
    }
}

#[test]
fn test_pause_resume_audition() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    // Create default audition
    let default_audition = create_default_audition(audition_id, season_id);

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Create audition
    contract
        .create_audition(
            audition_id,
            season_id,
            default_audition.genre,
            default_audition.name,
            default_audition.start_timestamp,
            default_audition.end_timestamp,
            false // not paused initially
        );

    // Pause audition
    contract.pause_audition(audition_id);

    // Verify paused state
    let paused_audition = contract.read_audition(audition_id);
    assert!(paused_audition.paused, "Audition should be paused");

    // Verify pause event
    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::AuditionPaused(
                        SeasonAndAudition::AuditionPaused {
                            audition_id, timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );

    // Resume audition
    contract.resume_audition(audition_id);

    // Verify resumed state
    let resumed_audition = contract.read_audition(audition_id);
    assert!(!resumed_audition.paused, "Audition should be resumed");

    // Verify resume event
    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::AuditionResumed(
                        SeasonAndAudition::AuditionResumed {
                            audition_id, timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_end_audition() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    // Create and end audition
    let default_audition = create_default_audition(audition_id, season_id);

    start_cheat_caller_address(contract.contract_address, OWNER());

    contract
        .create_audition(
            audition_id,
            season_id,
            default_audition.genre,
            default_audition.name,
            default_audition.start_timestamp,
            default_audition.end_timestamp,
            false,
        );

    // End audition
    contract.end_audition(audition_id);

    // Verify ended state
    assert!(contract.is_ended(audition_id), "Audition should be ended");

    // Verify end event
    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::AuditionEnded(
                        SeasonAndAudition::AuditionEnded {
                            audition_id, timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_reject_operations_on_paused_ended_auditions() {
    let (contract, _, _) = deploy_contract();

    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Create audition
    let default_audition = create_default_audition(audition_id, season_id);
    contract
        .create_audition(
            audition_id,
            season_id,
            default_audition.genre,
            default_audition.name,
            default_audition.start_timestamp,
            default_audition.end_timestamp,
            false,
        );

    // Pause audition
    contract.pause_audition(audition_id);

    // Attempt operations on paused audition
    match contract.register_participant(audition_id, USER()) {
        Result::Ok(_) => panic!("Should not allow registration on paused audition"),
        Result::Err(e) => assert(*e.at(0) == 'Audition is paused', *e.at(0)),
    }

    // End audition
    contract.end_audition(audition_id);

    // Attempt operations on ended audition
    match contract.resume_audition(audition_id) {
        Result::Ok(_) => panic!("Should not allow resuming ended audition"),
        Result::Err(e) => assert(*e.at(0) == 'Audition is ended', *e.at(0)),
    }

    stop_cheat_caller_address(contract.contract_address);
}
