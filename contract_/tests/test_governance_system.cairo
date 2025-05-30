use contract_::erc20::{IMusicShareTokenDispatcher, IMusicShareTokenDispatcherTrait, MusicStrk};
use contract_::token_factory::{
    IMusicShareTokenFactoryDispatcher, IMusicShareTokenFactoryDispatcherTrait,
    MusicShareTokenFactory,
};
use contract_::governance::{
    ProposalSystem::{
        IProposalSystemDispatcher, IProposalSystemDispatcherTrait, ProposalSystem},
    VotingMechanism::{
        IVotingMechanismDispatcher, IVotingMechanismDispatcherTrait, VotingMechanism},
    types::{Proposal, ProposalMetrics, Comment, VoteType, Vote, VoteBreakdown},
};
use core::array::ArrayTrait;
use core::result::ResultTrait;
use core::traits::Into;
use openzeppelin::token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::{class_hash::ClassHash, ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_caller_address, cheat_block_timestamp_global, declare, spy_events,
};

// Address constants for testing
fn ARTIST_1() -> ContractAddress {
    contract_address_const::<'artist_1'>()
}

fn ARTIST_2() -> ContractAddress {
    contract_address_const::<'artist_2'>()
}

fn SHAREHOLDER_1() -> ContractAddress {
    contract_address_const::<'shareholder_1'>()
}

fn SHAREHOLDER_2() -> ContractAddress {
    contract_address_const::<'shareholder_2'>()
}

fn SHAREHOLDER_3() -> ContractAddress {
    contract_address_const::<'shareholder_3'>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn ZERO_ADDRESS() -> ContractAddress {
    contract_address_const::<0>()
}

const TOTAL_SHARES: u256 = 100_u256;
const DEFAULT_VOTING_PERIOD: u64 = 604800_u64; // 7 days in seconds
const MIN_THRESHOLD_PERCENTAGE: u8 = 3_u8; // 3% minimum threshold

/// Helper function to deploy a music token for testing
fn deploy_music_token_for_test(artist: ContractAddress) -> ContractAddress {
    let contract_class = declare("MusicStrk").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(artist);
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

/// Helper function to deploy the token factory
fn deploy_token_factory(owner: ContractAddress) -> IMusicShareTokenFactoryDispatcher {
    let _music_token_address = deploy_music_token_for_test(owner);
    let music_token_class = declare("MusicStrk").unwrap().contract_class();
    let music_token_class_hash = music_token_class.class_hash;

    let factory_class = declare("MusicShareTokenFactory").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(owner.into());
    calldata.append((*music_token_class_hash).into());
    let (factory_address, _) = factory_class.deploy(@calldata).unwrap();
    IMusicShareTokenFactoryDispatcher { contract_address: factory_address }
}

/// Helper function to deploy ProposalSystem
fn deploy_proposal_system(
    factory_contract: ContractAddress, min_threshold: u8,
) -> IProposalSystemDispatcher {
    let contract_class = declare("ProposalSystem").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(factory_contract);
    calldata.append_serde(min_threshold);
    let (_contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IProposalSystemDispatcher { contract_address: _contract_address }
}

/// Helper function to deploy VotingMechanism
fn deploy_voting_mechanism(
    proposal_system: ContractAddress, voting_period: u64,
) -> IVotingMechanismDispatcher {
    let contract_class = declare("VotingMechanism").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(proposal_system);
    calldata.append_serde(voting_period);
    let (_contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IVotingMechanismDispatcher { contract_address: _contract_address }
}

/// Setup complete governance environment
fn setup_governance_environment() -> (
    ContractAddress,
    ContractAddress,
    IProposalSystemDispatcher,
    IVotingMechanismDispatcher,
    IERC20MixinDispatcher,
) {
    let owner = OWNER();
    let artist = ARTIST_1();

    // Deploy factory and create a token
    let factory = deploy_token_factory(owner);

    // Grant artist role and deploy token
    cheat_caller_address(factory.contract_address, owner, CheatSpan::TargetCalls(1));
    factory.grant_artist_role(artist);

    cheat_caller_address(factory.contract_address, artist, CheatSpan::TargetCalls(1));
    let token_address = factory
        .deploy_music_token("Test Album", "TA", 6_u8, "ipfs://test-metadata");

    // Deploy governance contracts
    let proposal_system = deploy_proposal_system(
        factory.contract_address, MIN_THRESHOLD_PERCENTAGE,
    );

    let voting_mechanism = deploy_voting_mechanism(
        proposal_system.contract_address, DEFAULT_VOTING_PERIOD,
    );

    // Register artist in proposal system
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system.register_artist(token_address, artist);

    let token = IERC20MixinDispatcher { contract_address: token_address };

    (token_address, artist, proposal_system, voting_mechanism, token)
}

#[test]
fn test_proposal_submission() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Transfer some tokens to shareholder to meet threshold
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 10_u256); // 10% of total supply

    // Shareholder submits a proposal
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));

    let proposal_id = proposal_system
        .submit_proposal(
            token_address,
            "Revenue Distribution Proposal",
            "Proposal to distribute 50% of revenue to token holders",
            'REVENUE',
        );

    // Verify proposal was created
    assert(proposal_id == 1, 'Proposal ID should be 1');

    let proposal = proposal_system.get_proposal(proposal_id);
    assert(proposal.proposer == shareholder, 'Proposer mismatch');
    assert(proposal.status == 0, 'Status should be Pending');
    assert(proposal.token_contract == token_address, 'Token contract mismatch');
}

