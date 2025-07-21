use contract_::audition::season_and_audition::{
    Audition, ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait,
    ISeasonAndAuditionSafeDispatcher, ISeasonAndAuditionSafeDispatcherTrait, Season,
    SeasonAndAudition,
};
use contract_::events::{
    SeasonCreated, AuditionCreated, AuditionPaused, AuditionResumed, AuditionEnded, SeasonUpdated,
    SeasonDeleted, AuditionUpdated, AuditionDeleted, PriceDeposited, PriceDistributed,
    PerformerRegistered, RegistrationRefunded,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::access::ownable::interface::IOwnableDispatcher;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare,
    start_cheat_caller_address, stop_cheat_caller_address, spy_events, start_cheat_block_timestamp,
    stop_cheat_block_timestamp,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};

// Test account -> Owner
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

// Test account -> User
fn USER() -> ContractAddress {
    'USER'.try_into().unwrap()
}

fn NON_OWNER() -> ContractAddress {
    'NON_OWNER'.try_into().unwrap()
}

// Helper function to deploy the contract
fn deploy_contract() -> (
    ISeasonAndAuditionDispatcher, IOwnableDispatcher, ISeasonAndAuditionSafeDispatcher,
) {
    // declare the contract
    let contract_class = declare("SeasonAndAudition")
        .expect('Failed to declare counter')
        .contract_class();

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
        genre: 'Pop',
        name: 'Summer Hits',
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: false,
    }
}

fn deploy_mock_erc20_contract() -> IERC20Dispatcher {
    let erc20_class = declare("mock_erc20").unwrap().contract_class();
    let mut calldata = array![OWNER().into(), OWNER().into(), 6];
    let (erc20_address, _) = erc20_class.deploy(@calldata).unwrap();

    IERC20Dispatcher { contract_address: erc20_address }
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
                        SeasonCreated {
                            season_id: default_season.season_id,
                            genre: default_season.genre,
                            name: default_season.name,
                            timestamp: get_block_timestamp(),
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

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::SeasonUpdated(
                        SeasonUpdated {
                            season_id: default_season.season_id, timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_delete_season() {
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

    // DELETE Season
    contract.delete_season(season_id);

    // READ Deleted Season
    let deleted_season = contract.read_season(season_id);

    assert!(deleted_season.name == '', "Failed to delete season");
    assert!(deleted_season.genre == '', "Failed to delete season genre");
    assert!(deleted_season.start_timestamp == 0, "Failed to delete season start timestamp");
    assert!(deleted_season.end_timestamp == 0, "Failed to delete season end timestamp");
    assert!(!deleted_season.paused, "Failed to delete season paused");

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::SeasonDeleted(
                        SeasonDeleted {
                            season_id: default_season.season_id, timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );

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
                        AuditionCreated {
                            audition_id: default_audition.audition_id,
                            season_id: default_audition.season_id,
                            genre: default_audition.genre,
                            name: default_audition.name,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_audition_deposit_price_successful() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
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
            default_audition.paused,
        );

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    start_cheat_caller_address(contract.contract_address, OWNER());
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::PriceDeposited(
                        PriceDeposited {
                            audition_id: audition_id,
                            token_address: mock_token_dispatcher.contract_address,
                            amount: 10,
                        },
                    ),
                ),
            ],
        );

    let (token, price): (ContractAddress, u256) = contract.get_audition_prices(audition_id);
    assert(token == mock_token_dispatcher.contract_address, 'Token address mismatch');
    assert(price == 10, 'Prize amount mismatch');
}


#[test]
#[should_panic(expected: 'Amount must be more than zero')]
fn test_audition_deposit_price_should_panic_if_amount_is_zero() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
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
            default_audition.paused,
        );

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    start_cheat_caller_address(contract.contract_address, OWNER());
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 0);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Token address cannot be zero')]
fn test_audition_deposit_price_should_panic_if_token_is_zero_address() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
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
            default_audition.paused,
        );

    stop_cheat_caller_address(contract.contract_address);

    let zero_address = contract_address_const::<0>();

    start_cheat_caller_address(contract.contract_address, OWNER());
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, zero_address, 10);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Prize already deposited')]
fn test_audition_deposit_price_should_panic_if_already_deposited() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
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
            default_audition.paused,
        );

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    start_cheat_caller_address(contract.contract_address, OWNER());
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Insufficient allowance')]
fn test_audition_deposit_price_should_panic_if_insufficient_allowance() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
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
            default_audition.paused,
        );

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 1);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    start_cheat_caller_address(contract.contract_address, OWNER());
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Insufficient balance')]
fn test_audition_deposit_price_should_panic_if_insufficient_balance() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
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
            default_audition.paused,
        );

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    let recipient = contract_address_const::<1234>();
    let owner_balance = mock_token_dispatcher.balance_of(OWNER().into());
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.transfer(recipient, owner_balance);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    start_cheat_caller_address(contract.contract_address, OWNER());
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Audition has already ended')]
fn test_audition_deposit_price_should_panic_if_audition_ended_already() {
    let (contract, _, _) = deploy_contract();
    let mock_token_dispatcher = deploy_mock_erc20_contract();

    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    //  Add timestamp cheat
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    let default_audition = create_default_audition(audition_id, season_id);

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

    // UPDATE Audition with future end time
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672617600, // Future time (24 hours later)
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);

    contract.end_audition(audition_id);

    start_cheat_caller_address(contract.contract_address, OWNER());
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Audition does not exist')]
fn test_audition_deposit_price_should_panic_if_invalid_audition_id() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    start_cheat_caller_address(contract.contract_address, OWNER());
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_audition_deposit_price_should_panic_if_called_by_non_owner() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
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
            default_audition.paused,
        );

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
}


