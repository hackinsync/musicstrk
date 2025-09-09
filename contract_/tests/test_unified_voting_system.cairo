use contract_::audition::interfaces::iseason_and_audition::{
    ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait,
};
use contract_::audition::interfaces::istake_to_vote::{
    IStakeToVoteDispatcher, IStakeToVoteDispatcherTrait,
};
use contract_::audition::types::season_and_audition::{
    ArtistScore, Genre, UnifiedVote, VoteType, VotingConfig,
};
use contract_::events::{ArtistScoreUpdated, CelebrityJudgeSet, UnifiedVoteCast, VotingConfigSet};
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_block_timestamp, start_cheat_caller_address,
    stop_cheat_block_timestamp, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use crate::test_utils::{
    NON_OWNER, OWNER, USER, default_contract_create_audition, default_contract_create_season,
    deploy_contracts_with_staking,
};

// Test helper functions for addresses
fn JUDGE1() -> ContractAddress {
    'JUDGE1'.try_into().unwrap()
}

fn JUDGE2() -> ContractAddress {
    'JUDGE2'.try_into().unwrap()
}

fn CELEBRITY_JUDGE() -> ContractAddress {
    'CELEBRITY_JUDGE'.try_into().unwrap()
}

fn STAKER1() -> ContractAddress {
    'STAKER1'.try_into().unwrap()
}

fn STAKER2() -> ContractAddress {
    'STAKER2'.try_into().unwrap()
}

fn STAKER3() -> ContractAddress {
    'STAKER3'.try_into().unwrap()
}

// Test helper functions for IPFS hashes
fn IPFS_HASH_1() -> felt252 {
    'QmYjtig7VJQ6anUjqq'
}

fn IPFS_HASH_2() -> felt252 {
    'QmPK1s3pNYLi9ERsiq3'
}

fn IPFS_HASH_3() -> felt252 {
    'QmT78zSuBmHaJ56dDQa'
}

// Helper function to setup audition with participants
fn setup_audition_with_participants() -> (
    ISeasonAndAuditionDispatcher, IStakeToVoteDispatcher, u256,
) {
    let (audition_dispatcher, staking_dispatcher, _) = deploy_contracts_with_staking();

    start_cheat_caller_address(audition_dispatcher.contract_address, OWNER());
    start_cheat_caller_address(staking_dispatcher.contract_address, OWNER());

    // Create season and audition
    default_contract_create_season(audition_dispatcher);
    default_contract_create_audition(audition_dispatcher);

    let audition_id = 1_u256;

    // Add judges
    audition_dispatcher.add_judge(audition_id, JUDGE1());
    audition_dispatcher.add_judge(audition_id, JUDGE2());
    audition_dispatcher.add_judge(audition_id, CELEBRITY_JUDGE());

    // Set celebrity judge with higher weight
    audition_dispatcher.set_celebrity_judge(audition_id, CELEBRITY_JUDGE(), 200); // 2x multiplier

    // Set up staking configuration for the audition
    let stake_token_address = contract_address_const::<0x1234>();
    staking_dispatcher
        .set_staking_config(
            audition_id, 1000, stake_token_address, 86400,
        ); // 1 day withdrawal delay

    // Add eligible stakers by having them stake
    start_cheat_caller_address(staking_dispatcher.contract_address, STAKER1());
    staking_dispatcher.stake_to_vote(audition_id);

    start_cheat_caller_address(staking_dispatcher.contract_address, STAKER2());
    staking_dispatcher.stake_to_vote(audition_id);

    start_cheat_caller_address(staking_dispatcher.contract_address, STAKER3());
    staking_dispatcher.stake_to_vote(audition_id);

    stop_cheat_caller_address(audition_dispatcher.contract_address);
    stop_cheat_caller_address(staking_dispatcher.contract_address);

    (audition_dispatcher, staking_dispatcher, audition_id)
}