#[test]
fn test_artist_response_to_proposal() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Transfer tokens and submit proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(
            token_address, "Marketing Campaign", "Proposal for new marketing campaign", 'MARKETING',
        );

    // Artist responds to proposal
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system
        .respond_to_proposal(
            proposal_id, 1, // Approved
            "I approve this marketing campaign proposal",
        );

    // Verify response
    let proposal = proposal_system.get_proposal(proposal_id);
    assert(proposal.status == 1, 'Status should be Approved');
}

#[test]
fn test_voting_mechanism() {
    let (token_address, artist, proposal_system, voting_mechanism, token) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();

    // Distribute tokens to shareholders
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    token.transfer(shareholder1, 30_u256);
    token.transfer(shareholder2, 20_u256);

    // Create proposal
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(
            token_address, "Creative Direction", "Proposal for new creative direction", 'CREATIVE',
        );

    // Shareholders vote
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    let weight1 = voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    cheat_caller_address(
        voting_mechanism.contract_address, shareholder2, CheatSpan::TargetCalls(1),
    );
    let weight2 = voting_mechanism.cast_vote(proposal_id, VoteType::Against, token_address);

    // Verify voting weights
    assert(weight1 == 30_u256, 'Voting weight 1 mismatch');
    assert(weight2 == 20_u256, 'Voting weight 2 mismatch');

    // Check vote breakdown
    let breakdown = voting_mechanism.get_vote_breakdown(proposal_id);
    assert(breakdown.votes_for == 30_u256, 'For votes mismatch');
    assert(breakdown.votes_against == 20_u256, 'Against votes mismatch');
    assert(breakdown.total_voters == 2, 'Total voters mismatch');
}

#[test]
fn test_comment_system() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(
            token_address, "Community Proposal", "A proposal for community discussion", 'OTHER',
        );

    // Add comments
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    proposal_system.add_comment(proposal_id, "This is a great proposal!");

    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system.add_comment(proposal_id, "I appreciate the feedback");

    // Verify comments
    let comments = proposal_system.get_comments(proposal_id, 0, 10);
    assert(comments.len() == 2, 'Should have 2 comments');

    let metrics = proposal_system.get_proposal_metrics(proposal_id);
    assert(metrics.comment_count == 2, 'Comment count should be 2');
}

#[test]
fn test_vote_delegation() {
    let (token_address, artist, proposal_system, voting_mechanism, token) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();

    // Setup tokens and proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    token.transfer(shareholder1, 25_u256);
    token.transfer(shareholder2, 25_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Delegation Test", "Testing vote delegation", 'OTHER');

    // Shareholder1 delegates to shareholder2
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.delegate_vote(shareholder2);

    // Shareholder2 votes (should include delegated weight)
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder2, CheatSpan::TargetCalls(1),
    );
    let weight = voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    // Weight should be shareholder2's tokens (25) since delegation affects the delegate's balance
    assert(weight == 25_u256, 'Delegated weight incorrect');
}

