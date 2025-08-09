use contract_::audition::interfaces::istake_to_vote::{
    IStakeToVoteDispatcher, IStakeToVoteDispatcherTrait,
};
use contract_::audition::season_and_audition::{
    Audition, ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait,
    ISeasonAndAuditionSafeDispatcher, ISeasonAndAuditionSafeDispatcherTrait, Season,
    SeasonAndAudition,
};
use contract_::events::{
    AuditionCreated, AuditionDeleted, AuditionEnded, AuditionPaused, AuditionResumed,
    AuditionUpdated, PriceDeposited, PriceDistributed, SeasonCreated, SeasonDeleted, SeasonUpdated,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_block_timestamp,
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
            default_season.genre,
            default_season.name,
            default_season.end_timestamp,
        );
    let default_audition = create_default_audition(audition_id, season_id);
    season_and_audition
        .create_audition(
            season_id,
            default_audition.genre,
            default_audition.name,
            // A future end timestamp to ensure it's not ended
            get_block_timestamp().into() + 1000,
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
    let (season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();

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
    let (season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();

    // Non-owner attempts to set the staking configuration
    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.set_staking_config(audition_id, 100, mock_token.contract_address, 3600);
    stop_cheat_caller_address(stake_to_vote.contract_address);
}

#[test]
#[should_panic(expected: 'Already staked')]
fn test_prevent_double_staking() {
    let (season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();
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
    let (season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();
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
}

#[test]
#[should_panic(expected: 'Audition not yet ended')]
fn test_stake_is_locked_before_results() {
    let (season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();
    let stake_amount = 100_u256;

    // Set config
    start_cheat_caller_address(stake_to_vote.contract_address, OWNER());
    stake_to_vote.set_staking_config(audition_id, stake_amount, mock_token.contract_address, 3600);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // Approve and stake
    start_cheat_caller_address(mock_token.contract_address, USER());
    mock_token.approve(stake_to_vote.contract_address, stake_amount);
    stop_cheat_caller_address(mock_token.contract_address);

    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.stake_to_vote(audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // Attempt to withdraw before audition has ended
    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.withdraw_stake_after_results(audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);
}

#[test]
fn test_successful_withdrawal_after_results() {
    let (season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();
    let stake_amount = 100_u256;
    let withdrawal_delay = 3600_u64;

    // Set config
    start_cheat_caller_address(stake_to_vote.contract_address, OWNER());
    stake_to_vote
        .set_staking_config(
            audition_id, stake_amount, mock_token.contract_address, withdrawal_delay,
        );
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // User approves and stakes
    start_cheat_caller_address(mock_token.contract_address, USER());
    mock_token.approve(stake_to_vote.contract_address, stake_amount);
    stop_cheat_caller_address(mock_token.contract_address);

    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.stake_to_vote(audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    let user_balance_before_withdrawal = mock_token.balance_of(USER().into());

    // Owner ends the audition
    start_cheat_caller_address(season_and_audition.contract_address, OWNER());
    // set block timestamp to non zero, it's zero by default
    start_cheat_block_timestamp(season_and_audition.contract_address, 1);
    season_and_audition.end_audition(audition_id);

    // Advance time past the withdrawal delay
    let audition_end_time = get_block_timestamp();
    start_cheat_block_timestamp(
        stake_to_vote.contract_address, audition_end_time + withdrawal_delay + 1,
    );
    stop_cheat_caller_address(season_and_audition.contract_address);

    // User withdraws stake
    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.withdraw_stake_after_results(audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);

    // Assertions
    let user_balance_after_withdrawal = mock_token.balance_of(USER().into());
    assert!(
        user_balance_after_withdrawal == user_balance_before_withdrawal + stake_amount,
        "User balance not refunded",
    );
    assert!(!stake_to_vote.is_eligible_voter(audition_id, USER()), "Eligibility should be revoked");
}

#[test]
#[should_panic(expected: 'No stake to withdraw')]
fn test_failed_withdrawal_if_not_staked() {
    let (season_and_audition, stake_to_vote, mock_token, audition_id) = setup_staking_audition();

    // Set config
    start_cheat_caller_address(stake_to_vote.contract_address, OWNER());
    start_cheat_caller_address(season_and_audition.contract_address, OWNER());
    stake_to_vote.set_staking_config(audition_id, 100, mock_token.contract_address, 0);
    // End the audition immediately for testing withdrawal
    season_and_audition.end_audition(audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);
    stop_cheat_caller_address(season_and_audition.contract_address);

    // A user who never staked tries to withdraw
    start_cheat_caller_address(stake_to_vote.contract_address, USER());
    stake_to_vote.withdraw_stake_after_results(audition_id);
    stop_cheat_caller_address(stake_to_vote.contract_address);
}
