use contract_::season_and_audition::{SeasonAndAudition, Season, Audition, Genre, ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait, ISeasonAndAuditionSafeDispatcher, ISeasonAndAuditionSafeDispatcherTrait};
use openzeppelin::access::ownable::interface::IOwnableDispatcher;
use starknet::ContractAddress;
use snforge_std::{ ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, start_cheat_caller_address, stop_cheat_caller_address, spy_events };

// Test account -> Owner
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

// Test account -> User
fn USER() -> ContractAddress {
    'USER'.try_into().unwrap()
}

// Helper function to deploy the contract
fn deploy_contract() -> (ISeasonAndAuditionDispatcher, IOwnableDispatcher, ISeasonAndAuditionSafeDispatcher) {
    // declare the contract
    let contract_class = declare("SeasonAndAudition").expect('Failed to declare counter').contract_class();

    // serialize constructor
    let mut calldata: Array<felt252> = array![];

    OWNER().serialize(ref calldata);

    // deploy the contract
    let (contract_address, _) = contract_class
        .deploy(@calldata)
        .expect('Failed to deploy contract');

    let contract = ISeasonAndAuditionDispatcher { contract_address };
    let ownable = IOwnableDispatcher { contract_address };
    let safe_dispatcher = ISeasonAndAuditionSafeDispatcher { contract_address };

    (contract, ownable, safe_dispatcher)
}