#[test]
fn test_proposal_filtering() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 15_u256);

    // Create multiple proposals with different categories
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(3));

    proposal_system
        .submit_proposal(
            token_address, "Revenue Proposal", "Revenue distribution proposal", 'REVENUE',
        );

    proposal_system
        .submit_proposal(
            token_address, "Marketing Proposal", "Marketing campaign proposal", 'MARKETING',
        );

    proposal_system
        .submit_proposal(
            token_address, "Creative Proposal", "Creative direction proposal", 'CREATIVE',
        );

    // Test filtering by category
    let revenue_proposals = proposal_system
        .get_proposals(
            ZERO_ADDRESS(), // All tokens
            255, // All statuses
            'REVENUE', 0, // page
            10 // limit
        );
    assert(revenue_proposals.len() == 1, 'Should have 1 revenue proposal');

    let all_proposals = proposal_system
        .get_proposals(token_address, 255, // All statuses
        'ALL', 0, // page
        10 // limit
        );
    assert(all_proposals.len() == 3, 'Should have 3 total proposals');
}

#[test]
#[should_panic(expected: ('Insufficient token balance',))]
fn test_insufficient_threshold_proposal_fails() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Transfer only 1 token (less than 3% threshold)
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 1_u256);

    // Should fail due to insufficient balance
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    proposal_system.submit_proposal(token_address, "Invalid Proposal", "This should fail", 'OTHER');
}

#[test]
fn test_proposal_system_initialization() {
    let owner = OWNER();
    let factory = deploy_token_factory(owner);
    
    let proposal_system = deploy_proposal_system(factory.contract_address, MIN_THRESHOLD_PERCENTAGE);
    
    // Test initial state
    assert(proposal_system.get_total_proposals() == 0, 'Should start with 0 proposals');
    assert(proposal_system.get_minimum_threshold() == MIN_THRESHOLD_PERCENTAGE, 'Threshold mismatch');
    
    // Test empty arrays
    let all_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'ALL', 0, 10);
    assert(all_proposals.len() == 0, 'Should have no proposals initially');
}

#[test]
fn test_voting_mechanism_initialization() {
    let owner = OWNER();
    let factory = deploy_token_factory(owner);
    let proposal_system = deploy_proposal_system(factory.contract_address, MIN_THRESHOLD_PERCENTAGE);
    
    let voting_mechanism = deploy_voting_mechanism(proposal_system.contract_address, DEFAULT_VOTING_PERIOD);
    
    // Test initial voting state for non-existent proposal
    let breakdown = voting_mechanism.get_vote_breakdown(1);
    assert(breakdown.votes_for == 0, 'Should start with 0 for votes');
    assert(breakdown.votes_against == 0, 'Should start with 0 against votes');
    assert(breakdown.votes_abstain == 0, 'Should start with 0 abstain votes');
    assert(breakdown.total_voters == 0, 'Should start with 0 voters');
}

#[test]
fn test_proposal_events() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 10_u256);
    
    let mut spy = spy_events();
    
    // Submit proposal
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(
        token_address,
        "Test Proposal",
        "Test Description",
        'REVENUE'
    );
    
    // Check ProposalCreated event
    spy.assert_emitted(
        @array![
            (
                proposal_system.contract_address,
                ProposalSystem::Event::ProposalCreated(
                    ProposalSystem::ProposalCreated {
                        proposal_id,
                        token_contract: token_address,
                        proposer: shareholder,
                        category: 'REVENUE',
                        title: "Test Proposal"
                    }
                )
            )
        ]
    );
    
    // Test artist response event
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system.respond_to_proposal(proposal_id, 1, "Approved");
    
    // Check ProposalStatusChanged event
    spy.assert_emitted(
        @array![
            (
                proposal_system.contract_address,
                ProposalSystem::Event::ProposalStatusChanged(
                    ProposalSystem::ProposalStatusChanged {
                        proposal_id,
                        old_status: 0,
                        new_status: 1,
                        responder: artist
                    }
                )
            )
        ]
    );
}