// TEST 1: Integration test with both judge and staker votes
#[test]
fn test_unified_voting_integration_judge_and_staker_votes() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();
    let mut spy = spy_events();

    let artist_id = 1_u256;

    // Test 1: Judge vote
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_1());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Verify judge vote was recorded
    let judge_vote = audition_dispatcher.get_unified_vote(audition_id, artist_id, JUDGE1());
    assert(judge_vote.voter == JUDGE1(), 'Wrong judge voter');
    assert(judge_vote.artist_id == artist_id, 'Wrong artist ID');
    assert(judge_vote.audition_id == audition_id, 'Wrong audition ID');
    assert(judge_vote.weight == 1000, 'Wrong judge weight'); // Default judge weight
    assert(judge_vote.vote_type == VoteType::Judge, 'Wrong vote type');
    assert(judge_vote.ipfs_content_hash == IPFS_HASH_1(), 'Wrong IPFS hash');

    // Test 2: Staker vote
    start_cheat_caller_address(audition_dispatcher.contract_address, STAKER1());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_2());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Verify staker vote was recorded
    let staker_vote = audition_dispatcher.get_unified_vote(audition_id, artist_id, STAKER1());
    assert(staker_vote.voter == STAKER1(), 'Wrong staker voter');
    assert(staker_vote.artist_id == artist_id, 'Wrong artist ID');
    assert(staker_vote.weight == 50, 'Wrong staker weight'); // Default staker weight
    assert(staker_vote.vote_type == VoteType::Staker, 'Wrong vote type');
    assert(staker_vote.ipfs_content_hash == IPFS_HASH_2(), 'Wrong IPFS hash');

    // Test 3: Celebrity judge vote with higher weight
    let artist_id_2 = 2_u256;
    start_cheat_caller_address(audition_dispatcher.contract_address, CELEBRITY_JUDGE());
    audition_dispatcher.cast_vote(audition_id, artist_id_2, IPFS_HASH_3());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Verify celebrity judge vote
    let celebrity_vote = audition_dispatcher
        .get_unified_vote(audition_id, artist_id_2, CELEBRITY_JUDGE());
    assert(celebrity_vote.weight == 2000, 'Wrong celebrity weight'); // 1000 * 2.0 multiplier
    assert(celebrity_vote.vote_type == VoteType::Judge, 'Wrong celebrity vote type');

    // Verify events were emitted
    spy
        .assert_emitted(
            @array![
                (
                    audition_dispatcher.contract_address,
                    UnifiedVoteCast {
                        audition_id,
                        artist_id,
                        voter: JUDGE1(),
                        weight: 1000,
                        vote_type: VoteType::Judge,
                        ipfs_content_hash: IPFS_HASH_1(),
                        timestamp: get_block_timestamp(),
                    },
                ),
            ],
        );
}

// TEST 2: Automatic role detection accuracy
#[test]
fn test_automatic_role_detection_accuracy() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    let artist_id = 1_u256;

    // Test 1: Regular judge detection
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_1());
    let vote = audition_dispatcher.get_unified_vote(audition_id, artist_id, JUDGE1());
    assert(vote.vote_type == VoteType::Judge, 'Should detect judge');
    assert(vote.weight == 1000, 'Wrong judge weight');
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Test 2: Celebrity judge detection (higher weight)
    start_cheat_caller_address(audition_dispatcher.contract_address, CELEBRITY_JUDGE());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_2());
    let celebrity_vote = audition_dispatcher
        .get_unified_vote(audition_id, artist_id, CELEBRITY_JUDGE());
    assert(celebrity_vote.vote_type == VoteType::Judge, 'Should detect celebrity judge');
    assert(celebrity_vote.weight == 2000, 'Wrong celebrity weight'); // 1000 * 2.0
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Test 3: Staker detection
    start_cheat_caller_address(audition_dispatcher.contract_address, STAKER1());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_3());
    let staker_vote = audition_dispatcher.get_unified_vote(audition_id, artist_id, STAKER1());
    assert(staker_vote.vote_type == VoteType::Staker, 'Should detect staker');
    assert(staker_vote.weight == 50, 'Wrong staker weight');
    stop_cheat_caller_address(audition_dispatcher.contract_address);
}

// TEST 3: Test ineligible user cannot vote
#[test]
#[should_panic(expected: ('Not eligible to vote',))]
fn test_automatic_role_detection_ineligible_user() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    // Try to vote as a user who is neither judge nor staker
    start_cheat_caller_address(audition_dispatcher.contract_address, NON_OWNER());
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_1());
}

// TEST 4: Double voting prevention
#[test]
#[should_panic(expected: ('Already voted for this artist',))]
fn test_double_voting_prevention() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    let artist_id = 1_u256;

    // First vote should succeed
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_1());

    // Second vote for same artist should fail
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_2());
}

