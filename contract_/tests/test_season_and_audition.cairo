use contract_::audition::interfaces::iseason_and_audition::{
    ISeasonAndAuditionDispatcherTrait, ISeasonAndAuditionSafeDispatcherTrait,
};
use contract_::audition::season_and_audition::SeasonAndAudition;
use contract_::audition::types::season_and_audition::{
    Appeal, Audition, Evaluation, Genre, Season, Vote,
};
use contract_::events::{
    AuditionCreated, AuditionDeleted, AuditionEnded, AuditionPaused, AuditionResumed,
    AuditionUpdated, PriceDeposited, PriceDistributed, ResultSubmitted, SeasonCreated,
    SeasonDeleted, SeasonUpdated,
};
use openzeppelin::access::ownable::interface::IOwnableDispatcher;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_block_timestamp,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use crate::test_audition_registration::{feign_artists_registration, feign_update_config};
use crate::test_utils::*;

fn performer() -> ContractAddress {
    'performerid'.try_into().unwrap()
}

fn performer2() -> ContractAddress {
    'performerid2'.try_into().unwrap()
}

fn performer3() -> ContractAddress {
    'performerid3'.try_into().unwrap()
}

#[test]
fn test_create_season_successfully() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();
    let season_id: u256 = 1;
    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // READ Season
    let read_season = contract.read_season(season_id);

    assert!(read_season.season_id == season_id, "Failed to read season");
    assert!(read_season.name == 'Summer Hits', "Failed to read season name");
    assert!(read_season.start_timestamp == 1672531200, "Failed to read season start timestamp");
    assert!(read_season.end_timestamp == 1675123200, "Failed to read season end timestamp");
    assert!(!read_season.paused, "Failed to read season paused");

    assert!(contract.get_active_season() == Some(season_id), "Failed to get active season");

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::SeasonCreated(
                        SeasonCreated {
                            season_id: season_id,
                            name: 'Summer Hits',
                            start_timestamp: 1672531200,
                            end_timestamp: 1675123200,
                            last_updated_timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );

    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_create_season_should_panic_of_called_by_non_owner() {
    let (contract, _, _) = deploy_contract();
    start_cheat_caller_address(contract.contract_address, USER());
    default_contract_create_season(contract);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'A Season is active')]
fn test_create_season_should_panic_if_another_season_is_ongoing() {
    let (contract, _, _) = deploy_contract();
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // SHOULD PANIC
    default_contract_create_season(contract);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'invalid start time')]