#[test]
fn test_voting_events() {
    let (token_address, artist, proposal_system, voting_mechanism, token) = setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();
    
    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    token.transfer(shareholder1, 30_u256);
    token.transfer(shareholder2, 20_u256);
    
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "Vote Test", "Testing votes", 'OTHER');
    
    let mut spy = spy_events();
    
    // Test voting events
    cheat_caller_address(voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
    
    spy.assert_emitted(
        @array![
            (
                voting_mechanism.contract_address,
                VotingMechanism::Event::VoteCast(
                    VotingMechanism::VoteCast {
                        proposal_id,
                        voter: shareholder1,
                        vote_type: VoteType::For,
                        weight: 30_u256
                    }
                )
            )
        ]
    );
    
    // Test delegation events
    cheat_caller_address(voting_mechanism.contract_address, shareholder2, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(shareholder1);
    
    spy.assert_emitted(
        @array![
            (
                voting_mechanism.contract_address,
                VotingMechanism::Event::VoteDelegated(
                    VotingMechanism::VoteDelegated {
                        delegator: shareholder2,
                        delegate: shareholder1
                    }
                )
            )
        ]
    );
}

#[test]
fn test_comment_events() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 10_u256);
    
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "Comment Test", "Testing comments", 'OTHER');
    
    let mut spy = spy_events();
    
    // Add comment
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    proposal_system.add_comment(proposal_id, "Great proposal!");
    
    spy.assert_emitted(
        @array![
            (
                proposal_system.contract_address,
                ProposalSystem::Event::CommentAdded(
                    ProposalSystem::CommentAdded {
                        proposal_id,
                        comment_id: 0,
                        commenter: shareholder
                    }
                )
            )
        ]
    );
}

#[test]
fn test_all_vote_types() {
    let (token_address, artist, proposal_system, voting_mechanism, token) = setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();
    let shareholder3 = SHAREHOLDER_3();
    
    // Distribute tokens
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(3));
    token.transfer(shareholder1, 20_u256);
    token.transfer(shareholder2, 30_u256);
    token.transfer(shareholder3, 25_u256);
    
    // Create proposal
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "Vote Types Test", "Testing all vote types", 'OTHER');
    
    // Cast different vote types
    cheat_caller_address(voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let weight1 = voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
    
    cheat_caller_address(voting_mechanism.contract_address, shareholder2, CheatSpan::TargetCalls(1));
    let weight2 = voting_mechanism.cast_vote(proposal_id, VoteType::Against, token_address);
    
    cheat_caller_address(voting_mechanism.contract_address, shareholder3, CheatSpan::TargetCalls(1));
    let weight3 = voting_mechanism.cast_vote(proposal_id, VoteType::Abstain, token_address);
    
    // Verify weights
    assert(weight1 == 20_u256, 'For vote weight mismatch');
    assert(weight2 == 30_u256, 'Against vote weight mismatch');
    assert(weight3 == 25_u256, 'Abstain vote weight mismatch');
    
    // Check final breakdown
    let breakdown = voting_mechanism.get_vote_breakdown(proposal_id);
    assert(breakdown.votes_for == 20_u256, 'For votes total mismatch');
    assert(breakdown.votes_against == 30_u256, 'Against votes total mismatch');
    assert(breakdown.votes_abstain == 25_u256, 'Abstain votes total mismatch');
    assert(breakdown.total_voters == 3, 'Total voters mismatch');
    
    // Test individual vote retrieval
    let vote1 = voting_mechanism.get_vote(proposal_id, shareholder1);
    assert(vote1.vote_type == VoteType::For, 'Vote1 type mismatch');
    assert(vote1.weight == 20_u256, 'Vote1 weight mismatch');
    
    let vote2 = voting_mechanism.get_vote(proposal_id, shareholder2);
    assert(vote2.vote_type == VoteType::Against, 'Vote2 type mismatch');
    
    let vote3 = voting_mechanism.get_vote(proposal_id, shareholder3);
    assert(vote3.vote_type == VoteType::Abstain, 'Vote3 type mismatch');
}