#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_audition_deposit_price_should_panic_if_contract_is_paused() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
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
            default_audition.paused,
        );

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);
    // deposit the price into a prize pool of an audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    // Pause the contract
    contract.pause_all();
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_audition_distribute_prize_successful() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
    let default_audition = create_default_audition(audition_id, season_id);

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

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

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    // Approve contract to spend tokens
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Check contract balance before deposit
    let contract_balance_before = mock_token_dispatcher.balance_of(contract.contract_address);

    // Deposit the prize into the prize pool of an audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);

    // Check contract balance after deposit
    let contract_balance_after = mock_token_dispatcher.balance_of(contract.contract_address);
    assert!(
        contract_balance_after == contract_balance_before + 10,
        "Contract balance did not increase after deposit",
    );

    // Assert winner addresses and amounts are zero before distribution
    let (w_addr1_before, w_addr2_before, w_addr3_before) = contract
        .get_audition_winner_addresses(audition_id);
    let (w_amt1_before, w_amt2_before, w_amt3_before) = contract
        .get_audition_winner_amounts(audition_id);
    let is_distributed_before = contract.is_prize_distributed(audition_id);

    assert!(
        w_addr1_before == contract_address_const::<0>(),
        "Winner 1 address should be zero before distribution",
    );
    assert!(
        w_addr2_before == contract_address_const::<0>(),
        "Winner 2 address should be zero before distribution",
    );
    assert!(
        w_addr3_before == contract_address_const::<0>(),
        "Winner 3 address should be zero before distribution",
    );
    assert!(w_amt1_before == 0, "Winner 1 amount should be zero before distribution");
    assert!(w_amt2_before == 0, "Winner 2 amount should be zero before distribution");
    assert!(w_amt3_before == 0, "Winner 3 amount should be zero before distribution");
    assert!(!is_distributed_before, "Prize should not be distributed before distribution");

    // Prepare for distribution
    start_cheat_caller_address(contract.contract_address, OWNER());

    // UPDATE Audition with future end time
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672617600, // Future time (24 hours later)
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    contract.end_audition(audition_id);

    let winner1 = contract_address_const::<1111>();
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();

    // Check winners' balances before distribution
    let winner1_balance_before = mock_token_dispatcher.balance_of(winner1);
    let winner2_balance_before = mock_token_dispatcher.balance_of(winner2);
    let winner3_balance_before = mock_token_dispatcher.balance_of(winner3);

    // Distribute the prize
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [50, 30, 20]);

    // Check contract balance after distribution
    let contract_balance_final = mock_token_dispatcher.balance_of(contract.contract_address);
    assert!(
        contract_balance_final == contract_balance_after - 10,
        "Contract balance did not decrease after distribution",
    );

    // Check winners' balances after distribution
    let winner1_balance_after = mock_token_dispatcher.balance_of(winner1);
    let winner2_balance_after = mock_token_dispatcher.balance_of(winner2);
    let winner3_balance_after = mock_token_dispatcher.balance_of(winner3);

    assert!(
        winner1_balance_after == winner1_balance_before + 5,
        "Winner 1 did not receive correct amount",
    );
    assert!(
        winner2_balance_after == winner2_balance_before + 3,
        "Winner 2 did not receive correct amount",
    );
    assert!(
        winner3_balance_after == winner3_balance_before + 2,
        "Winner 3 did not receive correct amount",
    );

    // Assert winner addresses and amounts after distribution
    let (w_addr1_after, w_addr2_after, w_addr3_after) = contract
        .get_audition_winner_addresses(audition_id);
    let (w_amt1_after, w_amt2_after, w_amt3_after) = contract
        .get_audition_winner_amounts(audition_id);
    let is_distributed_after = contract.is_prize_distributed(audition_id);

    assert!(w_addr1_after == winner1, "Winner 1 address mismatch after distribution");
    assert!(w_addr2_after == winner2, "Winner 2 address mismatch after distribution");
    assert!(w_addr3_after == winner3, "Winner 3 address mismatch after distribution");
    assert!(w_amt1_after == 5, "Winner 1 amount mismatch after distribution");
    assert!(w_amt2_after == 3, "Winner 2 amount mismatch after distribution");
    assert!(w_amt3_after == 2, "Winner 3 amount mismatch after distribution");
    assert!(is_distributed_after, "Prize should be marked as distributed after distribution");

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::PriceDistributed(
                        PriceDistributed {
                            audition_id: audition_id,
                            winners: [winner1, winner2, winner3],
                            shares: [50, 30, 20],
                            token_address: mock_token_dispatcher.contract_address,
                            amounts: [5, 3, 2].span(),
                        },
                    ),
                ),
            ],
        );

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_audition_distribute_prize_should_panic_if_not_owner() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
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
            default_audition.paused,
        );
    let mock_token_dispatcher = deploy_mock_erc20_contract();
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);

    let winner1 = contract_address_const::<1111>();
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();

    // Not owner
    start_cheat_caller_address(contract.contract_address, NON_OWNER());
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [50, 30, 20]);
}