fn test_create_season_should_panic_if_invalid_time() {
    let (contract, _, _) = deploy_contract();
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.create_season('Summer Hits', 1675123200, 1675123200 - 3600);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_create_season_should_panic_if_global_paused() {
    let (contract, _, _) = deploy_contract();
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_all();
    contract.create_season('Summer Hits', 1672531200, 1675531200);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_update_season_successfully() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    let season_id: u256 = 1;

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    default_contract_create_season(contract);

    contract.update_season(season_id, Some('Summer Hits Like chinese'), Some(1675123200));

    // READ Updated Season
    let read_updated_season = contract.read_season(season_id);

    assert!(read_updated_season.name == 'Summer Hits Like chinese', "Failed to update season name");
    assert!(
        read_updated_season.end_timestamp == 1675123200, "Failed to update season end timestamp",
    );
    assert!(
        read_updated_season.last_updated_timestamp == get_block_timestamp(),
        "Failed to update season last updated timestamp",
    );

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::SeasonUpdated(
                        SeasonUpdated {
                            season_id: season_id, last_updated_timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );

    // updater again but this time only update the genre
    contract.update_season(season_id, None, None);

    // READ Updated Season
    let read_updated_season = contract.read_season(season_id);

    assert!(read_updated_season.name == 'Summer Hits Like chinese', "Failed to update season name");
    assert!(
        read_updated_season.last_updated_timestamp == get_block_timestamp(),
        "Failed to update season last updated timestamp",
    );

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_update_season_should_panic_if_caller_not_owner() {
    let (contract, _, _) = deploy_contract();
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, USER());
    default_contract_create_season(contract);
    contract.update_season(season_id, Some('Summer Hits'), Some(1675123200));
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season is paused')]
fn test_update_season_should_panic_if_season_paused() {
    let (contract, _, _) = deploy_contract();
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.pause_season(season_id);
    contract.update_season(season_id, Some('Summer Hits'), Some(1675123200));
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_update_season_should_panic_if_contract_paused() {
    let (contract, _, _) = deploy_contract();
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.pause_all();
    contract.update_season(season_id, Some('Summer Hits'), Some(1675123200));
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_end_season_successfully() {
    let (contract, _, _) = deploy_contract();
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // READ Season
    start_cheat_block_timestamp(contract.contract_address, 1675123200);
    contract.end_season(season_id);
    let read_season = contract.read_season(season_id);

    assert!(read_season.ended, "Failed to end season");
    assert!(!read_season.paused, "Failed to end season paused");
    assert!(
        read_season.last_updated_timestamp == 1675123200,
        "Failed to end season last updated timestamp",
    );

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_create_audition() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define audition ID and season ID
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Season
    default_contract_create_season(contract);
    // CREATE Audition
    start_cheat_block_timestamp(contract.contract_address, 1672531200);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // READ Audition
    let read_audition = contract.read_audition(audition_id);

    assert!(read_audition.audition_id == audition_id, "Failed to read audition");
    assert!(read_audition.name == 'Summer Hits', "Failed to read audition name");
    assert!(read_audition.start_timestamp == 1672531200, "Failed to read audition start timestamp");
    assert!(read_audition.end_timestamp == 1675123200, "Failed to read audition end timestamp");
    assert!(!read_audition.paused, "Failed to read audition paused");

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::AuditionCreated(
                        AuditionCreated {
                            audition_id: audition_id,
                            season_id: season_id,
                            name: 'Summer Hits',
                            genre: Genre::Pop,
                            end_timestamp: 1675123200,
                        },
                    ),
                ),
            ],
        );

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season is paused')]
fn test_create_audition_should_panic_if_season_paused() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define audition ID and season ID
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Create default audition

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // PAUSE Season
    contract.pause_season(season_id);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
}

#[test]
// // #[ignore]
fn test_audition_deposit_price_successful() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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
// #[ignore]
#[should_panic(expected: 'Season is paused')]
fn test_audition_deposit_price_should_panic_if_season_paused() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_season(season_id);
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
// #[ignore]
#[should_panic(expected: 'Amount must be more than zero')]
fn test_audition_deposit_price_should_panic_if_amount_is_zero() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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
// #[ignore]
#[should_panic(expected: 'Token address cannot be zero')]
fn test_audition_deposit_price_should_panic_if_token_is_zero_address() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    stop_cheat_caller_address(contract.contract_address);

    let zero_address = contract_address_const::<0>();

    start_cheat_caller_address(contract.contract_address, OWNER());
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, zero_address, 10);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
// #[ignore]
#[should_panic(expected: "Prize already deposited")]
fn test_audition_deposit_price_should_panic_if_already_deposited() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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
// #[ignore]
#[should_panic(expected: 'Insufficient allowance')]
fn test_audition_deposit_price_should_panic_if_insufficient_allowance() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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
// #[ignore]
#[should_panic(expected: 'Insufficient balance')]
fn test_audition_deposit_price_should_panic_if_insufficient_balance() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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
// #[ignore]
#[should_panic(expected: 'Audition has already ended')]
fn test_audition_deposit_price_should_panic_if_audition_ended_already() {
    let (contract, _, _) = deploy_contract();
    let mock_token_dispatcher = deploy_mock_erc20_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    //  Add timestamp cheat
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    contract.update_audition_details(audition_id, Some(1672617600), None, None);

    contract.end_audition(audition_id);

    start_cheat_caller_address(contract.contract_address, OWNER());
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
// #[ignore]
#[should_panic(expected: 'Audition does not exist')]
fn test_audition_deposit_price_should_panic_if_invalid_audition_id() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
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
// #[ignore]
#[should_panic(expected: 'Caller is not the owner')]
fn test_audition_deposit_price_should_panic_if_called_by_non_owner() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    let mock_token_dispatcher = deploy_mock_erc20_contract();

    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(mock_token_dispatcher.contract_address, OWNER());
    mock_token_dispatcher.approve(contract.contract_address, 10);
    stop_cheat_caller_address(mock_token_dispatcher.contract_address);
    // deposit the price into a prize pool of an audition
    contract.deposit_prize(audition_id, mock_token_dispatcher.contract_address, 10);
}


#[test]
// #[ignore]
#[should_panic(expected: 'Contract is paused')]
fn test_audition_deposit_price_should_panic_if_contract_is_paused() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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
// #[ignore]
fn test_audition_distribute_prize_successful() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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
    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
// #[ignore]
#[should_panic(expected: 'Season is paused')]
fn test_audition_distribute_prize_should_panic_if_season_paused() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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

    // Prepare for distribution
    start_cheat_caller_address(contract.contract_address, OWNER());

    // UPDATE Audition with future end time
    contract.update_audition_details(audition_id, Some(1672617600), None, None);
    contract.end_audition(audition_id);

    let winner1 = contract_address_const::<1111>();
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();

    contract.pause_season(season_id);
    // Distribute the prize
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [50, 30, 20]);

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
// #[ignore]
#[should_panic(expected: 'Caller is not the owner')]
fn test_audition_distribute_prize_should_panic_if_not_owner() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
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
// #[ignore]
#[should_panic(expected: 'Contract is paused')]
fn test_audition_distribute_prize_should_panic_if_contract_is_paused() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
// #[ignore]
#[should_panic(expected: 'Audition does not exist')]
fn test_audition_distribute_prize_should_panic_if_invalid_audition_id() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let invalid_audition_id: u256 = 999;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    // Create a valid audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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
// #[ignore]
#[should_panic(expected: 'Audition must end first')]
fn test_distribute_prize_should_panic_if_audition_not_ended() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Create audition as owner
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
    contract.end_audition(audition_id);

    // Try to distribute prize without depositing any prize
    let winner1 = contract_address_const::<1111>();
    let winner2 = contract_address_const::<2222>();
    let winner3 = contract_address_const::<3333>();
    contract.distribute_prize(audition_id, [winner1, winner2, winner3], [50, 30, 20]);

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
// #[ignore]
#[should_panic(expected: 'Prize already distributed')]
fn test_distribute_prize_should_panic_if_already_distributed() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
// #[ignore]
#[should_panic(expected: 'null contract address')]
fn test_distribute_prize_should_panic_if_winner_is_zero_address() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
// #[ignore]
#[should_panic(expected: 'total does not add up')]
fn test_distribute_prize_should_panic_if_total_shares_not_100() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
// #[ignore]
#[should_panic(expected: 'Insufficient balance')]
fn test_audition_distribute_prize_should_panic_if_contract_balance_insufficient() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Set up contract and audition
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

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

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Create default audition

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    contract.update_audition_details(audition_id, Some(1672617600), None, None);

    // READ Updated Audition
    let read_updated_audition = contract.read_audition(audition_id);

    assert!(read_updated_audition.name == 'Summer Hits', "Failed to update audition name");
    assert!(
        read_updated_audition.end_timestamp == 1672617600,
        "Failed to update audition end timestamp",
    );

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::AuditionUpdated(
                        AuditionUpdated {
                            audition_id,
                            end_timestamp: 1672617600,
                            name: 'Summer Hits',
                            genre: Genre::Pop,
                        },
                    ),
                ),
            ],
        );

    // Stop prank
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season is paused')]
fn test_update_audition_should_panic_if_season_is_paused() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define audition ID and season ID
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Create default audition

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    contract.pause_season(season_id);

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_all_crud_operations() {
    let (contract, _, _) = deploy_contract();

    // Define season and audition IDs
    let season_id: u256 = 1;
    let audition_id: u256 = 1;

    // Create default season and audition

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Season
    default_contract_create_season(contract);

    // READ Season
    let read_season = contract.read_season(season_id);

    println!("Default season is {}", false);

    assert!(read_season.season_id == season_id, "Failed to read season");

    // UPDATE Season
    contract.update_season(season_id, Some('Summer Hits'), Some(1675123200));

    let read_updated_season = contract.read_season(season_id);

    assert!(read_updated_season.name == 'Summer Hits', "Failed to update season name");

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // READ Audition
    let read_audition = contract.read_audition(audition_id);

    assert!(read_audition.audition_id == audition_id, "Failed to read audition");

    // UPDATE Audition
    contract.update_audition_details(audition_id, Some(1672617600), None, None);
    let read_updated_audition = contract.read_audition(audition_id);

    assert!(read_updated_audition.name == 'Summer Hits', "Failed to update audition name");
    assert!(
        read_updated_audition.end_timestamp == 1672617600,
        "Failed to update audition end timestamp",
    );

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
    match safe_dispatcher.create_season('Lfggg', 1672531200, 1675123200) {
        Result::Ok(_) => panic!("Expected panic, but got success"),
        Result::Err(e) => assert(*e.at(0) == 'Caller is not the owner', *e.at(0)),
    }
}