#[test]
fn test_vote_tracking_functions() {
    let (token_address, artist, proposal_system, voting_mechanism, token) = setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();
    
    // Setup tokens and proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    token.transfer(shareholder1, 30_u256);
    token.transfer(shareholder2, 20_u256);
    
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "Tracking Test", "Testing vote tracking", 'OTHER');
    
    // Test initial state
    assert(!voting_mechanism.has_voted(proposal_id, shareholder1), 'Should not have voted yet');
    assert(voting_mechanism.get_voter_count(proposal_id) == 0, 'Should have 0 voters initially');
    assert(voting_mechanism.get_voting_weight(proposal_id, shareholder1) == 0, 'Should have 0 weight initially');
    
    // Cast votes
    cheat_caller_address(voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
    
    cheat_caller_address(voting_mechanism.contract_address, shareholder2, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::Against, token_address);
    
    // Test tracking functions
    assert(voting_mechanism.has_voted(proposal_id, shareholder1), 'Should have voted');
    assert(voting_mechanism.has_voted(proposal_id, shareholder2), 'Should have voted');
    assert(voting_mechanism.get_voter_count(proposal_id) == 2, 'Should have 2 voters');
    assert(voting_mechanism.get_voting_weight(proposal_id, shareholder1) == 30_u256, 'Weight mismatch');
    assert(voting_mechanism.get_voting_weight(proposal_id, shareholder2) == 20_u256, 'Weight mismatch');
}

#[test]
fn test_voting_period_management() {
    let (token_address, artist, proposal_system, voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 10_u256);
    
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "Period Test", "Testing voting periods", 'OTHER');
    
    // Test initial state (no period set)
    assert(voting_mechanism.get_voting_period(proposal_id) == 0, 'Should have no period initially');
    assert(voting_mechanism.is_voting_active(proposal_id), 'Should be active initially');
    
    // Set voting period to 1 hour from now
    let current_time = get_block_timestamp();
    let end_time = current_time + 3600; // 1 hour
    voting_mechanism.set_voting_period(proposal_id, end_time);
    
    assert(voting_mechanism.get_voting_period(proposal_id) == end_time, 'Period not set correctly');
    assert(voting_mechanism.is_voting_active(proposal_id), 'Should still be active');
    
    // Simulate time passing beyond voting period
    cheat_block_timestamp_global(end_time + 1);
    assert(!voting_mechanism.is_voting_active(proposal_id), 'Should be inactive after period');
}

#[test]
fn test_delegation_system() {
    let (token_address, artist, proposal_system, voting_mechanism, token) = setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();
    
    // Setup tokens
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    token.transfer(shareholder1, 25_u256);
    token.transfer(shareholder2, 25_u256);
    
    // Test initial delegation state
    assert(voting_mechanism.get_delegation(shareholder1) == ZERO_ADDRESS(), 'Should have no delegation initially');
    
    // Delegate vote
    cheat_caller_address(voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(shareholder2);
    
    // Verify delegation
    assert(voting_mechanism.get_delegation(shareholder1) == shareholder2, 'Delegation not set correctly');
    
    // Test that delegation can be changed
    cheat_caller_address(voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(artist);
    
    assert(voting_mechanism.get_delegation(shareholder1) == artist, 'Delegation not updated');
}

#[test]
fn test_proposal_categories() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 20_u256);
    
    // Create proposals with different categories
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(4));
    
    let revenue_id = proposal_system.submit_proposal(token_address, "Revenue Proposal", "Revenue desc", 'REVENUE');
    let marketing_id = proposal_system.submit_proposal(token_address, "Marketing Proposal", "Marketing desc", 'MARKETING');
    let creative_id = proposal_system.submit_proposal(token_address, "Creative Proposal", "Creative desc", 'CREATIVE');
    let other_id = proposal_system.submit_proposal(token_address, "Other Proposal", "Other desc", 'OTHER');
    
    // Test category filtering
    let revenue_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'REVENUE', 0, 10);
    assert(revenue_proposals.len() == 1, 'Should have 1 revenue proposal');
    assert(revenue_proposals.at(0).category == 'REVENUE', 'Category mismatch');
    
    let marketing_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'MARKETING', 0, 10);
    assert(marketing_proposals.len() == 1, 'Should have 1 marketing proposal');
    
    let creative_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'CREATIVE', 0, 10);
    assert(creative_proposals.len() == 1, 'Should have 1 creative proposal');
    
    let other_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'OTHER', 0, 10);
    assert(other_proposals.len() == 1, 'Should have 1 other proposal');
    
    // Test all categories
    let all_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'ALL', 0, 10);
    assert(all_proposals.len() == 4, 'Should have 4 total proposals');
}