// Helper function to create a default Season struct
fn create_default_season(season_id: felt252) -> Season {
    Season {
        season_id,
        genre: Genre::All,
        price: 100,
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
        genre: Genre::All,
        price: 50,
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
    contract.create_season(season_id, default_season.genre, default_season.price, default_season.start_timestamp, default_season.end_timestamp, default_season.paused);

    // READ Season
    let read_season = contract.read_season(season_id);

    assert!(read_season.season_id == season_id, "Failed to read season");
    assert!(read_season.genre == default_season.genre, "Failed to read season genre");
    assert!(read_season.price == default_season.price, "Failed to read season price");
    assert!(read_season.start_timestamp == default_season.start_timestamp, "Failed to read season start timestamp");
    assert!(read_season.end_timestamp == default_season.end_timestamp, "Failed to read season end timestamp");
    assert!(!read_season.paused, "Failed to read season paused");

    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                SeasonAndAudition::Event::SeasonCreated(
                    SeasonAndAudition::SeasonCreated {
                        season_id: default_season.season_id,
                        genre: default_season.genre,
                        price: default_season.price,
                    }
                )
            )
        ]
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
    contract.create_season(season_id, default_season.genre, default_season.price, default_season.start_timestamp, default_season.end_timestamp, default_season.paused);

    // UPDATE Season
    let updated_season = Season {
        season_id,
        genre: Genre::Pop, 
        price: 150,          
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: true,        
    };
    contract.update_season(season_id, updated_season);
    
    // READ Updated Season
    let read_updated_season = contract.read_season(season_id);

    assert!(read_updated_season.genre == Genre::Pop, "Failed to update season");
    assert!(read_updated_season.price == 150, "Failed to update season price");
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
    contract.create_season(season_id, default_season.genre, default_season.price, default_season.start_timestamp, default_season.end_timestamp, default_season.paused);

    // DELETE Season
    contract.delete_season(season_id);
    
    // READ Deleted Season
    let deleted_season = contract.read_season(season_id);

    assert!(deleted_season.price == 0, "Failed to delete season");
    assert!(deleted_season.genre == Genre::All, "Failed to delete season genre");
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
    contract.create_audition(audition_id, season_id, default_audition.genre, default_audition.price, default_audition.start_timestamp, default_audition.end_timestamp, default_audition.paused);

    // READ Audition
    let read_audition = contract.read_audition(audition_id);

    assert!(read_audition.audition_id == audition_id, "Failed to read audition");
    assert!(read_audition.genre == default_audition.genre, "Failed to read audition genre");
    assert!(read_audition.price == default_audition.price, "Failed to read audition price");
    assert!(read_audition.start_timestamp == default_audition.start_timestamp, "Failed to read audition start timestamp");
    assert!(read_audition.end_timestamp == default_audition.end_timestamp, "Failed to read audition end timestamp");
    assert!(!read_audition.paused, "Failed to read audition paused");

    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                SeasonAndAudition::Event::AuditionCreated(
                    SeasonAndAudition::AuditionCreated {
                        audition_id: default_audition.audition_id,
                        season_id: default_audition.season_id,
                        genre: default_audition.genre,
                        price: default_audition.price,
                    }
                )
            )
        ]
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
    contract.create_audition(audition_id, season_id, default_audition.genre, default_audition.price, default_audition.start_timestamp, default_audition.end_timestamp, default_audition.paused);

    // UPDATE Audition
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: Genre::Rock, 
        price: 75,           
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: true,         
    };
    contract.update_audition(audition_id, updated_audition);
    
    // READ Updated Audition
    let read_updated_audition = contract.read_audition(audition_id);

    assert!(read_updated_audition.genre == Genre::Rock, "Failed to update audition");
    assert!(read_updated_audition.price == 75, "Failed to update audition price");
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
    contract.create_audition(audition_id, season_id, default_audition.genre, default_audition.price, default_audition.start_timestamp, default_audition.end_timestamp, default_audition.paused);

    // DELETE Audition
    contract.delete_audition(audition_id);
    
    // READ Deleted Audition
    let deleted_audition = contract.read_audition(audition_id);

    assert!(deleted_audition.price == 0, "Failed to delete audition");
    assert!(deleted_audition.genre == Genre::All, "Failed to delete audition genre");
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
    contract.create_season(season_id, default_season.genre, default_season.price, default_season.start_timestamp, default_season.end_timestamp, default_season.paused);

    // READ Season
    let read_season = contract.read_season(season_id);

    assert!(read_season.season_id == season_id, "Failed to read season");

    // UPDATE Season
    let updated_season = Season {
        season_id,
        genre: Genre::Pop, 
        price: 150,          
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: true,        
    };
    contract.update_season(season_id, updated_season);
    let read_updated_season = contract.read_season(season_id);

    assert!(read_updated_season.genre == Genre::Pop, "Failed to update season");
    assert!(read_updated_season.price == 150, "Failed to update season price");
    assert!(read_updated_season.paused, "Failed to update season paused");

    // DELETE Season
    contract.delete_season(season_id);
    let deleted_season = contract.read_season(season_id);

    assert!(deleted_season.price == 0, "Failed to delete season");

    // CREATE Audition
    contract.create_audition(audition_id, season_id, default_audition.genre, default_audition.price, default_audition.start_timestamp, default_audition.end_timestamp, default_audition.paused);

    // READ Audition
    let read_audition = contract.read_audition(audition_id);

    assert!(read_audition.audition_id == audition_id, "Failed to read audition");

    // UPDATE Audition
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: Genre::Rock, 
        price: 75,           
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: true,         
    };
    contract.update_audition(audition_id, updated_audition);
    let read_updated_audition = contract.read_audition(audition_id);

    assert!(read_updated_audition.genre == Genre::Rock, "Failed to update audition");
    assert!(read_updated_audition.price == 75, "Failed to update audition price");
    assert!(read_updated_audition.paused, "Failed to update audition paused");

    // DELETE Audition
    contract.delete_audition(audition_id);
    let deleted_audition = contract.read_audition(audition_id);

    assert!(deleted_audition.price == 0, "Failed to delete audition");

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_painc_only_owner_can_call_functions() {
    let (_, _, safe_dispatcher) = deploy_contract();

    // Start prank to simulate a non-owner calling the contract
    start_cheat_caller_address(safe_dispatcher.contract_address, USER());

    // Attempt to create a season
    match safe_dispatcher.create_season(1, Genre::All, 100, 1672531200, 1675123200, false) {
        Result::Ok(_) => panic!("Expected panic, but got success"),
        Result::Err(e) => assert(*e.at(0) == 'Caller is not the owner', *e.at(0)),
    }
}