#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_audition_distribute_prize_should_panic_if_contract_is_paused() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
    let default_audition = create_default_audition(audition_id, season_id);

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

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

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    // Approve contract to spend tokens
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Deposit the prize into the prize pool of an audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);

    // Prepare for distribution
    start_cheat_caller_address(contract.contract_address, OWNER());

    // UPDATE Audition with future end time
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672617600, // Future time (24 hours later)
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    contract.end_audition(audition_id);

    // Pause the contract before distribution
    contract.pause_all();

    let winner1 = contract_address_const::<1111>();
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();

    // This should panic because the contract is paused
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [50, 30, 20]);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Audition does not exist')]
fn test_audition_distribute_prize_should_panic_if_invalid_audition_id() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let invalid_audition_id: felt252 = 999;
    let season_id: felt252 = 1;
    let default_audition = create_default_audition(audition_id, season_id);

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    // Create a valid audition
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

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    // Approve contract to spend tokens
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Deposit the prize into the prize pool of the valid audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);

    // Prepare for distribution on a non-existent audition
    start_cheat_caller_address(contract.contract_address, OWNER());

    let winner1 = contract_address_const::<1111>();
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();

    // This should panic because the audition ID does not exist
    contract.distribute_prize(invalid_audition_id, [winner1, winner2, winner3], [50, 30, 20]);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Audition must end first')]