#[test]
fn test_proposal_status_filtering() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    // Setup and create proposals
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 20_u256);
    
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(3));
    let proposal1 = proposal_system.submit_proposal(token_address, "Proposal 1", "Desc 1", 'OTHER');
    let proposal2 = proposal_system.submit_proposal(token_address, "Proposal 2", "Desc 2", 'OTHER');
    let proposal3 = proposal_system.submit_proposal(token_address, "Proposal 3", "Desc 3", 'OTHER');
    
    // Change statuses
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(2));
    proposal_system.respond_to_proposal(proposal1, 1, "Approved"); // Approved
    proposal_system.respond_to_proposal(proposal2, 2, "Rejected"); // Rejected
    // proposal3 remains Pending (0)
    
    // Test status filtering
    let pending_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 0, 'ALL', 0, 10);
    assert(pending_proposals.len() == 1, 'Should have 1 pending proposal');
    
    let approved_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 1, 'ALL', 0, 10);
    assert(approved_proposals.len() == 1, 'Should have 1 approved proposal');
    
    let rejected_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 2, 'ALL', 0, 10);
    assert(rejected_proposals.len() == 1, 'Should have 1 rejected proposal');
    
    // Test helper function
    let status_proposals = proposal_system.get_proposals_by_status(1);
    assert(status_proposals.len() == 1, 'get_proposals_by_status failed');
}

#[test]
fn test_pagination() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 20_u256);
    
    // Create 5 proposals
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(5));
    let mut i = 0;
    while i < 5 {
        proposal_system.submit_proposal(token_address, "Proposal", "Description", 'OTHER');
        i += 1;
    };
    
    // Test pagination
    let page0 = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'ALL', 0, 2); // First 2
    assert(page0.len() == 2, 'Page 0 should have 2 proposals');
    
    let page1 = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'ALL', 1, 2); // Next 2
    assert(page1.len() == 2, 'Page 1 should have 2 proposals');
    
    let page2 = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'ALL', 2, 2); // Last 1
    assert(page2.len() == 1, 'Page 2 should have 1 proposal');
    
    let page3 = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'ALL', 3, 2); // Should be empty
    assert(page3.len() == 0, 'Page 3 should be empty');
    
    // Test comment pagination
    let proposal_id = 1;
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(3));
    proposal_system.add_comment(proposal_id, "Comment 1");
    proposal_system.add_comment(proposal_id, "Comment 2");
    proposal_system.add_comment(proposal_id, "Comment 3");
    
    let comments_page0 = proposal_system.get_comments(proposal_id, 0, 2);
    assert(comments_page0.len() == 2, 'Comments page 0 should have 2');
    
    let comments_page1 = proposal_system.get_comments(proposal_id, 1, 2);
    assert(comments_page1.len() == 1, 'Comments page 1 should have 1');
}

#[test]
fn test_proposal_metrics_tracking() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) = setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();
    
    // Setup shareholders
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    token.transfer(shareholder1, 20_u256);
    token.transfer(shareholder2, 15_u256);
    
    // Create proposal
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "Metrics Test", "Testing metrics", 'OTHER');
    
    // Check initial metrics
    let initial_metrics = proposal_system.get_proposal_metrics(proposal_id);
    assert(initial_metrics.comment_count == 0, 'Initial comment count should be 0');
    assert(initial_metrics.total_voters == 0, 'Initial voter count should be 0');
    
    // Add comments and check metrics update
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(2));
    proposal_system.add_comment(proposal_id, "First comment");
    proposal_system.add_comment(proposal_id, "Second comment");
    
    cheat_caller_address(proposal_system.contract_address, shareholder2, CheatSpan::TargetCalls(1));
    proposal_system.add_comment(proposal_id, "Third comment");
    
    let updated_metrics = proposal_system.get_proposal_metrics(proposal_id);
    assert(updated_metrics.comment_count == 3, 'Comment count should be 3');
}