#[test]
fn test_pause_audition() {
    let (contract, _, _) = deploy_contract();

    // Define audition ID and season ID
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Create default audition

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // UPDATE Audition

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Create default audition

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    contract.update_audition_details(audition_id, Some(1672617600), None, None);

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
                        AuditionPaused { audition_id: audition_id, end_timestamp: 1672617600 },
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
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Create default audition

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // UPDATE Audition

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
#[should_panic(expected: 'Audition is paused')]
fn test_pause_audition_twice_should_fail() {
    let (contract, _, _) = deploy_contract();

    // Define audition ID and season ID
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Create default audition

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // UPDATE Audition

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
fn test_resume_audition() {
    let (contract, _, _) = deploy_contract();

    // Define audition ID and season ID
    let audition_id: u256 = 1;

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // UPDATE Audition

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Create default season
    default_contract_create_season(contract);
    // Create default audition

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    // Create default audition

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    contract.update_audition_details(audition_id, Some(1672617600), None, None);
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
                        AuditionResumed { audition_id: audition_id, end_timestamp: 1672617600 },
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

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    //  Add timestamp cheat
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    contract.update_audition_details(audition_id, Some(1672617600), None, None);

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

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Add timestamp cheat
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    // CREATE Audition as owner
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // UPDATE Audition as owner

    contract.update_audition_details(audition_id, Some(1672617600), None, None);

    start_cheat_caller_address(contract.contract_address, NON_OWNER());

    contract.end_audition(audition_id);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_emission_of_event_for_end_audition() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();
    let audition_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
    stop_cheat_block_timestamp(contract.contract_address);

    start_cheat_block_timestamp(contract.contract_address, 1672617601);
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
                        AuditionEnded { audition_id: audition_id, end_timestamp: 1672617601 },
                    ),
                ),
            ],
        );

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_end_audition_functionality() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    contract.update_audition_details(audition_id, Some(1672617600), None, None);

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

    println!("All tests passed!");

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_add_judge() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    default_contract_create_season(contract);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // Add judge
    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);

    // Check that the judge has been added
    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 1, 'Judge should be added');
    assert(*judges.at(0) == judge_address, 'Judge should be added');

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season is paused')]
fn test_add_judge_should_panic_if_season_paused() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    default_contract_create_season(contract);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    contract.pause_season(season_id);
    // Add judge
    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);
}

#[test]
fn test_add_multiple_judge() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    let mut judges = contract.get_judges(audition_id);
    assert(judges.len() == 0, 'Judge should be empty');
    // Add judge
    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);

    judges = contract.get_judges(audition_id);
    assert(judges.len() == 1, 'Judge should be added');
    assert(*judges.at(0) == judge_address, 'Judge should be added');

    let judge_address2 = contract_address_const::<0x124>();
    contract.add_judge(audition_id, judge_address2);

    judges = contract.get_judges(audition_id);
    assert(judges.len() == 2, 'Judge should be added');
    assert(*judges.at(0) == judge_address, 'Judge should be added');
    assert(*judges.at(1) == judge_address2, 'Judge should be added');

    let judge_address3 = contract_address_const::<0x125>();
    contract.add_judge(audition_id, judge_address3);

    judges = contract.get_judges(audition_id);
    assert(judges.len() == 3, 'Judge should be added');
    assert(*judges.at(0) == judge_address, 'Judge should be added');
    assert(*judges.at(1) == judge_address2, 'Judge should be added');
    assert(*judges.at(2) == judge_address3, 'Judge should be added');

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_add_judges_should_panic_if_non_owner() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
    stop_cheat_block_timestamp(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, USER());
    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);
    stop_cheat_block_timestamp(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_add_judges_should_panic_if_contract_paused() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    contract.pause_all();

    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);
    stop_cheat_block_timestamp(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Audition does not exist')]
fn test_add_judges_should_panic_if_audition_does_not_exist() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);
    stop_cheat_block_timestamp(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Audition has already ended')]
fn test_add_judges_should_panic_if_audition_has_ended() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
    stop_cheat_block_timestamp(contract.contract_address);
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp + 1675123200 + 10);

    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Judge already added')]