fn test_distribute_prize_should_panic_if_audition_not_ended() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
    let default_audition = create_default_audition(audition_id, season_id);

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

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

    let mock_token_dispatcher = deploy_mock_erc20_contract();
    stop_cheat_caller_address(contract.contract_address);

    // Approve contract to spend tokens
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Deposit the prize into the prize pool of an audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);

    // Prepare for distribution without ending the audition
    start_cheat_caller_address(contract.contract_address, OWNER());

    let winner1 = contract_address_const::<1111>();
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();

    // This should panic because the audition has not ended yet
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [50, 30, 20]);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'No prize for this audition')]
fn test_distribute_prize_should_panic_if_no_prize_deposited() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
    let default_audition = create_default_audition(audition_id, season_id);

    // Create audition as owner
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

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

    // End audition
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672617600,
        paused: false,
    };

    contract.update_audition(audition_id, updated_audition);
    contract.end_audition(audition_id);
    // assert(contract.is_audition_ended(audition_id), 'audition never end o');
    // contract.end_audition(audition_id);

    // Try to distribute prize without depositing any prize
    let winner1 = contract_address_const::<1111>();
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [50, 30, 20]);

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Prize already distributed')]
fn test_distribute_prize_should_panic_if_already_distributed() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
    let default_audition = create_default_audition(audition_id, season_id);

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

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

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    // Approve contract to spend tokens
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Deposit the prize into the prize pool of an audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);

    // Prepare for distribution
    start_cheat_caller_address(contract.contract_address, OWNER());

    // UPDATE Audition with future end time
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672617600, // Future time (24 hours later)
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    contract.end_audition(audition_id);

    let winner1 = contract_address_const::<1111>();
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();

    // First distribution (should succeed)
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [50, 30, 20]);

    // Second distribution (should panic)
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [50, 30, 20]);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'null contract address')]
fn test_distribute_prize_should_panic_if_winner_is_zero_address() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
    let default_audition = create_default_audition(audition_id, season_id);

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

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

    let mock_token_dispatcher = deploy_mock_erc20_contract();
    stop_cheat_caller_address(contract.contract_address);

    // Approve contract to spend tokens
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Deposit the prize into the prize pool of an audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);

    // Prepare for distribution
    start_cheat_caller_address(contract.contract_address, OWNER());

    // UPDATE Audition with future end time and end it
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672617600,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    contract.end_audition(audition_id);

    let winner1 = contract_address_const::<0>(); // Null address
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();

    // This should panic because winner1 is a zero address
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [50, 30, 20]);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'total does not add up')]
fn test_distribute_prize_should_panic_if_total_shares_not_100() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
    let default_audition = create_default_audition(audition_id, season_id);

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

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

    let mock_token_dispatcher = deploy_mock_erc20_contract();
    stop_cheat_caller_address(contract.contract_address);

    // Approve contract to spend tokens
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Deposit the prize into the prize pool of an audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);

    // Prepare for distribution
    start_cheat_caller_address(contract.contract_address, OWNER());

    // UPDATE Audition with future end time and end it
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672617600,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    contract.end_audition(audition_id);

    let winner1 = contract_address_const::<1111>();
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();

    // This should panic because shares do not add up to 100 (e.g., 40 + 30 + 20 = 90)
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [40, 30, 20]);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Insufficient balance')]
fn test_audition_distribute_prize_should_panic_if_contract_balance_insufficient() {
    let (contract, _, _) = deploy_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;
    let default_audition = create_default_audition(audition_id, season_id);

    // Set up contract and audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

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

    let mock_token_dispatcher = deploy_mock_erc20_contract();
    stop_cheat_caller_address(contract.contract_address);

    // Approve contract to spend tokens
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Deposit the prize into the prize pool of an audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);

    // Cheat: transfer all tokens from contract to a random address, draining contract balance
    let random_address = contract_address_const::<9999>();
    let contract_balance = mock_token_dispatcher.balance_of(contract.contract_address);
    if contract_balance > 0 {
        start_cheat_caller_address(
            mock_token_dispatcher.contract_address, contract.contract_address,
        );
        mock_token_dispatcher.transfer(random_address, contract_balance);
        stop_cheat_caller_address(mock_token_dispatcher.contract_address);
    }

    // Prepare for distribution
    start_cheat_caller_address(contract.contract_address, OWNER());

    // UPDATE Audition with future end time and end it
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672617600,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    contract.end_audition(audition_id);

    let winner1 = contract_address_const::<1111>();
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();

    // This should panic because contract has no balance to distribute
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [50, 30, 20]);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_update_audition() {
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

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::AuditionUpdated(
                        AuditionUpdated { audition_id, timestamp: get_block_timestamp() },
                    ),
                ),
            ],
        );

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_delete_audition() {
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

    // DELETE Audition
    contract.delete_audition(audition_id);

    // READ Deleted Audition
    let deleted_audition = contract.read_audition(audition_id);

    assert!(deleted_audition.name == '', "Failed to delete audition");
    assert!(deleted_audition.genre == '', "Failed to delete audition genre");
    assert!(deleted_audition.start_timestamp == 0, "Failed to delete audition start timestamp");
    assert!(deleted_audition.end_timestamp == 0, "Failed to delete audition end timestamp");
    assert!(!deleted_audition.paused, "Failed to delete audition paused");

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::AuditionDeleted(
                        AuditionDeleted { audition_id, timestamp: get_block_timestamp() },
                    ),
                ),
            ],
        );

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

    println!("Default season is {}", default_season.paused);

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

    assert!(deleted_season.name == 0, "Failed to delete season");

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
        paused: false //can't operate more functions if audition is paused 
    };
    contract.update_audition(audition_id, updated_audition);
    let read_updated_audition = contract.read_audition(audition_id);

    assert!(read_updated_audition.genre == 'Rock', "Failed to update audition");
    assert!(read_updated_audition.name == 'Summer Audition', "Failed to update audition name");
    assert!(!read_updated_audition.paused, "Failed to update audition paused");

    // DELETE Audition
    contract.delete_audition(audition_id);
    let deleted_audition = contract.read_audition(audition_id);

    assert!(deleted_audition.name == 0, "Failed to delete audition");

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
    match safe_dispatcher.create_season(1, 'Pop', 100, 1672531200, 1675123200, false) {
        Result::Ok(_) => panic!("Expected panic, but got success"),
        Result::Err(e) => assert(*e.at(0) == 'Caller is not the owner', *e.at(0)),
    }
}