#[test]
fn test_threshold_management() {
    let owner = OWNER();
    let factory = deploy_token_factory(owner);
    let proposal_system = deploy_proposal_system(factory.contract_address, 5); // 5% threshold
    
    // Test initial threshold
    assert(proposal_system.get_minimum_threshold() == 5, 'Initial threshold should be 5%');
    
    // Update threshold
    proposal_system.update_minimum_threshold(10);
    assert(proposal_system.get_minimum_threshold() == 10, 'Threshold should be updated to 10%');
    
    // Test with different threshold values
    proposal_system.update_minimum_threshold(1);
    assert(proposal_system.get_minimum_threshold() == 1, 'Threshold should be 1%');
    
    proposal_system.update_minimum_threshold(50);
    assert(proposal_system.get_minimum_threshold() == 50, 'Threshold should be 50%');
}

#[test]
fn test_artist_management() {
    let owner = OWNER();
    let artist1 = ARTIST_1();
    let artist2 = ARTIST_2();
    let factory = deploy_token_factory(owner);
    let proposal_system = deploy_proposal_system(factory.contract_address, MIN_THRESHOLD_PERCENTAGE);
    
    // Create two tokens
    cheat_caller_address(factory.contract_address, owner, CheatSpan::TargetCalls(2));
    factory.grant_artist_role(artist1);
    factory.grant_artist_role(artist2);
    
    cheat_caller_address(factory.contract_address, artist1, CheatSpan::TargetCalls(1));
    let token1 = factory.deploy_music_token("Album 1", "A1", 6, "ipfs://1");
    
    cheat_caller_address(factory.contract_address, artist2, CheatSpan::TargetCalls(1));
    let token2 = factory.deploy_music_token("Album 2", "A2", 6, "ipfs://2");
    
    // Register artists
    proposal_system.register_artist(token1, artist1);
    proposal_system.register_artist(token2, artist2);
    
    // Test artist retrieval
    assert(proposal_system.get_artist_for_token(token1) == artist1, 'Artist 1 mismatch');
    assert(proposal_system.get_artist_for_token(token2) == artist2, 'Artist 2 mismatch');
    assert(proposal_system.get_artist_for_token(ZERO_ADDRESS()) == ZERO_ADDRESS(), 'Unregistered should be zero');
    
    // Test proposals by artist
    let shareholder = SHAREHOLDER_1();
    cheat_caller_address(token1, artist1, CheatSpan::TargetCalls(1));
    IERC20MixinDispatcher { contract_address: token1 }.transfer(shareholder, 10_u256);
    
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    proposal_system.submit_proposal(token1, "Artist 1 Proposal", "Description", 'OTHER');
    
    let artist1_proposals = proposal_system.get_proposals_by_artist(token1);
    assert(artist1_proposals.len() == 1, 'Should have 1 proposal for artist 1');
    
    let artist2_proposals = proposal_system.get_proposals_by_artist(token2);
    assert(artist2_proposals.len() == 0, 'Should have 0 proposals for artist 2');
}

// Edge case tests

#[test]
#[should_panic(expected: ('Already voted',))]
fn test_double_voting_fails() {
    let (token_address, artist, proposal_system, voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    // Setup and vote
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 10_u256);
    
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "Double Vote Test", "Test", 'OTHER');
    
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
    // This should fail
    voting_mechanism.cast_vote(proposal_id, VoteType::Against, token_address);
}

#[test]
#[should_panic(expected: ('No voting power',))]
fn test_zero_balance_voting_fails() {
    let (token_address, _artist, proposal_system, voting_mechanism, _token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    let zero_balance_user = SHAREHOLDER_2();
    
    // Only shareholder has tokens
    cheat_caller_address(token_address, _artist, CheatSpan::TargetCalls(1));
    _token.transfer(shareholder, 10_u256);
    
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "Zero Balance Test", "Test", 'OTHER');
    
    // User with zero balance tries to vote
    cheat_caller_address(voting_mechanism.contract_address, zero_balance_user, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
}

#[test]
#[should_panic(expected: ('Cannot delegate to self',))]
fn test_self_delegation_fails() {
    let (_token_address, _artist, _proposal_system, voting_mechanism, _token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(shareholder);
}

#[test]
#[should_panic(expected: ('Not a token holder',))]
fn test_non_holder_comment_fails() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    let non_holder = SHAREHOLDER_2();
    
    // Only shareholder has tokens
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 10_u256);
    
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "Comment Test", "Test", 'OTHER');
    
    // Non-holder tries to comment
    cheat_caller_address(proposal_system.contract_address, non_holder, CheatSpan::TargetCalls(1));
    proposal_system.add_comment(proposal_id, "I shouldn't be able to comment");
}