fn test_add_judges_should_panic_if_judge_already_added() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    default_contract_create_season(contract);
    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    let mut judges = contract.get_judges(audition_id);
    assert(judges.len() == 0, 'Judge should be empty');
    // Add judge
    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);

    judges = contract.get_judges(audition_id);
    assert(judges.len() == 1, 'Judge should be added');
    assert(*judges.at(0) == judge_address, 'Judge should be added');

    contract.add_judge(audition_id, judge_address);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_remove_judge() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
    let judge_address = contract_address_const::<0x1777723>();
    contract.add_judge(audition_id, judge_address);
    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 1, 'Judge should be added');
    assert(*judges.at(0) == judge_address, 'Judge should be added');

    let judge_address2 = contract_address_const::<0x1777724>();
    contract.add_judge(audition_id, judge_address2);
    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 2, 'Second judge should be added');
    assert(*judges.at(1) == judge_address2, 'judge address dont match');

    // print the judges
    println!("judges: {:?}", judges);

    contract.remove_judge(audition_id, judge_address);
    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 1, 'Judge should be removed');
    println!("judges: {:?}", judges);

    assert(*judges.at(0) == judge_address2, 'Incorrect Judge removed');

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season is paused')]
fn test_remove_judge_should_panic_if_season_paused() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
    let judge_address = contract_address_const::<0x1777723>();
    contract.add_judge(audition_id, judge_address);
    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 1, 'Judge should be added');
    assert(*judges.at(0) == judge_address, 'Judge should be added');

    let judge_address2 = contract_address_const::<0x1777724>();
    contract.add_judge(audition_id, judge_address2);
    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 2, 'Second judge should be added');
    assert(*judges.at(1) == judge_address2, 'judge address dont match');

    // print the judges
    println!("judges: {:?}", judges);

    contract.pause_season(season_id);
    contract.remove_judge(audition_id, judge_address);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_judge_remove_can_remove_and_add_multiple_judges() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    default_contract_create_season(contract);

    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
    let judge_address = contract_address_const::<0x1777723>();
    contract.add_judge(audition_id, judge_address);
    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 1, 'Judge should be added');
    assert(*judges.at(0) == judge_address, 'Judge should be added');

    let judge_address2 = contract_address_const::<0x1777724>();
    contract.add_judge(audition_id, judge_address2);
    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 2, 'Second judge should be added');
    assert(*judges.at(1) == judge_address2, 'judge address dont match');

    contract.remove_judge(audition_id, judge_address);
    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 1, 'Judge should be removed');
    println!("judges: {:?}", judges);

    assert(*judges.at(0) == judge_address2, 'Incorrect Judge removed');
    // Add two more judges
    let judge_address3 = contract_address_const::<0x1777725>();
    let judge_address4 = contract_address_const::<0x1777726>();
    contract.add_judge(audition_id, judge_address3);
    contract.add_judge(audition_id, judge_address4);

    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 3, '3 judges after add');
    assert(*judges.at(0) == judge_address2, 'judge2 pos0');
    assert(*judges.at(1) == judge_address3, 'judge3 pos1');
    assert(*judges.at(2) == judge_address4, 'judge4 pos2');

    // Remove one judge (judge_address3)
    contract.remove_judge(audition_id, judge_address3);
    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 2, '2 judges after rm');
    assert(*judges.at(0) == judge_address2, 'judge2 pos0');
    assert(*judges.at(1) == judge_address4, 'judge4 pos1');

    // Add three more judges
    let judge_address5 = contract_address_const::<0x1777727>();
    let judge_address6 = contract_address_const::<0x1777728>();
    let judge_address7 = contract_address_const::<0x1777729>();
    contract.add_judge(audition_id, judge_address5);
    contract.add_judge(audition_id, judge_address6);
    contract.add_judge(audition_id, judge_address7);

    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 5, '5 judges after add');
    assert(*judges.at(0) == judge_address2, 'judge2 pos0');
    assert(*judges.at(1) == judge_address4, 'judge4 pos1');
    assert(*judges.at(2) == judge_address5, 'judge5 pos2');
    assert(*judges.at(3) == judge_address6, 'judge6 pos3');
    assert(*judges.at(4) == judge_address7, 'judge7 pos4');

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_judge_remove_should_panic_if_contract_paused() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    // Create audition

    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // Add a judge
    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);

    // Pause the contract
    contract.pause_all();

    // Try to remove the judge (should panic)
    contract.remove_judge(audition_id, judge_address);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Audition does not exist')]
fn test_remove_judge_should_panic_if_audition_doesnt_exist() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let judge_address = contract_address_const::<0x123>();
    contract.remove_judge(audition_id, judge_address);
    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Audition has ended')]