#[test]
fn test_pause_audition() {
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
        end_timestamp: 1672531500,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    stop_cheat_caller_address(contract.contract_address);

    // Pause audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_audition(audition_id);

    // check that the audition is paused
    let is_audition_paused = contract.read_audition(audition_id);

    assert(is_audition_paused.paused, 'Audition is stil not paused');

    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_emission_of_event_for_pause_audition() {
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

    // UPDATE Audition
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672531500,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);

    // Pause audition
    contract.pause_audition(audition_id);

    // check that the audition is paused
    let is_audition_paused = contract.read_audition(audition_id);

    assert(is_audition_paused.paused, 'Audition is stil not paused');

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::AuditionPaused(
                        AuditionPaused {
                            audition_id: audition_id, timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );

    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_pause_audition_as_non_owner() {
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
        end_timestamp: 1672531500,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    stop_cheat_caller_address(contract.contract_address);

    // Pause audition
    start_cheat_caller_address(contract.contract_address, NON_OWNER());
    contract.pause_audition(audition_id);

    // check that the audition is paused
    let is_audition_paused = contract.read_audition(audition_id);

    assert(is_audition_paused.paused, 'Audition is stil not paused');

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Audition is already paused')]
fn test_pause_audition_twice_should_fail() {
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
        end_timestamp: 1672531500,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    stop_cheat_caller_address(contract.contract_address);

    // Pause audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_audition(audition_id);
    stop_cheat_caller_address(contract.contract_address);

    // check that the audition is paused
    let is_audition_paused = contract.read_audition(audition_id);

    assert(is_audition_paused.paused, 'Audition is stil not paused');

    // try to pause again
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_audition(audition_id);

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Cannot delete paused audition')]
fn test_function_should_fail_after_pause_audition() {
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
        end_timestamp: 1672531500,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    stop_cheat_caller_address(contract.contract_address);

    // Pause audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_audition(audition_id);

    // check that the audition is paused
    let is_audition_paused = contract.read_audition(audition_id);

    assert(is_audition_paused.paused, 'Audition is stil not paused');

    //  try to perform function

    // Delete Audition
    contract.delete_audition(audition_id);

    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_resume_audition() {
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
        end_timestamp: 1672531500,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    stop_cheat_caller_address(contract.contract_address);

    // Pause audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_audition(audition_id);

    // check that the audition is paused
    let is_audition_paused = contract.read_audition(audition_id);
    assert(is_audition_paused.paused, 'Audition is stil not paused');

    //resume_audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.resume_audition(audition_id);

    //check that contract is no longer paused
    let is_audition_pausedv2 = contract.read_audition(audition_id);
    assert(!is_audition_pausedv2.paused, 'Audition is still paused');

    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_attempt_resume_audition_as_non_owner() {
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
        end_timestamp: 1672531500,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    stop_cheat_caller_address(contract.contract_address);

    // Pause audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_audition(audition_id);

    // check that the audition is paused
    let is_audition_paused = contract.read_audition(audition_id);
    assert(is_audition_paused.paused, 'Audition is stil not paused');

    //resume_audition
    start_cheat_caller_address(contract.contract_address, NON_OWNER());
    contract.resume_audition(audition_id);

    //check that contract is no longer paused
    let is_audition_pausedv2 = contract.read_audition(audition_id);
    assert(!is_audition_pausedv2.paused, 'Audition is still paused');

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_emission_of_event_for_resume_audition() {
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

    // UPDATE Audition
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672531500,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);
    stop_cheat_caller_address(contract.contract_address);

    // Pause audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_audition(audition_id);

    // check that the audition is paused
    let is_audition_paused = contract.read_audition(audition_id);
    assert(is_audition_paused.paused, 'Audition is stil not paused');

    //resume_audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.resume_audition(audition_id);

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::AuditionResumed(
                        AuditionResumed {
                            audition_id: audition_id, timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );

    //check that contract is no longer paused
    let is_audition_pausedv2 = contract.read_audition(audition_id);
    assert(!is_audition_pausedv2.paused, 'Audition is still paused');

    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_end_audition() {
    let (contract, _, _) = deploy_contract();

    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    //  Add timestamp cheat
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    let default_audition = create_default_audition(audition_id, season_id);

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

    // UPDATE Audition with future end time
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672617600, // Future time (24 hours later)
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);

    // Verify audition is not ended initially
    assert(!contract.is_audition_ended(audition_id), 'Should not be ended initially');

    // Pause audition (no need to call start_cheat_caller_address again)
    contract.pause_audition(audition_id);

    // Check that the audition is paused
    let is_audition_paused = contract.read_audition(audition_id);
    assert(is_audition_paused.paused, 'Audition should be paused');

    // End the audition
    let end_result = contract.end_audition(audition_id);
    assert(end_result, 'End audition should succeed');

    // Check that audition has ended properly
    let audition_has_ended = contract.read_audition(audition_id);
    assert(contract.is_audition_ended(audition_id), 'Audition should be ended');
    assert(audition_has_ended.end_timestamp != 0, 'End timestamp should be set');
    assert(audition_has_ended.end_timestamp != 1672617600, 'Should not be original end time');

    // Check that the global contract is not paused
    let global_is_paused = contract.is_paused();
    assert(!global_is_paused, 'Global contract is paused');

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_end_audition_as_non_owner() {
    let (contract, _, _) = deploy_contract();

    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Add timestamp cheat
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    let default_audition = create_default_audition(audition_id, season_id);

    // CREATE Audition as owner
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

    // UPDATE Audition as owner
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672617600,
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);

    start_cheat_caller_address(contract.contract_address, NON_OWNER());

    contract.end_audition(audition_id);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_emission_of_event_for_end_audition() {
    let (contract, _, _) = deploy_contract();

    let mut spy = spy_events();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Add timestamp cheat
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    let default_audition = create_default_audition(audition_id, season_id);

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
        end_timestamp: 1672617600, // Future time
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);

    // Pause audition
    contract.pause_audition(audition_id);

    // Check that the audition is paused
    let is_audition_paused = contract.read_audition(audition_id);
    assert(is_audition_paused.paused, 'Audition should be paused');
    // stop_cheat_block_timestamp(contract.contract_address);

    // start_cheat_block_timestamp(contract.contract_address, 1672617600);
    // End the audition
    let end_result = contract.end_audition(audition_id);
    assert(end_result, 'End audition should succeed');

    // Check that audition has ended properly
    let audition_has_ended = contract.read_audition(audition_id);
    assert(contract.is_audition_ended(audition_id), 'Audition should be ended');
    assert(audition_has_ended.end_timestamp != 0, 'End timestamp should be set');

    // Check event emission
    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::AuditionEnded(
                        AuditionEnded { audition_id: audition_id, timestamp: 1672531200 },
                    ),
                ),
            ],
        );

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Cannot delete ended audition')]
fn test_end_audition_functionality() {
    let (contract, _, _) = deploy_contract();

    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    let default_audition = create_default_audition(audition_id, season_id);

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

    // UPDATE with future end time
    let updated_audition = Audition {
        audition_id,
        season_id,
        genre: 'Rock',
        name: 'Summer Audition',
        start_timestamp: 1672531200,
        end_timestamp: 1672617600, // Future time
        paused: false,
    };
    contract.update_audition(audition_id, updated_audition);

    // Verify audition is not ended initially
    assert(!contract.is_audition_ended(audition_id), 'Should not be ended initially');

    // End the audition
    let end_result = contract.end_audition(audition_id);
    assert(end_result, 'End audition should succeed');

    // Check state after ending
    let audition_after_end = contract.read_audition(audition_id);

    // check that the audition has ended
    assert(contract.is_audition_ended(audition_id), 'Audition should be ended');

    assert(contract.is_audition_ended(audition_id), 'Audition should be ended');
    assert(audition_after_end.end_timestamp != 0, 'End timestamp should be set');
    assert(audition_after_end.end_timestamp != 1672617600, 'Should not be original end time');
    assert(audition_after_end.end_timestamp != 0, 'End timestamp should not be 0');

    //  Test restrictions on ended audition
    //try to delete
    contract.delete_audition(audition_id);

    println!("All tests passed!");

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_register_performer_free_registration() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Register performer with zero fee (free registration)
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, contract_address_const::<0>(), 0);
    stop_cheat_caller_address(contract.contract_address);

    // Verify registration
    let registration = contract.read_registration(audition_id, USER());
    assert!(registration.performer == USER(), "Failed to read registration");
    assert!(
        registration.token_address == contract_address_const::<0>(),
        "Failed to read registration token address",
    );
    assert!(registration.fee_amount == 0, "Failed to read registration fee amount");
    assert!(!registration.refunded, "Failed to read registration refunded");

    // // Verify event emission
    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::PerformerRegistered(
                        PerformerRegistered {
                            audition_id: audition_id,
                            performer: USER(),
                            token_address: contract_address_const::<0>(),
                            fee_amount: 0,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_register_performer_erc20_success() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Deploy mock ERC20 token
    let mock_token_dispatcher = deploy_mock_erc20_contract();

    // Transfer tokens from OWNER to USER
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.transfer(USER(), 1000);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Approve tokens for the contract
    start_cheat_caller_address(mock_token_dispatcher.contract_address, USER());
    mock_token_dispatcher.approve(contract.contract_address, 100);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Register performer with ERC20 fee
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, mock_token_dispatcher.contract_address, 50);
    stop_cheat_caller_address(contract.contract_address);

    // Verify registration
    let registration = contract.read_registration(audition_id, USER());
    assert!(registration.performer == USER(), "Failed to read registration");
    assert!(
        registration.token_address == mock_token_dispatcher.contract_address,
        "Failed to read registration token address",
    );
    assert!(registration.fee_amount == 50, "Failed to read registration fee amount");
    assert!(!registration.refunded, "Failed to read registration refunded");

    // Verify event emission
    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::PerformerRegistered(
                        PerformerRegistered {
                            audition_id: audition_id,
                            performer: USER(),
                            token_address: mock_token_dispatcher.contract_address,
                            fee_amount: 50,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expect: 'Audition does not exist')]
fn test_register_performer_nonexistent_audition() {
    let (contract, _, _) = deploy_contract();

    // Try to register for non-existent audition
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(999, contract_address_const::<0>(), 0);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expect: 'Audition is paused')]
fn test_register_performer_paused_audition() {
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

    // Pause the audition
    contract.pause_audition(audition_id);
    stop_cheat_caller_address(contract.contract_address);

    // Try to register for paused audition
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, contract_address_const::<0>(), 0);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expect: 'Already registered')]
fn test_register_performer_duplicate_registration() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Register performer first time
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, contract_address_const::<0>(), 0);
    stop_cheat_caller_address(contract.contract_address);

    // Try to register again (should panic)
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, contract_address_const::<0>(), 0);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expect: 'Insufficient allowance')]
fn test_register_performer_insufficient_allowance() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Deploy mock ERC20 token
    let mock_token_dispatcher = deploy_mock_erc20_contract();

    // Approve insufficient tokens for the contract
    start_cheat_caller_address(mock_token_dispatcher.contract_address, USER());
    mock_token_dispatcher.approve(contract.contract_address, 10); // Only approve 10
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Try to register with higher fee (should panic)
    start_cheat_caller_address(contract.contract_address, USER());
    contract
        .register_performer(
            audition_id, mock_token_dispatcher.contract_address, 50,
        ); // Try to pay 50
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_refund_registration_success() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Deploy mock ERC20 token
    let mock_token_dispatcher = deploy_mock_erc20_contract();

    // Transfer tokens from OWNER to USER
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.transfer(USER(), 1000);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Approve tokens for the contract
    start_cheat_caller_address(mock_token_dispatcher.contract_address, USER());
    mock_token_dispatcher.approve(contract.contract_address, 100);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Register performer with ERC20 fee
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, mock_token_dispatcher.contract_address, 50);
    stop_cheat_caller_address(contract.contract_address);

    // Check user balance before refund
    let user_balance_before = mock_token_dispatcher.balance_of(USER());

    // Pause the audition to allow refunds
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_audition(audition_id);
    
    // Refund the registration (as owner)
    contract.refund_registration(audition_id, USER());
    stop_cheat_caller_address(contract.contract_address);

    // Check user balance after refund
    let user_balance_after = mock_token_dispatcher.balance_of(USER());
    assert!(user_balance_after == user_balance_before + 50, "User did not receive refund");

    // Verify registration is marked as refunded
    let registration = contract.read_registration(audition_id, USER());
    assert!(registration.refunded, "Registration should be marked as refunded");

    // Verify event emission
    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::RegistrationRefunded(
                        RegistrationRefunded {
                            audition_id: audition_id,
                            performer: USER(),
                            token_address: mock_token_dispatcher.contract_address,
                            fee_amount: 50,
                        },
                    ),
                ),
            ],
       );
}