#[test]
#[should_panic(expected: ('Only artist can respond',))]
fn test_non_artist_response_fails() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    let fake_artist = SHAREHOLDER_2();
    
    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 10_u256);
    
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "Response Test", "Test", 'OTHER');
    
    // Non-artist tries to respond
    cheat_caller_address(proposal_system.contract_address, fake_artist, CheatSpan::TargetCalls(1));
    proposal_system.respond_to_proposal(proposal_id, 1, "I'm not the artist");
}

#[test]
#[should_panic(expected: ('Threshold must be <= 100',))]
fn test_invalid_threshold_update_fails() {
    let owner = OWNER();
    let factory = deploy_token_factory(owner);
    let proposal_system = deploy_proposal_system(factory.contract_address, MIN_THRESHOLD_PERCENTAGE);
    
    // Try to set threshold above 100%
    proposal_system.update_minimum_threshold(101);
}

#[test]
fn test_empty_content_edge_cases() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 10_u256);
    
    // Test empty proposal content
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "", "", 'OTHER');
    
    let proposal = proposal_system.get_proposal(proposal_id);
    assert(proposal.title == "", 'Empty title should work');
    assert(proposal.description == "", 'Empty description should work');
    
    // Test empty comment
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    proposal_system.add_comment(proposal_id, "");
    
    let comments = proposal_system.get_comments(proposal_id, 0, 10);
    assert(comments.len() == 1, 'Empty comment should be added');
    assert(comments.at(0).content == "", 'Comment content should be empty');
    
    // Test empty artist response
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system.respond_to_proposal(proposal_id, 1, "");
    
    let updated_proposal = proposal_system.get_proposal(proposal_id);
    assert(updated_proposal.artist_response == "", 'Empty response should work');
}

#[test]
fn test_large_content_handling() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 10_u256);
    
    // Create proposal with long content
    let long_title = "This is a very long title that tests the system's ability to handle large amounts of text content in proposal titles";
    let long_description = "This is an extremely long description that tests the system's capability to store and retrieve large amounts of text data. It should work properly even with extensive content that might be used in real-world governance proposals with detailed explanations and comprehensive information.";
    
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, long_title, long_description, 'OTHER');
    
    let proposal = proposal_system.get_proposal(proposal_id);
    assert(proposal.title == long_title, 'Long title should be stored correctly');
    assert(proposal.description == long_description, 'Long description should be stored correctly');
}

#[test]
fn test_boundary_conditions() {
    let (token_address, artist, proposal_system, voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    // Test with exactly threshold amount (3% of 100 = 3 tokens)
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 3_u256);
    
    // Should work with exactly 3% threshold
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system.submit_proposal(token_address, "Boundary Test", "Testing threshold boundary", 'OTHER');
    
    assert(proposal_id == 1, 'Proposal should be created at boundary');
    
    // Test voting with exactly 1 token
    let small_holder = SHAREHOLDER_2();
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(small_holder, 1_u256);
    
    cheat_caller_address(voting_mechanism.contract_address, small_holder, CheatSpan::TargetCalls(1));
    let weight = voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
    assert(weight == 1_u256, 'Should work with 1 token weight');
}

#[test]
fn test_proposal_id_sequence() {
    let (token_address, artist, proposal_system, _voting_mechanism, token) = setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    
    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    token.transfer(shareholder, 20_u256);
    
    // Create multiple proposals and verify ID sequence
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(3));
    
    let id1 = proposal_system.submit_proposal(token_address, "Proposal 1", "Desc 1", 'OTHER');
    let id2 = proposal_system.submit_proposal(token_address, "Proposal 2", "Desc 2", 'OTHER');
    let id3 = proposal_system.submit_proposal(token_address, "Proposal 3", "Desc 3", 'OTHER');
    
    assert(id1 == 1, 'First proposal should have ID 1');
    assert(id2 == 2, 'Second proposal should have ID 2');
    assert(id3 == 3, 'Third proposal should have ID 3');
    
    // Verify total count
    assert(proposal_system.get_total_proposals() == 3, 'Should have 3 total proposals');
}