fn test_remove_judge_should_panic_if_audition_has_ended() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    // Create audition

    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // Add a judge
    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);

    // Move time past the audition's end
    stop_cheat_block_timestamp(contract.contract_address);
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp + 1675123200 + 10);

    // Try to remove the judge (should panic)
    contract.remove_judge(audition_id, judge_address);

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Judge not found')]
fn test_remove_judge_should_panic_if_judge_not_found() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    // Create audition

    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // Try to remove a judge that was never added (should panic)
    let judge_address = contract_address_const::<0x123>();
    contract.remove_judge(audition_id, judge_address);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_judges_returns_expected_judges() {
    let (contract, _, _) = deploy_contract();
    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);
    // Create audition

    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // Add judges
    let judge1 = contract_address_const::<0x111>();
    let judge2 = contract_address_const::<0x222>();
    let judge3 = contract_address_const::<0x333>();
    contract.add_judge(audition_id, judge1);
    contract.add_judge(audition_id, judge2);
    contract.add_judge(audition_id, judge3);

    // Get judges and assert
    let judges = contract.get_judges(audition_id);
    assert(judges.len() == 3, 'Expected 3 judges');
    assert(*judges.at(0) == judge1, 'Judge 1 mismatch');
    assert(*judges.at(1) == judge2, 'Judge 2 mismatch');
    assert(*judges.at(2) == judge3, 'Judge 3 mismatch');

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_submit_evaluation_success() {
    let (contract, erc20) = feign_update_config(OWNER(), 1, 100);
    let artists = feign_artists_registration(1, erc20, 100, contract);

    let (performer, performer_id) = *artists.at(0);

    let audition_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    let mut judges = contract.get_judges(audition_id);
    assert(judges.len() == 0, 'Judge should be empty');
    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);
    let judge_address2 = contract_address_const::<0x124>();
    contract.add_judge(audition_id, judge_address2);
    let judge_address3 = contract_address_const::<0x125>();
    contract.add_judge(audition_id, judge_address3);
    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);

    // submit evaluation
    start_cheat_caller_address(contract.contract_address, judge_address);
    contract.submit_evaluation(audition_id, performer_id, (1, 2, 3));
    stop_cheat_caller_address(contract.contract_address);

    // get evaluation
    let evaluation = contract.get_evaluation(audition_id, performer_id);
    println!("evaluation: {:?}", evaluation.len());
    assert(evaluation.len() == 1, 'Evaluation should be 3');
    assert(*(evaluation.at(0)).audition_id == audition_id, 'Audition ID should match');
    assert(*(evaluation.at(0)).performer == performer, 'Performer should match');
    assert(*(evaluation.at(0)).criteria == (1, 2, 3), 'Criteria should match');
}


#[test]
#[should_panic(expected: 'Season is paused')]
fn test_submit_evaluation_should_panic_if_season_paused() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    let mut judges = contract.get_judges(audition_id);
    assert(judges.len() == 0, 'Judge should be empty');
    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);
    let judge_address2 = contract_address_const::<0x124>();
    contract.add_judge(audition_id, judge_address2);
    let judge_address3 = contract_address_const::<0x125>();
    contract.add_judge(audition_id, judge_address3);
    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_season(season_id);
    stop_cheat_caller_address(contract.contract_address);
    // submit evaluation
    start_cheat_caller_address(contract.contract_address, judge_address);
    contract.submit_evaluation(audition_id, 0, (1, 2, 3));
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_multiple_judges_submit_evaluation_for_same_performer() {
    let (contract, erc20) = feign_update_config(OWNER(), 1, 100);
    let artists = feign_artists_registration(1, erc20, 100, contract);

    let (performer, performer_id) = *artists.at(0);
    let audition_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    // Add multiple judges
    let judge_address1 = contract_address_const::<0x111>();
    let judge_address2 = contract_address_const::<0x112>();
    let judge_address3 = contract_address_const::<0x113>();
    contract.add_judge(audition_id, judge_address1);
    contract.add_judge(audition_id, judge_address2);
    contract.add_judge(audition_id, judge_address3);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);

    // Each judge submits an evaluation for the same performer
    start_cheat_caller_address(contract.contract_address, judge_address1);
    contract.submit_evaluation(audition_id, performer_id, (3, 4, 5));
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, judge_address2);
    contract.submit_evaluation(audition_id, performer_id, (6, 7, 8));
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, judge_address3);
    contract.submit_evaluation(audition_id, performer_id, (9, 1, 2));
    stop_cheat_caller_address(contract.contract_address);

    // Get all evaluations for the performer
    let evaluations = contract.get_evaluation(audition_id, performer_id);
    println!("Evaluations count: {:?}", evaluations.len());
    assert(evaluations.len() == 3, 'There should be 3');

    // Check that all criteria are present
    let mut found_criteria_1 = false;
    let mut found_criteria_2 = false;
    let mut found_criteria_3 = false;
    for i in 0..evaluations.len() {
        let criteria = *(evaluations.at(i)).criteria;
        if criteria == (3, 4, 5) {
            found_criteria_1 = true;
        } else if criteria == (6, 7, 8) {
            found_criteria_2 = true;
        } else if criteria == (9, 1, 2) {
            found_criteria_3 = true;
        }
        assert(*(evaluations.at(i)).audition_id == audition_id, 'Audition ID should match');
        assert(*(evaluations.at(i)).performer == performer, 'Performer should match');
    }
    assert(found_criteria_1, 'Criteria (3,4,5) not found');
    assert(found_criteria_2, 'Criteria (6,7,8) not found');
    assert(found_criteria_3, 'Criteria (9,1,2) not found');
}