// TEST 5: Double voting prevention - different artists allowed
#[test]
fn test_double_voting_prevention_different_artists() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());

    // Should be able to vote for different artists
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_1());
    audition_dispatcher.cast_vote(audition_id, 2_u256, IPFS_HASH_2());
    audition_dispatcher.cast_vote(audition_id, 3_u256, IPFS_HASH_3());

    // Verify all votes were recorded
    let vote1 = audition_dispatcher.get_unified_vote(audition_id, 1_u256, JUDGE1());
    let vote2 = audition_dispatcher.get_unified_vote(audition_id, 2_u256, JUDGE1());
    let vote3 = audition_dispatcher.get_unified_vote(audition_id, 3_u256, JUDGE1());

    assert(vote1.artist_id == 1_u256, 'Vote 1 not recorded');
    assert(vote2.artist_id == 2_u256, 'Vote 2 not recorded');
    assert(vote3.artist_id == 3_u256, 'Vote 3 not recorded');

    stop_cheat_caller_address(audition_dispatcher.contract_address);
}

// TEST 6: Real-time score updates
#[test]
fn test_real_time_score_updates() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();
    let mut spy = spy_events();

    let artist_id = 1_u256;

    // Initial score should be zero
    let initial_score = audition_dispatcher.get_artist_score(audition_id, artist_id);
    assert(initial_score.total_score == 0, 'Initial score should be 0');
    assert(initial_score.judge_votes == 0, 'Initial judge votes = 0');
    assert(initial_score.staker_votes == 0, 'Initial staker votes = 0');

    // Judge vote should update score
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_1());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    let score_after_judge = audition_dispatcher.get_artist_score(audition_id, artist_id);
    assert(score_after_judge.total_score == 1000, 'Score should be 1000');
    assert(score_after_judge.judge_votes == 1, 'Judge votes should be 1');
    assert(score_after_judge.staker_votes == 0, 'Staker votes should be 0');
    assert(score_after_judge.artist_id == artist_id, 'Wrong artist ID');

    // Staker vote should add to score
    start_cheat_caller_address(audition_dispatcher.contract_address, STAKER1());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_2());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    let score_after_staker = audition_dispatcher.get_artist_score(audition_id, artist_id);
    assert(score_after_staker.total_score == 1050, 'Score should be 1050'); // 1000 + 50
    assert(score_after_staker.judge_votes == 1, 'Judge votes should be 1');
    assert(score_after_staker.staker_votes == 1, 'Staker votes should be 1');

    // Celebrity judge vote should add higher weight
    start_cheat_caller_address(audition_dispatcher.contract_address, CELEBRITY_JUDGE());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_3());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    let score_after_celebrity = audition_dispatcher.get_artist_score(audition_id, artist_id);
    assert(score_after_celebrity.total_score == 3050, 'Score should be 3050'); // 1050 + 2000
    assert(score_after_celebrity.judge_votes == 2, 'Judge votes should be 2');
    assert(score_after_celebrity.staker_votes == 1, 'Staker votes should be 1');

    // Verify score timestamp was updated
    assert(score_after_celebrity.last_updated > 0, 'Score timestamp should be set');
}

// TEST 7: IPFS hash integration
#[test]
fn test_ipfs_hash_integration() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    let artist_id = 1_u256;

    // Test different IPFS hashes are properly stored
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_1());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE2());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_2());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    start_cheat_caller_address(audition_dispatcher.contract_address, STAKER1());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_3());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Verify IPFS hashes are correctly stored
    let vote1 = audition_dispatcher.get_unified_vote(audition_id, artist_id, JUDGE1());
    let vote2 = audition_dispatcher.get_unified_vote(audition_id, artist_id, JUDGE2());
    let vote3 = audition_dispatcher.get_unified_vote(audition_id, artist_id, STAKER1());

    assert(vote1.ipfs_content_hash == IPFS_HASH_1(), 'Wrong IPFS hash 1');
    assert(vote2.ipfs_content_hash == IPFS_HASH_2(), 'Wrong IPFS hash 2');
    assert(vote3.ipfs_content_hash == IPFS_HASH_3(), 'Wrong IPFS hash 3');
}

