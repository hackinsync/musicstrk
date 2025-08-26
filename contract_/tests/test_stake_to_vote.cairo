use contract_::audition::interfaces::istake_to_vote::{
    IStakeToVoteDispatcher, IStakeToVoteDispatcherTrait,
};
use contract_::audition::season_and_audition::{
    Audition, ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait, Season,
};
use core::num::traits::Zero;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress, get_block_timestamp};

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

fn WITHDRAWAL_CONTRACT() -> ContractAddress {
    'WITHDRAWAL_CONTRACT'.try_into().unwrap()
}

// Helper function to deploy the contract
fn deploy_season_and_audition_contract() -> ISeasonAndAuditionDispatcher {
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

    contract
}

fn deploy_mock_erc20_contract() -> IERC20Dispatcher {
    let erc20_class = declare("mock_erc20").unwrap().contract_class();
    let mut calldata = array![OWNER().into(), OWNER().into(), 6];
    let (erc20_address, _) = erc20_class.deploy(@calldata).unwrap();

    IERC20Dispatcher { contract_address: erc20_address }
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
        ended: false,
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

fn deploy_contracts() -> (ISeasonAndAuditionDispatcher, IStakeToVoteDispatcher) {
    let season_and_audition = deploy_season_and_audition_contract();

    // deploy stake to vote contract
    // 1. declare the contract
    let contract_class = declare("StakeToVote")
        .expect('Failed to declare contract')
        .contract_class();

    // 2. serialize constructor
    let mut calldata: Array<felt252> = array![];

    OWNER().serialize(ref calldata);
    season_and_audition.contract_address.serialize(ref calldata);

    // 3. deploy the contract
    let (contract_address, _) = contract_class
        .deploy(@calldata)
        .expect('Failed to deploy contract');

    let stake_to_vote = IStakeToVoteDispatcher { contract_address };

    (season_and_audition, stake_to_vote)
}

// Helper function to set up a standard environment for staking tests
fn setup_staking_audition() -> (
    ISeasonAndAuditionDispatcher, IStakeToVoteDispatcher, IERC20Dispatcher, felt252,
) {
    let (season_and_audition, stake_to_vote) = deploy_contracts();
    let mock_token = deploy_mock_erc20_contract();
    let audition_id: felt252 = 1;
    let season_id: felt252 = 1;

    // Create a new audition as the owner
    start_cheat_caller_address(season_and_audition.contract_address, OWNER());
    let default_season = create_default_season(season_id);
    season_and_audition
        .create_season(
            season_id,
            default_season.genre,
            default_season.name,
            default_season.start_timestamp,
            default_season.end_timestamp,
            default_season.paused,
        );
    let default_audition = create_default_audition(audition_id, season_id);
    season_and_audition
        .create_audition(
            audition_id,
            season_id,
            default_audition.genre,
            default_audition.name,
            default_audition.start_timestamp,
            // A future end timestamp to ensure it's not ended
            get_block_timestamp().into() + 1000,
            default_audition.paused,
        );
    stop_cheat_caller_address(season_and_audition.contract_address);

    start_cheat_caller_address(mock_token.contract_address, OWNER());
    // Mint some tokens to user for testing,
    mock_token.transfer(USER(), 1000000);
    stop_cheat_caller_address(mock_token.contract_address);

    (season_and_audition, stake_to_vote, mock_token, audition_id)
}

// staking to vote tests starts here
#[test]
fn test_owner_can_set_and_adjust_stake_amount() {
    let (_season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();

    // Owner sets the initial staking configuration
    start_cheat_caller_address(stake_to_vote.contract_address, OWNER());
    stake_to_vote.set_staking_config(audition_id, 100, mock_token.contract_address, 3600);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // Owner adjusts the staking configuration
    start_cheat_caller_address(stake_to_vote.contract_address, OWNER());
    stake_to_vote.set_staking_config(audition_id, 200, mock_token.contract_address, 7200);
    stop_cheat_caller_address(stake_to_vote.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_cannot_set_staking_config() {
    let (_season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();

    // Non-owner attempts to set the staking configuration
    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.set_staking_config(audition_id, 100, mock_token.contract_address, 3600);
    stop_cheat_caller_address(stake_to_vote.contract_address);
}

#[test]
#[should_panic(expected: 'Already staked')]
fn test_prevent_double_staking() {
    let (_season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();
    let stake_amount = 100_u256;

    // Configure staking
    start_cheat_caller_address(stake_to_vote.contract_address, OWNER());
    stake_to_vote.set_staking_config(audition_id, stake_amount, mock_token.contract_address, 0);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // User approves tokens
    start_cheat_caller_address(mock_token.contract_address, USER());
    mock_token.approve(stake_to_vote.contract_address, stake_amount * 2);
    stop_cheat_caller_address(mock_token.contract_address);

    // First stake (successful)
    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.stake_to_vote(audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // Second stake (should panic)
    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.stake_to_vote(audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);
}

#[test]
fn test_eligibility_tracking_and_stake_locking() {
    let (_season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();
    let stake_amount = 100_u256;

    // 1. Set config
    start_cheat_caller_address(stake_to_vote.contract_address, OWNER());
    stake_to_vote.set_staking_config(audition_id, stake_amount, mock_token.contract_address, 3600);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // 2. Check eligibility before staking
    assert!(!stake_to_vote.is_eligible_voter(audition_id, USER()), "Should not be eligible yet");

    // 3. Approve and stake
    start_cheat_caller_address(mock_token.contract_address, USER());
    mock_token.approve(stake_to_vote.contract_address, stake_amount);
    stop_cheat_caller_address(mock_token.contract_address);

    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.stake_to_vote(audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // 4. Check eligibility after staking
    assert!(stake_to_vote.is_eligible_voter(audition_id, USER()), "Should be eligible after stake");

    // 5. Verify staker info is recorded correctly
    let staker_info = stake_to_vote.get_staker_info(USER(), audition_id);
    assert!(staker_info.address == USER(), "Staker address should match");
    assert!(staker_info.staked_amount == stake_amount, "Staked amount should match");
    assert!(staker_info.is_eligible_voter, "Should be marked as eligible voter");
}

#[test]
fn test_get_staking_config() {
    let (_season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();
    let stake_amount = 100_u256;
    let withdrawal_delay = 3600_u64;

    // Set config
    start_cheat_caller_address(stake_to_vote.contract_address, OWNER());
    stake_to_vote.set_staking_config(audition_id, stake_amount, mock_token.contract_address, withdrawal_delay);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // Get and verify config
    let config = stake_to_vote.get_staking_config(audition_id);
    assert!(config.required_stake_amount == stake_amount, "Stake amount should match");
    assert!(config.stake_token == mock_token.contract_address, "Token address should match");
    assert!(config.withdrawal_delay_after_results == withdrawal_delay, "Delay should match");
}

#[test]
fn test_required_stake_amount() {
    let (_season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();
    let stake_amount = 100_u256;

    // Set config
    start_cheat_caller_address(stake_to_vote.contract_address, OWNER());
    stake_to_vote.set_staking_config(audition_id, stake_amount, mock_token.contract_address, 3600);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // Test required stake amount getter
    let required_amount = stake_to_vote.required_stake_amount(audition_id);
    assert!(required_amount == stake_amount, "Required stake amount should match");
}

#[test]
fn test_set_withdrawal_contract() {
    let (_season_and_audition, stake_to_vote, _mock_token, _audition_id) = setup_staking_audition();

    // Owner sets withdrawal contract
    start_cheat_caller_address(stake_to_vote.contract_address, OWNER());
    stake_to_vote.set_withdrawal_contract(WITHDRAWAL_CONTRACT());
    stop_cheat_caller_address(stake_to_vote.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_withdrawal_contract_unauthorized() {
    let (_season_and_audition, stake_to_vote, _mock_token, _audition_id) = setup_staking_audition();

    // Non-owner tries to set withdrawal contract
    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.set_withdrawal_contract(WITHDRAWAL_CONTRACT());
    stop_cheat_caller_address(stake_to_vote.contract_address);
}

#[test]
#[should_panic(expected: 'Only withdrawal contract')]
fn test_clear_staker_data_unauthorized() {
    let (_season_and_audition, stake_to_vote, _mock_token, audition_id) = setup_staking_audition();

    // Random user tries to clear staker data
    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.clear_staker_data(USER(), audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);
}

#[test]
fn test_clear_staker_data_authorized() {
    let (_season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();
    let stake_amount = 100_u256;

    // Set up staking config and withdrawal contract
    start_cheat_caller_address(stake_to_vote.contract_address, OWNER());
    stake_to_vote.set_staking_config(audition_id, stake_amount, mock_token.contract_address, 3600);
    stake_to_vote.set_withdrawal_contract(WITHDRAWAL_CONTRACT());
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // User stakes
    start_cheat_caller_address(mock_token.contract_address, USER());
    mock_token.approve(stake_to_vote.contract_address, stake_amount);
    stop_cheat_caller_address(mock_token.contract_address);

    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.stake_to_vote(audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // Verify staker is eligible before clearing
    assert!(stake_to_vote.is_eligible_voter(audition_id, USER()), "Should be eligible");

    // Authorized withdrawal contract clears staker data
    start_cheat_caller_address(stake_to_vote.contract_address, WITHDRAWAL_CONTRACT());
    stake_to_vote.clear_staker_data(USER(), audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // Verify staker is no longer eligible
    assert!(!stake_to_vote.is_eligible_voter(audition_id, USER()), "Should not be eligible after clearing");
}

#[test]
fn test_get_staker_info_empty() {
    let (_season_and_audition, stake_to_vote, _mock_token, audition_id) = setup_staking_audition();

    // Get staker info for non-staker
    let staker_info = stake_to_vote.get_staker_info(USER(), audition_id);
    assert!(staker_info.address.is_zero(), "Address should be zero");
    assert!(staker_info.staked_amount == 0, "Amount should be zero");
    assert!(!staker_info.is_eligible_voter, "Should not be eligible");
}