#[test]
fn test_multiple_judges_submit_evaluation_for_diffrent_performers() {
    let audition_id: u256 = 1;
    let (contract, erc20) = feign_update_config(OWNER(), audition_id, 100);
    let artists = feign_artists_registration(3, erc20, 100, contract);

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    // default_contract_create_season(contract);

    // // CREATE Audition
    // contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // Add multiple judges
    let judge_address1 = contract_address_const::<0x211>();
    let judge_address2 = contract_address_const::<0x212>();
    let judge_address3 = contract_address_const::<0x213>();
    contract.add_judge(audition_id, judge_address1);
    contract.add_judge(audition_id, judge_address2);
    contract.add_judge(audition_id, judge_address3);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);

    // Register different performers
    let (performer1, performer_id1) = *artists.at(0);
    let (performer2, performer_id2) = *artists.at(1);
    let (performer3, performer_id3) = *artists.at(2);

    // Each judge submits an evaluation for a different performer
    start_cheat_caller_address(contract.contract_address, judge_address1);
    contract.submit_evaluation(audition_id, performer_id1, (1, 2, 3));
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, judge_address2);
    contract.submit_evaluation(audition_id, performer_id2, (4, 5, 6));
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, judge_address3);
    contract.submit_evaluation(audition_id, performer_id3, (7, 8, 9));
    stop_cheat_caller_address(contract.contract_address);

    // Get and check evaluation for performer 1
    let evals1 = contract.get_evaluation(audition_id, performer_id1);
    assert(evals1.len() == 1, 'evals1 count fail');
    let criteria1 = *(evals1.at(0)).criteria;
    assert(criteria1 == (1, 2, 3), 'criteria1 fail');
    assert(*(evals1.at(0)).audition_id == audition_id, 'aid1 fail');
    assert(*(evals1.at(0)).performer == performer1, 'pid1 fail');

    // Get and check evaluation for performer 2
    let evals2 = contract.get_evaluation(audition_id, performer_id2);
    assert(evals2.len() == 1, 'evals2 count fail');
    let criteria2 = *(evals2.at(0)).criteria;
    assert(criteria2 == (4, 5, 6), 'criteria2 fail');
    assert(*(evals2.at(0)).audition_id == audition_id, 'aid2 fail');
    assert(*(evals2.at(0)).performer == performer2, 'pid2 fail');

    // Get and check evaluation for performer 3
    let evals3 = contract.get_evaluation(audition_id, performer_id3);
    assert(evals3.len() == 1, 'evals3 count fail');
    let criteria3 = *(evals3.at(0)).criteria;
    assert(criteria3 == (7, 8, 9), 'criteria3 fail');
    assert(*(evals3.at(0)).audition_id == audition_id, 'aid3 fail');
    assert(*(evals3.at(0)).performer == performer3, 'pid3 fail');

    // Get all evaluations for the audition and assert their correctness
    let all_evals = contract.get_evaluations(audition_id);
    assert(all_evals.len() == 3, 'all_evals count fail');

    // Check that each evaluation matches the expected performer and criteria
    let mut found1 = false;
    let mut found2 = false;
    let mut found3 = false;

    for i in 0..all_evals.len() {
        let eval = all_evals.at(i);
        let performer = *(eval.performer);
        let criteria = *(eval.criteria);

        if performer == contract.get_performer_address(audition_id, performer_id1) {
            assert(criteria == (1, 2, 3), 'all_evals: criteria1 fail');
            found1 = true;
        } else if performer == contract.get_performer_address(audition_id, performer_id2) {
            assert(criteria == (4, 5, 6), 'all_evals: criteria2 fail');
            found2 = true;
        } else if performer == contract.get_performer_address(audition_id, performer_id3) {
            assert(criteria == (7, 8, 9), 'all_evals: criteria3 fail');
            found3 = true;
        } else {
            assert(false, 'all_evals: unexpected performer');
        }
    }
    assert(found1, 'all_evals: performer1 not found');
    assert(found2, 'all_evals: performer2 not found');
    assert(found3, 'all_evals: performer3 not found');
}


#[test]
#[should_panic(expected: 'Judging is paused')]
fn test_submit_evaluation_should_panic_when_judging_is_paused() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);

    // pause judging
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_judging();
    stop_cheat_caller_address(contract.contract_address);

    // submit evaluation
    start_cheat_caller_address(contract.contract_address, judge_address);
    contract.submit_evaluation(audition_id, 0, (1, 2, 3));
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_pause_judging_success() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);

    // pause judging
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_judging();
    stop_cheat_caller_address(contract.contract_address);

    // check if judging is paused
    let is_paused = contract.is_judging_paused();
    assert(is_paused, 'Judging should be paused');
}

#[test]
fn test_resume_judging_success() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);

    // pause judging
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_judging();
    stop_cheat_caller_address(contract.contract_address);

    // check if judging is paused
    let is_paused = contract.is_judging_paused();
    assert(is_paused, 'Judging should be paused');

    // resume judging
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.resume_judging();
    stop_cheat_caller_address(contract.contract_address);

    // check if judging is resumed
    let is_paused = contract.is_judging_paused();
    assert(!is_paused, 'Judging should be resumed');
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_pause_judging_should_panic_when_caller_is_not_owner() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    default_contract_create_season(contract);
    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);

    // pause judging
    start_cheat_caller_address(contract.contract_address, USER());
    contract.pause_judging();
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_resume_judging_should_panic_when_caller_is_not_owner() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);

    // pause judging
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_judging();
    stop_cheat_caller_address(contract.contract_address);

    // check if judging is paused
    let is_paused = contract.is_judging_paused();
    assert(is_paused, 'Judging should be paused');

    // resume judging
    start_cheat_caller_address(contract.contract_address, USER());
    contract.resume_judging();
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_set_weight_for_audition_success() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);

    contract.set_evaluation_weight(audition_id, (10, 60, 30));
    let evaluation_weight = contract.get_evaluation_weight(audition_id);
    assert(evaluation_weight == (10, 60, 30), 'Evaluation weight should be set');

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season is paused')]
fn test_set_weight_for_audition_should_panic_if_season_paused() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    default_contract_create_season(contract);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);

    contract.pause_season(season_id);
    contract.set_evaluation_weight(audition_id, (10, 60, 30));
    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Total weight should be 100')]