// TEST 8: Voting window enforcement with custom config
#[test]
fn test_voting_window_enforcement_custom_config() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    start_cheat_caller_address(audition_dispatcher.contract_address, OWNER());

    let current_time = get_block_timestamp();
    let voting_start = current_time + 100;
    let voting_end = current_time + 200;

    // Set custom voting window
    let voting_config = VotingConfig {
        voting_start_time: voting_start,
        voting_end_time: voting_end,
        staker_base_weight: 75,
        judge_base_weight: 1500,
        celebrity_weight_multiplier: 250,
    };

    audition_dispatcher.set_voting_config(audition_id, voting_config);
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Test voting before window opens
    assert(!audition_dispatcher.is_voting_active(audition_id), 'Voting should not be active');

    // Move to voting window
    start_cheat_block_timestamp(audition_dispatcher.contract_address, voting_start + 10);
    assert(audition_dispatcher.is_voting_active(audition_id), 'Voting should be active');

    // Test successful vote during window
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_1());

    // Verify custom weights are applied
    let vote = audition_dispatcher.get_unified_vote(audition_id, 1_u256, JUDGE1());
    assert(vote.weight == 1500, 'Wrong custom judge weight');
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Move past voting window
    start_cheat_block_timestamp(audition_dispatcher.contract_address, voting_end + 10);
    assert(!audition_dispatcher.is_voting_active(audition_id), 'Voting should not be active');

    stop_cheat_block_timestamp(audition_dispatcher.contract_address);
}

// TEST 9: Voting before window opens (should fail)
#[test]
#[should_panic(expected: ('Voting is not active',))]
fn test_voting_window_enforcement_before_window() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    start_cheat_caller_address(audition_dispatcher.contract_address, OWNER());

    let current_time = get_block_timestamp();
    let voting_start = current_time + 100;
    let voting_end = current_time + 200;

    let voting_config = VotingConfig {
        voting_start_time: voting_start,
        voting_end_time: voting_end,
        staker_base_weight: 50,
        judge_base_weight: 1000,
        celebrity_weight_multiplier: 150,
    };

    audition_dispatcher.set_voting_config(audition_id, voting_config);
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Try to vote before window opens (should fail)
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_1());
}

// TEST 10: Staking contract integration
#[test]
fn test_staking_contract_integration() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    // Test that stakers can vote
    start_cheat_caller_address(audition_dispatcher.contract_address, STAKER1());
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_1());

    let vote = audition_dispatcher.get_unified_vote(audition_id, 1_u256, STAKER1());
    assert(vote.vote_type == VoteType::Staker, 'Should be staker vote');
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Test that multiple stakers can vote
    start_cheat_caller_address(audition_dispatcher.contract_address, STAKER2());
    audition_dispatcher.cast_vote(audition_id, 2_u256, IPFS_HASH_2());

    let vote2 = audition_dispatcher.get_unified_vote(audition_id, 2_u256, STAKER2());
    assert(vote2.vote_type == VoteType::Staker, 'Should be staker vote 2');
    stop_cheat_caller_address(audition_dispatcher.contract_address);
}

// TEST 11: Comprehensive event emission
#[test]
fn test_comprehensive_event_emission() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();
    let mut spy = spy_events();

    let current_time = get_block_timestamp();
    let artist_id = 1_u256;

    // Test UnifiedVoteCast event
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, artist_id, IPFS_HASH_1());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Verify at least the voting event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    audition_dispatcher.contract_address,
                    UnifiedVoteCast {
                        audition_id,
                        artist_id,
                        voter: JUDGE1(),
                        weight: 1000,
                        vote_type: VoteType::Judge,
                        ipfs_content_hash: IPFS_HASH_1(),
                        timestamp: current_time,
                    },
                ),
            ],
        );
}

// TEST 12: Edge case - nonexistent audition
#[test]
#[should_panic(expected: ('Audition does not exist',))]
fn test_edge_case_nonexistent_audition() {
    let (audition_dispatcher, _staking_dispatcher, _audition_id) =
        setup_audition_with_participants();

    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(999_u256, 1_u256, IPFS_HASH_1()); // Nonexistent audition
}

// TEST 13: Edge case - paused audition
#[test]
#[should_panic(expected: ('Audition is paused',))]
fn test_edge_case_paused_audition() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    // Pause the audition
    start_cheat_caller_address(audition_dispatcher.contract_address, OWNER());
    audition_dispatcher.pause_audition(audition_id);
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Try to vote on paused audition
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_1());
}