#[test]
#[should_panic(expect: 'Registration already refunded')]
fn test_refund_registration_already_refunded() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Deploy mock ERC20 token
    let mock_token_dispatcher = deploy_mock_erc20_contract();

    // Approve tokens for the contract
    start_cheat_caller_address(mock_token_dispatcher.contract_address, USER());
    mock_token_dispatcher.approve(contract.contract_address, 100);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Register performer with ERC20 fee
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, mock_token_dispatcher.contract_address, 50);
    stop_cheat_caller_address(contract.contract_address);

    // Refund the registration first time
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.refund_registration(audition_id, USER());
    stop_cheat_caller_address(contract.contract_address);

    // Try to refund again (should panic)
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.refund_registration(audition_id, USER());
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expect: 'No fee to refund')]
fn test_refund_free_registration() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Register performer with zero fee (free registration)
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, contract_address_const::<0>(), 0);
    stop_cheat_caller_address(contract.contract_address);

    // Try to refund free registration (should panic)
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.refund_registration(audition_id, USER());
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expect: 'Registration does not exist')]
fn test_refund_nonexistent_registration() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Try to refund non-existent registration (should panic)
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.refund_registration(audition_id, USER());
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_refund_registration_non_owner() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Deploy mock ERC20 token
    let mock_token_dispatcher = deploy_mock_erc20_contract();

    // Approve tokens for the contract
    start_cheat_caller_address(mock_token_dispatcher.contract_address, USER());
    mock_token_dispatcher.approve(contract.contract_address, 100);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Register performer with ERC20 fee
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, mock_token_dispatcher.contract_address, 50);
    stop_cheat_caller_address(contract.contract_address);

    // Try to refund as non-owner (should panic)
    start_cheat_caller_address(contract.contract_address, NON_OWNER());
    contract.refund_registration(audition_id, USER());
    stop_cheat_caller_address(contract.contract_address);
}