fn test_set_weight_for_audition_should_panic_if_weight_doest_add_up_to_100() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    let judge_address = contract_address_const::<0x123>();
    contract.add_judge(audition_id, judge_address);

    contract.set_evaluation_weight(audition_id, (4, 60, 30));

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_perform_aggregate_score_calculation_successful() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);

    contract.create_season('Lfggg', 1672531200, 1675123200);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // then add 2 judges
    let judge_address1 = contract_address_const::<0x123>();
    let judge_address2 = contract_address_const::<0x124>();
    contract.add_judge(audition_id, judge_address1);
    contract.add_judge(audition_id, judge_address2);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);

    // then register 2 performers
    let performer_id1 = 'performerA';
    let performer_id2 = 'performerB';

    // then set weight
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_evaluation_weight(audition_id, (40, 30, 30));
    stop_cheat_caller_address(contract.contract_address);

    // then submit evaluation for each performer
    start_cheat_caller_address(contract.contract_address, judge_address1);
    contract.submit_evaluation(audition_id, performer_id1, (4, 7, 3));
    contract.submit_evaluation(audition_id, performer_id2, (6, 7, 8));
    stop_cheat_caller_address(contract.contract_address);
    start_cheat_caller_address(contract.contract_address, judge_address2);
    contract.submit_evaluation(audition_id, performer_id1, (4, 9, 2));
    contract.submit_evaluation(audition_id, performer_id2, (4, 9, 6));
    stop_cheat_caller_address(contract.contract_address);

    // move the timestamp to the end of the audition
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp + 1675123200);

    // then perform aggregate score calculation
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.perform_aggregate_score_calculation(audition_id);
    stop_cheat_caller_address(contract.contract_address);

    // get the aggregate score for each performer
    let aggregate_score1 = contract.get_aggregate_score_for_performer(audition_id, performer_id1);
    let aggregate_score2 = contract.get_aggregate_score_for_performer(audition_id, performer_id2);
    println!("aggregate_score1: {:?}", aggregate_score1); // aggregate_score1: 4
    println!("aggregate_score2: {:?}", aggregate_score2); // aggregate_score2: 6

    // get the aggregate score for the audition
    let aggregate_score = contract.get_aggregate_score(audition_id);
    println!(
        "aggregate_score: {:?}", aggregate_score,
    ); // aggregate_score: [(530776410631550129238593, 4), (530776410631550129238594, 6)]

    stop_cheat_block_timestamp(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season is paused')]
fn test_perform_aggregate_score_calculation_should_panic_if_season_paused() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());

    // Set timestamp
    let initial_timestamp: u64 = 1672531200;
    start_cheat_block_timestamp(contract.contract_address, initial_timestamp);
    contract.create_season('Lfggg', 1672531200, 1675123200);

    // CREATE Audition
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);

    // then add 2 judges
    let judge_address1 = contract_address_const::<0x123>();
    let judge_address2 = contract_address_const::<0x124>();
    contract.add_judge(audition_id, judge_address1);
    contract.add_judge(audition_id, judge_address2);

    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);

    // then register 2 performers
    let performer_id1 = 'performerA';
    let performer_id2 = 'performerB';

    // then set weight
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_evaluation_weight(audition_id, (40, 30, 30));
    stop_cheat_caller_address(contract.contract_address);

    // then submit evaluation for each performer
    start_cheat_caller_address(contract.contract_address, judge_address1);
    contract.submit_evaluation(audition_id, performer_id1, (4, 7, 3));
    contract.submit_evaluation(audition_id, performer_id2, (6, 7, 8));
    stop_cheat_caller_address(contract.contract_address);
    start_cheat_caller_address(contract.contract_address, judge_address2);
    contract.submit_evaluation(audition_id, performer_id1, (4, 9, 2));
    contract.submit_evaluation(audition_id, performer_id2, (4, 9, 6));
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_season(season_id);
    stop_cheat_caller_address(contract.contract_address);

    // move the timestamp to the end of the audition
    start_cheat_block_timestamp(contract.contract_address, 1675123201);
    // then perform aggregate score calculation
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_season(season_id);
    contract.perform_aggregate_score_calculation(audition_id);
    stop_cheat_caller_address(contract.contract_address);

    stop_cheat_block_timestamp(contract.contract_address);
}


#[test]
fn test_pause_season_success() {
    let (contract, _, _) = deploy_contract();

    // Define season ID
    let season_id: u256 = 1;

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Season
    default_contract_create_season(contract);

    contract.pause_season(season_id);
    stop_cheat_caller_address(contract.contract_address);

    let is_paused = contract.is_season_paused(season_id);
    assert(is_paused, 'Season should be paused');

    let read_season = contract.read_season(season_id);
    assert(read_season.paused, 'Season should be paused');
}


#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_pause_season_should_panic_if_paused_by_non_owner() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define season ID
    let season_id: u256 = 1;

    // Start prank to simulate the owner calling the contract

    // CREATE Season
    default_contract_create_season(contract);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_season(season_id);
}


#[test]
#[should_panic(expected: 'Season is paused')]
fn test_pause_season_should_panic_if_season_is_paused() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define season ID
    let season_id: u256 = 1;

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Season
    default_contract_create_season(contract);

    contract.pause_season(season_id);
    contract.pause_season(season_id);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season does not exist')]
fn test_pause_season_should_panic_if_season_doesnt_exist() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define season ID
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.pause_season(season_id);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season has already ended')]
fn test_pause_season_should_panic_if_season_is_ended() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define season ID
    let season_id: u256 = 1;

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.create_season('Lfggg', 1672531200, 1675123200);

    start_cheat_block_timestamp(contract.contract_address, 1675123200 + 1);
    contract.pause_season(season_id);
    stop_cheat_block_timestamp(contract.contract_address);

    stop_cheat_caller_address(contract.contract_address);

    let is_paused = contract.is_season_paused(season_id);
    assert(is_paused, 'Season should be paused');

    let read_season = contract.read_season(season_id);
    assert(read_season.paused, 'Season should be paused');
}

#[test]
fn test_resume_season_success() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define season ID
    let season_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.pause_season(season_id);

    let is_paused = contract.is_season_paused(season_id);
    assert(is_paused, 'Season should be paused');

    let read_season = contract.read_season(season_id);
    assert(read_season.paused, 'Season should be paused');

    contract.resume_season(season_id);

    stop_cheat_caller_address(contract.contract_address);

    let is_paused = contract.is_season_paused(season_id);
    assert(!is_paused, 'Season should be resumed');

    let read_season = contract.read_season(season_id);
    assert(!read_season.paused, 'Season should be resumed');
}


#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_resume_season_should_panic_if_non_owner() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define season ID
    let season_id: u256 = 1;

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    // CREATE Season
    default_contract_create_season(contract);
    contract.pause_season(season_id);

    let is_paused = contract.is_season_paused(season_id);
    assert(is_paused, 'Season should be paused');

    let read_season = contract.read_season(season_id);
    assert(read_season.paused, 'Season should be paused');
    stop_cheat_caller_address(contract.contract_address);

    contract.resume_season(season_id);
}


