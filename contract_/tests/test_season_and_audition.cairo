use contract_::audition::season_and_audition::{
    Audition, ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait,
    ISeasonAndAuditionSafeDispatcher, ISeasonAndAuditionSafeDispatcherTrait, Season,
    SeasonAndAudition,
};
use contract_::events::{
    SeasonCreated, AuditionCreated, AuditionPaused, AuditionResumed, AuditionEnded, SeasonUpdated,
    SeasonDeleted, AuditionUpdated, AuditionDeleted, PriceDeposited, PriceDistributed,
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

// Additional helper functions for testing query functions
fn create_test_season(season_id: felt252, genre: felt252, name: felt252) -> Season {
    Season {
        season_id,
        genre,
        name,
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: false,
    }
}

fn create_test_audition_with_times(
    audition_id: felt252,
    season_id: felt252,
    genre: felt252,
    name: felt252,
    start_timestamp: felt252,
    end_timestamp: felt252,
    paused: bool,
) -> Audition {
    Audition { audition_id, season_id, genre, name, start_timestamp, end_timestamp, paused }
}

fn setup_test_data(contract: ISeasonAndAuditionDispatcher) {
    // Create multiple seasons with different genres
    contract.create_season(1, 'Pop', 'Pop Season 1', 1672531200, 1675123200, false);
    contract.create_season(2, 'Rock', 'Rock Season 1', 1672531200, 1675123200, false);
    contract.create_season(3, 'Pop', 'Pop Season 2', 1672531200, 1675123200, false);

    contract.create_audition(1, 1, 'Pop', 'Pop Audition 1', 1672531200, 1675123200, false);
    contract.create_audition(2, 1, 'Pop', 'Pop Audition 2', 1672531200, 1675123200, false);
    contract.create_audition(3, 2, 'Rock', 'Rock Audition 1', 1672531200, 1675123200, false);
    contract.create_audition(4, 3, 'Pop', 'Pop Audition 3', 1672531200, 1675123200, true); // paused

    contract
        .create_audition(
            5, 1, 'Pop', 'Future Audition', 1893456000, 1896048000, false,
        ); // Future dates
    contract
        .create_audition(
            6, 2, 'Rock', 'Past Audition', 1640995200, 1643673600, false,
        ); // Past dates

    contract.add_oracle(OWNER());
    contract.record_vote(1, 'performer1', 'voter1', 100);
    contract.record_vote(2, 'performer1', 'voter1', 150); // Same performer in different audition
    contract.record_vote(3, 'performer2', 'voter2', 200);
}

// Test genre-based filtering
#[test]
fn test_get_seasons_by_genre() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    // Test getting Pop seasons (should use index)
    let pop_seasons = contract.get_seasons_by_genre('Pop', 10);
    assert!(pop_seasons.len() == 2, "Should return 2 Pop seasons");

    // Test getting Rock seasons
    let rock_seasons = contract.get_seasons_by_genre('Rock', 10);
    assert!(rock_seasons.len() == 1, "Should return 1 Rock season");

    // Test max_results limit
    let limited_seasons = contract.get_seasons_by_genre('Pop', 1);
    assert!(limited_seasons.len() == 1, "Should respect max_results limit");

    // Test non-existent genre
    let jazz_seasons = contract.get_seasons_by_genre('Jazz', 10);
    assert!(jazz_seasons.len() == 0, "Should return empty array for non-existent genre");

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_auditions_by_genre() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    // Test getting Pop auditions (should use index)
    let pop_auditions = contract.get_auditions_by_genre('Pop', 10);
    assert!(pop_auditions.len() == 4, "Should return 4 Pop auditions");

    // Test getting Rock auditions
    let rock_auditions = contract.get_auditions_by_genre('Rock', 10);
    assert!(rock_auditions.len() == 2, "Should return 2 Rock auditions");

    // Test max_results limit
    let limited_auditions = contract.get_auditions_by_genre('Pop', 2);
    assert!(limited_auditions.len() == 2, "Should respect max_results limit");

    stop_cheat_caller_address(contract.contract_address);
}

// Test time-based queries
#[test]
fn test_get_auditions_in_time_range() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    // Test getting auditions in a specific time range
    let start_time: u64 = 1672531200;
    let end_time: u64 = 1675123200;
    let auditions_in_range = contract.get_auditions_in_time_range(start_time, end_time);

    assert!(auditions_in_range.len() >= 4, "Should return auditions in time range");

    // Test with future time range
    let future_start: u64 = 1893456000;
    let future_end: u64 = 1896048000;
    let future_auditions = contract.get_auditions_in_time_range(future_start, future_end);
    assert!(future_auditions.len() >= 1, "Should return future auditions");

    stop_cheat_caller_address(contract.contract_address);
}