// ===== NEW TESTS FOR IMPROVEMENTS =====

#[test]
#[should_panic(expect: 'Native token not implemented')]
fn test_register_performer_native_token_error() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Try to register with native token (zero address) and fee > 0
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, contract_address_const::<0x0>(), 100);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expect: 'Insufficient balance')]
fn test_register_performer_insufficient_balance() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Deploy mock ERC20 token
    let mock_token_dispatcher = deploy_mock_erc20_contract();

    // USER has 0 balance but tries to pay 50 tokens
    // Approve tokens for the contract (but user has insufficient balance)
    start_cheat_caller_address(mock_token_dispatcher.contract_address, USER());
    mock_token_dispatcher.approve(contract.contract_address, 100);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Try to register with insufficient balance
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, mock_token_dispatcher.contract_address, 50);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expect: 'Contract is paused')]
fn test_register_performer_global_pause() {
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

    // Pause the entire contract
    contract.pause_all();

    stop_cheat_caller_address(contract.contract_address);

    // Try to register while contract is paused
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, contract_address_const::<0x0>(), 0);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_registration_count() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Check initial count is 0
    let initial_count = contract.get_registration_count(audition_id);
    assert!(initial_count == 0, "Initial count should be 0");

    // Register first performer
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, contract_address_const::<0x0>(), 0);
    stop_cheat_caller_address(contract.contract_address);

    // Check count is now 1
    let count_after_first = contract.get_registration_count(audition_id);
    assert!(count_after_first == 1, "Count should be 1 after first registration");

    // Register second performer
    start_cheat_caller_address(contract.contract_address, NON_OWNER());
    contract.register_performer(audition_id, contract_address_const::<0x0>(), 0);
    stop_cheat_caller_address(contract.contract_address);

    // Check count is now 2
    let count_after_second = contract.get_registration_count(audition_id);
    assert!(count_after_second == 2, "Count should be 2 after second registration");
}

#[test]
fn test_register_performer_maximum_amount() {
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

    stop_cheat_caller_address(contract.contract_address);

    // Deploy mock ERC20 token
    let mock_token_dispatcher = deploy_mock_erc20_contract();

    // Test with large amount
    let large_amount: u256 = 1000000000000000000; // 1e18

    // Transfer large amount to user
    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.transfer(USER(), large_amount);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Approve large amount
    start_cheat_caller_address(mock_token_dispatcher.contract_address, USER());
    mock_token_dispatcher.approve(contract.contract_address, large_amount);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    // Register with large amount
    start_cheat_caller_address(contract.contract_address, USER());
    contract.register_performer(audition_id, mock_token_dispatcher.contract_address, large_amount);
    stop_cheat_caller_address(contract.contract_address);

    // Verify registration
    let registration = contract.read_registration(audition_id, USER());
    assert!(registration.fee_amount == large_amount, "Large amount registration failed");
}