// TEST 14: Edge case - global pause
#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_edge_case_global_pause() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    // Pause the entire contract
    start_cheat_caller_address(audition_dispatcher.contract_address, OWNER());
    audition_dispatcher.pause_all();
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Try to vote when globally paused
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_1());
}

// TEST 15: Edge case - ended audition
#[test]
#[should_panic(expected: ('Voting is not active',))]
fn test_edge_case_ended_audition() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    // End the audition
    start_cheat_caller_address(audition_dispatcher.contract_address, OWNER());
    audition_dispatcher.end_audition(audition_id);
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Try to vote on ended audition
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_1());
}

// TEST 16: Edge case - zero artist ID (should work)
#[test]
fn test_edge_case_zero_artist_id() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    // Should be able to vote for artist with ID 0
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, 0_u256, IPFS_HASH_1());

    let vote = audition_dispatcher.get_unified_vote(audition_id, 0_u256, JUDGE1());
    assert(vote.artist_id == 0_u256, 'Should accept zero artist ID');
    stop_cheat_caller_address(audition_dispatcher.contract_address);
}

// TEST 17: Complex scenario with multiple artists and voters
#[test]
fn test_complex_scenario_multiple_artists_and_voters() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    // Artist 1: Gets votes from 1 judge, 1 celebrity judge, 2 stakers
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE1());
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_1());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    start_cheat_caller_address(audition_dispatcher.contract_address, CELEBRITY_JUDGE());
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_2());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    start_cheat_caller_address(audition_dispatcher.contract_address, STAKER1());
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_3());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    start_cheat_caller_address(audition_dispatcher.contract_address, STAKER2());
    audition_dispatcher.cast_vote(audition_id, 1_u256, IPFS_HASH_1());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Artist 2: Gets votes from 1 judge, 1 staker
    start_cheat_caller_address(audition_dispatcher.contract_address, JUDGE2());
    audition_dispatcher.cast_vote(audition_id, 2_u256, IPFS_HASH_2());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    start_cheat_caller_address(audition_dispatcher.contract_address, STAKER3());
    audition_dispatcher.cast_vote(audition_id, 2_u256, IPFS_HASH_3());
    stop_cheat_caller_address(audition_dispatcher.contract_address);

    // Verify scores
    let score1 = audition_dispatcher.get_artist_score(audition_id, 1_u256);
    let score2 = audition_dispatcher.get_artist_score(audition_id, 2_u256);

    // Artist 1: 1000 (judge) + 2000 (celebrity) + 50 (staker1) + 50 (staker2) = 3100
    assert(score1.total_score == 3100, 'Wrong Artist1 total score');
    assert(score1.judge_votes == 2, 'Wrong Artist1 judge votes');
    assert(score1.staker_votes == 2, 'Wrong Artist1 staker votes');

    // Artist 2: 1000 (judge) + 50 (staker) = 1050
    assert(score2.total_score == 1050, 'Wrong Artist2 total score');
    assert(score2.judge_votes == 1, 'Wrong Artist2 judge votes');
    assert(score2.staker_votes == 1, 'Wrong Artist2 staker votes');
}

// TEST 18: Voting config persistence
#[test]
fn test_voting_config_persistence() {
    let (audition_dispatcher, _staking_dispatcher, audition_id) =
        setup_audition_with_participants();

    start_cheat_caller_address(audition_dispatcher.contract_address, OWNER());

    // Set custom config
    let custom_config = VotingConfig {
        voting_start_time: 1000,
        voting_end_time: 2000,
        staker_base_weight: 75,
        judge_base_weight: 1500,
        celebrity_weight_multiplier: 250,
    };

    audition_dispatcher.set_voting_config(audition_id, custom_config);

    // Retrieve and verify config persisted
    let retrieved_config = audition_dispatcher.get_voting_config(audition_id);
    assert(retrieved_config.voting_start_time == 1000, 'Wrong start time');
    assert(retrieved_config.voting_end_time == 2000, 'Wrong end time');
    assert(retrieved_config.staker_base_weight == 75, 'Wrong staker weight');
    assert(retrieved_config.judge_base_weight == 1500, 'Wrong judge weight');
    assert(retrieved_config.celebrity_weight_multiplier == 250, 'Wrong celebrity multiplier');

    stop_cheat_caller_address(audition_dispatcher.contract_address);
}