// Test invalid time range (start > end)
#[test]
#[should_panic(expected: ('Start time > end time',))]
fn test_get_auditions_in_time_range_invalid() {
    let (contract, _, _) = deploy_contract();
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.get_auditions_in_time_range(1675123200, 1672531200); // start > end
    stop_cheat_caller_address(contract.contract_address);
}


// Test season-based queries
#[test]
fn test_get_auditions_by_season() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    // Test getting auditions for season 1 (should use index)
    let season1_auditions = contract.get_auditions_by_season(1);
    assert!(season1_auditions.len() == 3, "Should return 3 auditions for season 1");

    // Test getting auditions for season 2
    let season2_auditions = contract.get_auditions_by_season(2);
    assert!(season2_auditions.len() == 2, "Should return 2 auditions for season 2");

    // Test getting auditions for season 3
    let season3_auditions = contract.get_auditions_by_season(3);
    assert!(season3_auditions.len() == 1, "Should return 1 audition for season 3");

    // Test non-existent season
    let nonexistent_auditions = contract.get_auditions_by_season(999);
    assert!(nonexistent_auditions.len() == 0, "Should return empty array for non-existent season");

    stop_cheat_caller_address(contract.contract_address);
}

// Test analytics functions
#[test]
fn test_vote_analytics() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    contract.record_vote(1, 'test_performer1', 'test_voter1', 100);
    contract.record_vote(1, 'test_performer1', 'test_voter2', 150);
    contract.record_vote(1, 'test_performer2', 'test_voter1', 200);

    // Test vote count
    let vote_count = contract.get_audition_vote_count(1);
    assert!(
        vote_count == 4, "Should return correct vote count",
    ); // 1 in the setup_test_data + 3 here in this function = 4 votes total for the audition with `id = 1`

    // Test total weight for performer
    let performer1_weight = contract.get_total_vote_weight_for_performer(1, 'test_performer1');
    assert!(performer1_weight == 250, "Should return correct total weight for performer1");

    let performer2_weight = contract.get_total_vote_weight_for_performer(1, 'test_performer2');
    assert!(performer2_weight == 200, "Should return correct total weight for performer2");

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_genre_audition_count() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    let pop_count = contract.get_genre_audition_count('Pop');
    assert!(pop_count == 4, "Should return 4 auditions for Pop genre");

    let rock_count = contract.get_genre_audition_count('Rock');
    assert!(rock_count == 2, "Should return 2 auditions for Rock genre");

    let unknown_count = contract.get_genre_audition_count('Jazz');
    assert!(unknown_count == 0, "Should return 0 for unknown genre");

    stop_cheat_caller_address(contract.contract_address);
}


// Test pagination and listing
#[test]
fn test_get_seasons_by_ids() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    // Test getting multiple seasons by IDs
    let season_ids = array![1, 2, 3];
    let seasons = contract.get_seasons_by_ids(season_ids);
    assert!(seasons.len() == 3, "Should return 3 seasons");

    // Test with some non-existent IDs
    let mixed_ids = array![1, 999, 2];
    let mixed_seasons = contract.get_seasons_by_ids(mixed_ids);
    assert!(mixed_seasons.len() == 2, "Should return only existing seasons");

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_auditions_by_ids() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    // Test getting multiple auditions by IDs
    let audition_ids = array![1, 2, 3];
    let auditions = contract.get_auditions_by_ids(audition_ids);
    assert!(auditions.len() == 3, "Should return 3 auditions");

    // Test with some non-existent IDs
    let mixed_ids = array![1, 999, 2];
    let mixed_auditions = contract.get_auditions_by_ids(mixed_ids);
    assert!(mixed_auditions.len() == 2, "Should return only existing auditions");

    stop_cheat_caller_address(contract.contract_address);
}