#[test]
#[should_panic(expected: 'Season does not exist')]
fn test_resume_season_should_panic_if_season_doesnt_exist() {
    let (contract, _, _) = deploy_contract();

    // Define season ID
    let season_id: u256 = 1;

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    contract.pause_season(season_id);

    contract.resume_season(season_id);

    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season is not paused')]
fn test_resume_season_should_panic_if_season_is_not_paused() {
    let (contract, _, _) = deploy_contract();
    let mut spy = spy_events();

    // Define season ID
    let season_id: u256 = 1;

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    default_contract_create_season(contract);

    contract.resume_season(season_id);

    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season has already ended')]
fn test_resume_season_should_panic_if_season_is_ended() {
    let (contract, _, _) = deploy_contract();

    // Define season ID
    let season_id: u256 = 1;

    // Start prank to simulate the owner calling the contract
    start_cheat_caller_address(contract.contract_address, OWNER());

    default_contract_create_season(contract);

    start_cheat_block_timestamp(contract.contract_address, 1675123200 + 1);
    contract.pause_season(season_id);
    contract.resume_season(season_id);

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_submit_result_success() {
    let (contract, erc20) = feign_update_config(OWNER(), 1, 100);
    let artists = feign_artists_registration(1, erc20, 100, contract);

    let audition_id: u256 = 1;
    let (_, performer_id) = *artists.at(0);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.submit_result(audition_id, "result_uri", performer_id);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_submit_result_should_panic_if_non_owner() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let performer_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
    stop_cheat_caller_address(contract.contract_address);

    contract.submit_result(audition_id, "result_uri", performer_id);
}


#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_submit_result_should_panic_if_contract_paused() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    let performer_id = 0;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
    contract.pause_all();
    contract.submit_result(audition_id, "result_uri", performer_id);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season does not exist')]
fn test_submit_result_should_panic_if_season_doesnt_exist() {
    let (contract, erc20) = feign_update_config(OWNER(), 1, 100);
    let artists = feign_artists_registration(1, erc20, 100, contract);

    let audition_id: u256 = 2;
    let (_, performer_id) = *artists.at(0);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.submit_result(audition_id, "result_uri", performer_id);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Season is paused')]
fn test_submit_result_should_panic_if_season_is_paused() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    let performer_id = 0;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
    contract.pause_season(season_id);
    contract.submit_result(audition_id, "result_uri", performer_id);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Season has already ended')]
fn test_submit_result_should_panic_if_season_is_ended() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let performer_id: u256 = 1;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
    start_cheat_block_timestamp(contract.contract_address, 1675123200 + 1);
    contract.submit_result(audition_id, "result_uri", performer_id);
    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Performer is not enrolled')]
fn test_submit_result_should_panic_if_performer_not_enrolled() {
    let (contract, _, _) = deploy_contract();

    let audition_id: u256 = 1;
    let season_id: u256 = 1;
    let performer_id = 0;

    start_cheat_caller_address(contract.contract_address, OWNER());
    default_contract_create_season(contract);
    contract.create_audition('Summer Hits', Genre::Pop, 1675123200);
    contract.submit_result(audition_id, "result_uri", performer_id);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Performer already submitted')]
fn test_submit_result_should_panic_if_performer_already_submitted() {
    let (contract, erc20) = feign_update_config(OWNER(), 1, 100);
    let artists = feign_artists_registration(1, erc20, 100, contract);

    let audition_id: u256 = 1;
    let (_, performer_id) = *artists.at(0);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.submit_result(audition_id, "result_uri", performer_id);
    contract.submit_result(audition_id, "result_uri", performer_id);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_submit_result_success_events() {
    let (contract, erc20) = feign_update_config(OWNER(), 1, 100);
    let artists = feign_artists_registration(1, erc20, 100, contract);
    let (performer, performer_id) = *artists.at(0);

    let mut spy = spy_events();
    let audition_id: u256 = 1;
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.submit_result(audition_id, "result_uri", performer_id);
    stop_cheat_caller_address(contract.contract_address);

    let result = contract.get_result(audition_id, performer_id);
    assert(result == "result_uri", 'Result should be "result_uri"');

    let results = contract.get_results(audition_id);
    assert(results.len() == 1, 'Results should be 1');
    assert(results[0].clone() == "result_uri", 'Result  incorrect"');

    let performer_results = contract.get_performer_results(performer_id);
    assert(performer_results.len() == 1, 'Performer results should be 1');
    assert(performer_results[0].clone() == "result_uri", 'Result should be "result_uri"');

    spy
        .assert_emitted(
            @array![
                (
                    contract.contract_address,
                    SeasonAndAudition::Event::ResultSubmitted(
                        ResultSubmitted {
                            audition_id: audition_id, result_uri: "result_uri", performer,
                        },
                    ),
                ),
            ],
        );
}


#[test]
fn test_register_performer_generates_correct_performer_id() {
    let audition_id: u256 = 1;
    let (contract, erc20) = feign_update_config(OWNER(), audition_id, 100);
    let artists = feign_artists_registration(3, erc20, 100, contract);

    let (performer1, performer_id1) = *artists.at(0);
    let (performer2, performer_id2) = *artists.at(1);
    let (performer3, performer_id3) = *artists.at(2);

    assert(contract.get_performers_count() == 3, 'performer count should be 3');

    assert(
        contract.get_performer_address(audition_id, performer_id1) == performer1,
        'performer address should match',
    );
    assert(
        contract.get_performer_address(audition_id, performer_id2) == performer2,
        'performer address should match',
    );
    assert(
        contract.get_performer_address(audition_id, performer_id3) == performer3,
        'performer address should match',
    );
}