// Test utility functions
#[test]
fn test_is_audition_active() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    // Test active audition
    let current_time: u64 = 1673000000; // Between start and end
    let is_active = contract.is_audition_active(1, current_time);
    assert!(is_active, "Should return true for active audition");

    // Test paused audition
    let is_paused_active = contract.is_audition_active(4, current_time);
    assert!(!is_paused_active, "Should return false for paused audition");

    // Test future audition
    let is_future_active = contract.is_audition_active(5, current_time);
    assert!(!is_future_active, "Should return false for future audition");

    // Test past audition
    let is_past_active = contract.is_audition_active(6, current_time);
    assert!(!is_past_active, "Should return false for past audition");

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_count_votes_for_audition() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    contract.record_vote(1, 'test_performer1', 'test_voter1', 100);
    contract.record_vote(1, 'test_performer2', 'test_voter2', 150);
    contract.record_vote(1, 'test_performer3', 'test_voter3', 200);

    // Test counting votes
    let voter_performer_pairs = array![
        ('test_performer1', 'test_voter1'),
        ('test_performer2', 'test_voter2'),
        ('test_performer3', 'test_voter3'),
    ];
    let vote_count = contract.count_votes_for_audition(1, voter_performer_pairs);
    assert!(vote_count == 3, "Should return correct vote count");

    // Test with some non-existent pairs
    let mixed_pairs = array![('test_performer1', 'test_voter1'), ('performer999', 'voter999')];
    let mixed_count = contract.count_votes_for_audition(1, mixed_pairs);
    assert!(mixed_count == 1, "Should return count only for existing votes");

    stop_cheat_caller_address(contract.contract_address);
}

// Test performer history
#[test]
fn test_get_performer_history() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    let history = contract.get_performer_history('performer1');
    assert!(history.len() == 2, "Should return 2 auditions for performer1");
    assert!(*history.at(0) == 1, "First audition should be 1");
    assert!(*history.at(1) == 2, "Second audition should be 2");

    let empty_history = contract.get_performer_history('unknown');
    assert!(empty_history.len() == 0, "Should return empty for unknown performer");

    stop_cheat_caller_address(contract.contract_address);
}

// Test voter history
#[test]
fn test_get_voter_history() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);

    let history = contract.get_voter_history('voter1');
    assert!(history.len() == 2, "Should return 2 auditions for voter1");
    assert!(*history.at(0) == 1, "First audition should be 1");
    assert!(*history.at(1) == 2, "Second audition should be 2");

    let empty_history = contract.get_voter_history('unknown');
    assert!(empty_history.len() == 0, "Should return empty for unknown voter");

    stop_cheat_caller_address(contract.contract_address);
}


// Test edge cases and error scenarios
#[test]
fn test_query_functions_performance_limits() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Create many seasons and auditions
    let mut i: u32 = 1;
    while i <= 20 {
        contract.create_season(i.into(), 'Pop', 'Season', 1672531200, 1675123200, false);
        contract
            .create_audition(i.into(), i.into(), 'Pop', 'Audition', 1672531200, 1675123200, false);
        i += 1;
    };

    // Test max_results limiting
    let limited_seasons = contract.get_seasons_by_genre('Pop', 5);
    assert!(limited_seasons.len() == 5, "Should respect max_results limit");

    let limited_auditions = contract.get_auditions_by_genre('Pop', 5);
    assert!(limited_auditions.len() == 5, "Should respect max_results limit");

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_query_functions_with_empty_data() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Test functions with no data
    let empty_seasons = contract.get_seasons_by_genre('Pop', 10);
    assert!(empty_seasons.len() == 0, "Should return empty array when no data");

    let empty_auditions = contract.get_auditions_by_genre('Pop', 10);
    assert!(empty_auditions.len() == 0, "Should return empty array when no data");

    let empty_active = contract.get_active_auditions(1673000000);
    assert!(empty_active.len() == 0, "Should return empty array when no data");

    stop_cheat_caller_address(contract.contract_address);
}

// Stress test with large datasets
#[test]
fn test_stress_large_dataset() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Create 50 seasons and auditions
    let mut i: u32 = 1;
    while i <= 50 {
        contract.create_season(i.into(), 'Pop', 'Season', 1672531200, 1675123200, false);
        contract
            .create_audition(i.into(), i.into(), 'Pop', 'Audition', 1672531200, 1675123200, false);
        i += 1;
    };

    // Test querying with large data
    let pop_seasons = contract.get_seasons_by_genre('Pop', 50);
    assert!(pop_seasons.len() == 50, "Should handle 50 Pop seasons");

    let pop_auditions = contract.get_auditions_by_genre('Pop', 50);
    assert!(pop_auditions.len() == 50, "Should handle 50 Pop auditions");

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Vote already exists',))]
fn test_duplicate_vote() {
    let (contract, _, _) = deploy_contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    setup_test_data(contract);
    contract.add_oracle(OWNER());

    // Record a vote
    contract.record_vote(1, 'performer1', 'voter1', 100);

    // Attempt duplicate vote (same key)
    contract.record_vote(1, 'performer1', 'voter1', 150);

    stop_cheat_caller_address(contract.contract_address);
}
