use contract_::governance::{
    GovernanceToken::{
        IERC20ExtensionDispatcher, IERC20ExtensionDispatcherTrait, IGovernanceTokenDispatcher,
        IGovernanceTokenDispatcherTrait, GovernanceToken,
    },
    ProposalSystem::{IProposalSystemDispatcher, IProposalSystemDispatcherTrait, ProposalSystem},
    VotingMechanism::{IVotingMechanismDispatcher, IVotingMechanismDispatcherTrait, VotingMechanism},
    types::VoteType,
};
use contract_::token_factory::{
    IMusicShareTokenFactoryDispatcher, IMusicShareTokenFactoryDispatcherTrait, MusicShareTokenFactory
};
use contract_::events::{
    ProposalCreated, VoteDelegated, VoteCast, ProposalStatusChanged, CommentAdded, ArtistRegistered,
    RoleGranted, VotingPeriodEnded, VotingPeriodStarted, TokenTransferDuringVoting,
};
use core::array::ArrayTrait;
use core::result::ResultTrait;
use core::traits::Into;
use openzeppelin::token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_block_timestamp, cheat_caller_address, declare, spy_events,
};
use starknet::{class_hash::ClassHash, ContractAddress, contract_address_const, get_block_timestamp};

// Address constants for testing
fn ARTIST_1() -> ContractAddress {
    contract_address_const::<'artist_1'>()
}

fn ARTIST_2() -> ContractAddress {
    contract_address_const::<'artist_2'>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'owner'>()
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

fn ZERO_ADDRESS() -> ContractAddress {
    contract_address_const::<0>()
}

const TOTAL_SHARES: u256 = 100_u256;
const DEFAULT_VOTING_PERIOD: u64 = 604800_u64; // 7 days in seconds
const MIN_THRESHOLD_PERCENTAGE: u8 = 3_u8; // 3% minimum threshold
const MIN_TOKEN_THRESHOLD_PERCENTAGE: u8 = 30_u8; // 30% minimum token threshold

/// Helper function to deploy a music token for testing
fn deploy_music_token(artist: ContractAddress) -> (ContractAddress, ClassHash) {
    let mut calldata = array![];
    calldata.append_serde(artist);

    let contract_class = declare("MusicStrk").unwrap().contract_class();
    let contract_class_hash = contract_class.class_hash;

    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    (contract_address, *contract_class_hash)
}

/// Helper function to deploy the token factory
fn deploy_token_factory(owner: ContractAddress) -> IMusicShareTokenFactoryDispatcher {
    let (_music_token_address, music_token_class_hash) = deploy_music_token(owner);
    let mut calldata = array![];
    calldata.append(owner.into());
    calldata.append(music_token_class_hash.into());

    let factory_class = declare("MusicShareTokenFactory").unwrap().contract_class();
    let (factory_address, _) = factory_class.deploy(@calldata).unwrap();
    IMusicShareTokenFactoryDispatcher { contract_address: factory_address }
}

/// Helper function to deploy the ProposalSystem contract
fn deploy_proposal_system(
    factory_contract: ContractAddress, min_threshold: u8,
) -> IProposalSystemDispatcher {
    let mut calldata = array![];
    calldata.append_serde(factory_contract);
    calldata.append_serde(min_threshold);

    let contract_class = declare("ProposalSystem").unwrap().contract_class();
    let (_contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IProposalSystemDispatcher { contract_address: _contract_address }
}

/// Helper function to deploy the VotingMechanism contract
fn deploy_voting_mechanism(
    proposal_system: ContractAddress,
    default_voting_period: u64,
    minimum_token_threshold_percentage: u8,
) -> IVotingMechanismDispatcher {
    let mut calldata = array![];
    calldata.append_serde(proposal_system);
    calldata.append_serde(default_voting_period);
    calldata.append_serde(minimum_token_threshold_percentage);

    let contract_class = declare("VotingMechanism").unwrap().contract_class();
    let (_contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IVotingMechanismDispatcher { contract_address: _contract_address }
}

/// Helper function to deploy GovernanceToken
fn deploy_governance_token(
    name: ByteArray,
    symbol: ByteArray,
    decimals: u8,
    owner: ContractAddress,
    proposal_system: ContractAddress,
    voting_mechanism: ContractAddress,
) -> IGovernanceTokenDispatcher {
    let mut calldata = array![];
    calldata.append_serde(name.into());
    calldata.append_serde(symbol.into());
    calldata.append_serde(decimals);
    calldata.append_serde(owner);
    calldata.append_serde(proposal_system);
    calldata.append_serde(voting_mechanism);

    let contract_class = declare("GovernanceToken").unwrap().contract_class();
    // let (_contract_address, _) = contract_class.deploy(@calldata).unwrap();
    let (_contract_address, _) = contract_class
        .deploy(@calldata)
        .expect('GovernanceToken deploy failed');
    IGovernanceTokenDispatcher { contract_address: _contract_address }
}

/// Setup governance environment with GovernanceToken
fn setup_governance_environment() -> (
    ContractAddress,
    ContractAddress,
    IProposalSystemDispatcher,
    IVotingMechanismDispatcher,
    IERC20MixinDispatcher,
    IGovernanceTokenDispatcher,
) {
    let owner = OWNER();
    let artist = ARTIST_1();

    // Deploy factory and create a token
    let factory = deploy_token_factory(owner);

    // Grant artist role and deploy music token
    cheat_caller_address(factory.contract_address, owner, CheatSpan::TargetCalls(1));
    factory.grant_artist_role(artist);

    cheat_caller_address(factory.contract_address, artist, CheatSpan::TargetCalls(1));
    let token_address = factory
        .deploy_music_token("Test Album", "TA", 6_u8, "ipfs://test-metadata");

    // Create an instance of the music token
    let music_token = IERC20MixinDispatcher { contract_address: token_address };

    // Deploy governance contracts
    let proposal_system = deploy_proposal_system(
        factory.contract_address, MIN_THRESHOLD_PERCENTAGE,
    );

    let voting_mechanism = deploy_voting_mechanism(
        proposal_system.contract_address, DEFAULT_VOTING_PERIOD, MIN_TOKEN_THRESHOLD_PERCENTAGE,
    );

    // Set voting contract in proposal system
    cheat_caller_address(proposal_system.contract_address, owner, CheatSpan::TargetCalls(1));
    proposal_system.set_voting_contract(voting_mechanism.contract_address);

    // Register artist in proposal system
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system.register_artist(token_address, artist);

    // Deploy governance token
    cheat_caller_address(proposal_system.contract_address, owner, CheatSpan::TargetCalls(1));
    let governance_token = deploy_governance_token(
        "Gov Token",
        "GVT",
        6_u8,
        owner,
        proposal_system.contract_address,
        voting_mechanism.contract_address,
    );

    // Mint governance tokens to the owner
    let mintable_governance_token = IERC20ExtensionDispatcher {
        contract_address: governance_token.contract_address,
    };

    cheat_caller_address(governance_token.contract_address, owner, CheatSpan::TargetCalls(1));
    mintable_governance_token.mint(owner, 1000_u256);

    (token_address, artist, proposal_system, voting_mechanism, music_token, governance_token)
}


// ============================================================================
// PROPOSAL SYSTEM TESTS
// ============================================================================
#[test]
fn test_proposal_system_initialization() {
    let owner = OWNER();
    let factory = deploy_token_factory(owner);

    let proposal_system = deploy_proposal_system(
        factory.contract_address, MIN_THRESHOLD_PERCENTAGE,
    );

    // Test initial state
    assert(proposal_system.get_total_proposals_count() == 0, 'Should start with 0 proposals');
    assert(
        proposal_system.get_minimum_threshold() == MIN_THRESHOLD_PERCENTAGE, 'Threshold mismatch',
    );

    // Test empty arrays
    let all_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'ALL', 0, 10);
    assert(all_proposals.len() == 0, 'Should have no proposals');
}

#[test]
fn test_proposal_submission() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    let mut spy = spy_events();

    // Transfer some tokens to shareholder to meet threshold
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256); // 10% of total supply

    // Shareholder submits a proposal
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));

    let proposal_id = proposal_system
        .submit_proposal(
            token_address,
            "Revenue Distribution Proposal",
            "Proposal to distribute 50% of revenue to token holders",
            'REVENUE',
        );

    spy
        .assert_emitted(
            @array![
                (
                    proposal_system.contract_address,
                    ProposalSystem::Event::ProposalCreated(
                        ProposalCreated {
                            proposal_id,
                            token_contract: token_address,
                            proposer: shareholder,
                            category: 'REVENUE', // All 3 proposals should be affected
                            title: "Revenue Distribution Proposal"
                        },
                    ),
                ),
            ],
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
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    let mut spy = spy_events();

    // Transfer tokens and submit proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

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

    spy
        .assert_emitted(
            @array![
                (
                    proposal_system.contract_address,
                    ProposalSystem::Event::ProposalStatusChanged(
                        ProposalStatusChanged {
                            proposal_id,
                            old_status: 0,
                            new_status: 1,
                            responder: artist // All 3 proposals should be affected
                        },
                    ),
                ),
            ],
        );

    // Verify response
    let proposal = proposal_system.get_proposal(proposal_id);
    assert(proposal.status == 1, 'Status should be Approved');
}

#[test]
fn test_get_active_proposals() {
    let (
        token_address, artist, proposal_system, _voting_mechanism, music_token, _governance_token,
    ) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup tokens using token
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 30_u256);

    // Initially no active proposals
    let empty_proposals = proposal_system.get_active_proposals(token_address);
    assert(empty_proposals.len() == 0, 'Should have no active proposals');

    // Create some proposals (they should be active by default with status 0)
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(3));
    let proposal_id1 = proposal_system
        .submit_proposal(token_address, "Active 1", "First active", 'REVENUE');
    let proposal_id2 = proposal_system
        .submit_proposal(token_address, "Active 2", "Second active", 'MARKETING');
    let proposal_id3 = proposal_system
        .submit_proposal(token_address, "Active 3", "Third active", 'OTHER');

    // Check active proposals
    let active_proposals = proposal_system.get_active_proposals(token_address);
    assert(active_proposals.len() == 3, 'Should have 3 active proposals');
    assert(*active_proposals.at(0) == proposal_id1, 'First proposal ID wrong');
    assert(*active_proposals.at(1) == proposal_id2, 'Second proposal ID wrong');
    assert(*active_proposals.at(2) == proposal_id3, 'Third proposal ID wrong');

    // Artist responds to one proposal (changes status from 0 to 1, no longer active)
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system.respond_to_proposal(proposal_id2, 1, "Approved");

    // Check active proposals again (should be 2 now)
    let remaining_active = proposal_system.get_active_proposals(token_address);
    assert(remaining_active.len() == 2, 'Should have 2 active proposals');
}

#[test]
fn test_artist_veto_proposal() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 30_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Veto Test", "Testing artist veto", 'OTHER');

    // Shareholder votes
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    // Artist vetoes the proposal
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system.veto_proposal(proposal_id, "Artist disagrees with this proposal");

    // Verify proposal status after veto
    let proposal = proposal_system.get_proposal(proposal_id);
    assert(proposal.status == 4, 'Proposal should be vetoed'); // 4 = Vetoed status
}

#[test]
#[should_panic(expected: ('Only artist can respond',))]
fn test_non_artist_veto_fails() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    let fake_artist = SHAREHOLDER_2();

    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 30_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Veto Test", "Testing veto", 'OTHER');

    // Non-artist tries to veto
    cheat_caller_address(proposal_system.contract_address, fake_artist, CheatSpan::TargetCalls(1));
    proposal_system.veto_proposal(proposal_id, "I'm not the artist");
}

#[test]
fn test_comment_system() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

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
fn test_proposal_filtering() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 15_u256);

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
#[should_panic(expect: ('Insufficient token balance',))]
fn test_insufficient_threshold_proposal_fails() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Transfer only 1 token (less than 3% threshold)
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 1_u256);

    // Should fail due to insufficient balance
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    proposal_system.submit_proposal(token_address, "Invalid Proposal", "This should fail", 'OTHER');
}

#[test]
fn test_proposal_categories() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 20_u256);

    // Create proposals with different categories
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(4));

    let _revenue_id = proposal_system
        .submit_proposal(token_address, "Revenue Proposal", "Revenue desc", 'REVENUE');
    let _marketing_id = proposal_system
        .submit_proposal(token_address, "Marketing Proposal", "Marketing desc", 'MARKETING');
    let _creative_id = proposal_system
        .submit_proposal(token_address, "Creative Proposal", "Creative desc", 'CREATIVE');
    let _other_id = proposal_system
        .submit_proposal(token_address, "Other Proposal", "Other desc", 'OTHER');

    // Test category filtering
    let revenue_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 255, 'REVENUE', 0, 10);
    assert(revenue_proposals.len() == 1, 'Should have 1 revenue proposal');
    assert(*revenue_proposals.at(0).category == 'REVENUE', 'Category mismatch');

    let marketing_proposals = proposal_system
        .get_proposals(ZERO_ADDRESS(), 255, 'MARKETING', 0, 10);
    assert(marketing_proposals.len() == 1, 'Marketing proposals should be 1');

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
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup and create proposals
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 20_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(3));
    let proposal1 = proposal_system.submit_proposal(token_address, "Proposal 1", "Desc 1", 'OTHER');
    let proposal2 = proposal_system.submit_proposal(token_address, "Proposal 2", "Desc 2", 'OTHER');
    let _proposal3 = proposal_system
        .submit_proposal(token_address, "Proposal 3", "Desc 3", 'OTHER');

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

    let implemented_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 3, 'ALL', 0, 10);
    assert(implemented_proposals.len() == 0, 'Should have 0 implemented props');

    let vetoed_proposals = proposal_system.get_proposals(ZERO_ADDRESS(), 4, 'ALL', 0, 10);
    assert(vetoed_proposals.len() == 0, 'Should have 0 vetoed proposals');

    // Test helper function
    let status_proposals = proposal_system.get_proposals_by_status(1);
    assert(status_proposals.len() == 1, 'get_proposals_by_status failed');
}

#[test]
fn test_pagination() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 20_u256);

    // Create 5 proposals
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(5));
    let mut i: u64 = 0;
    while i < 5_u64 {
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
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();

    // Setup shareholders
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    music_token.transfer(shareholder1, 20_u256);
    music_token.transfer(shareholder2, 15_u256);

    // Create proposal
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Metrics Test", "Testing metrics", 'OTHER');

    // Check initial metrics
    let initial_metrics = proposal_system.get_proposal_metrics(proposal_id);
    assert(initial_metrics.comment_count == 0, 'Comment count should be 0');
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

    // Mock threshold updates as factory owner
    cheat_caller_address(proposal_system.contract_address, owner, CheatSpan::TargetCalls(6));

    // Update threshold
    proposal_system.update_minimum_threshold(10);
    assert(proposal_system.get_minimum_threshold() == 10, 'Threshold should be 10%');

    // Test with different valid threshold values
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
    let mut spy = spy_events();
    let proposal_system = deploy_proposal_system(
        factory.contract_address, MIN_THRESHOLD_PERCENTAGE,
    );

    // Create two tokens
    cheat_caller_address(factory.contract_address, owner, CheatSpan::TargetCalls(2));
    cheat_block_timestamp(factory.contract_address, 0, CheatSpan::TargetCalls(2));
    factory.grant_artist_role(artist1);
    factory.grant_artist_role(artist2);

    spy
        .assert_emitted(
            @array![
                (
                    factory.contract_address,
                    MusicShareTokenFactory::Event::RoleGranted(
                        RoleGranted { artist: artist2, timestamp: 0 },
                    ),
                ),
            ],
        );

    cheat_caller_address(factory.contract_address, artist1, CheatSpan::TargetCalls(1));
    let token1 = factory.deploy_music_token("Album 1", "A1", 6, "ipfs://1");

    cheat_caller_address(factory.contract_address, artist2, CheatSpan::TargetCalls(1));
    let token2 = factory.deploy_music_token("Album 2", "A2", 6, "ipfs://2");

    // Register only artist 1 as an artist in governance system
    cheat_caller_address(factory.contract_address, artist1, CheatSpan::TargetCalls(1));
    proposal_system.register_artist(token1, artist1);

    // Test proposals by artist
    let shareholder = SHAREHOLDER_1();
    cheat_caller_address(token1, artist1, CheatSpan::TargetCalls(1));
    IERC20MixinDispatcher { contract_address: token1 }.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    proposal_system.submit_proposal(token1, "Artist 1 Proposal", "Description", 'OTHER');

    // Test using token address
    let artist1_proposal = proposal_system.get_proposals_by_token(token1);
    assert(artist1_proposal.len() == 1, 'Should have 1 proposal');

    let artist2_proposal = proposal_system.get_proposals_by_token(token2);
    assert(artist2_proposal.len() == 0, 'Should have 0 proposals');

    // Test using user addresses
    let shareholder_proposals = proposal_system.get_proposals_by_proposer(shareholder);
    assert(shareholder_proposals.len() == 1, 'Should have 1 proposal');

    let artist_proposals = proposal_system.get_proposals_by_proposer(artist1);
    assert(artist_proposals.len() == 0, 'Should have 0 proposals');

    // Test artist retrieval
    assert(proposal_system.get_artist_for_token(token1) == artist1, 'Artist 1 mismatch');
    assert(
        proposal_system.get_artist_for_token(token2) == contract_address_const::<0>(),
        'Artist 2 mismatch',
    );
    assert(
        proposal_system.get_artist_for_token(ZERO_ADDRESS()) == ZERO_ADDRESS(),
        'Unregistered should be zero',
    );
}

#[test]
#[should_panic(expected: ('Not a token holder',))]
fn test_non_holder_comment_fails() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    let non_holder = SHAREHOLDER_2();

    // Only shareholder has tokens
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Comment Test", "Test", 'OTHER');

    // Non-holder tries to comment
    cheat_caller_address(proposal_system.contract_address, non_holder, CheatSpan::TargetCalls(1));
    proposal_system.add_comment(proposal_id, "I shouldn't be able to comment");
}

#[test]
#[should_panic(expected: ('Only artist can respond',))]
fn test_non_artist_response_fails() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    let fake_artist = SHAREHOLDER_2();

    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Response Test", "Test", 'OTHER');

    // Non-artist tries to respond
    cheat_caller_address(proposal_system.contract_address, fake_artist, CheatSpan::TargetCalls(1));
    proposal_system.respond_to_proposal(proposal_id, 1, "I'm not the artist");
}

#[test]
#[should_panic(expected: ('Threshold must be <= 100',))]
fn test_invalid_threshold_update_fails() {
    let owner = OWNER();
    let factory = deploy_token_factory(owner);
    let proposal_system = deploy_proposal_system(
        factory.contract_address, MIN_THRESHOLD_PERCENTAGE,
    );

    // Try to set threshold above 100%
    cheat_caller_address(proposal_system.contract_address, owner, CheatSpan::TargetCalls(1));
    proposal_system.update_minimum_threshold(101);
}

#[test]
fn test_empty_content_edge_cases() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

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
    assert(comments.at(0).content.len() == 0, 'Comment content should be empty');

    // Test empty artist response
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system.respond_to_proposal(proposal_id, 1, "");

    let updated_proposal = proposal_system.get_proposal(proposal_id);
    assert(updated_proposal.artist_response == "", 'Empty response should work');
}

#[test]
fn test_large_content_handling() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    // Create proposal with long content
    let long_title =
        "This is a very long title that tests the system's ability to handle large amounts of text content in proposal titles";
    let long_description =
        "This is an extremely long description that tests the system's capability to store and retrieve large amounts of text data. It should work properly even with extensive content that might be used in real-world governance proposals with detailed explanations and comprehensive information.";

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, long_title.clone(), long_description.clone(), 'OTHER');

    let proposal = proposal_system.get_proposal(proposal_id);
    assert(proposal.title == long_title, 'Long title is incorrect');
    assert(proposal.description == long_description, 'Long description is incorrect');
}

#[test]
fn test_boundary_conditions() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Test with exactly threshold amount (3% of 100 = 3 tokens)
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 3_u256);

    // Should work with exactly 3% threshold
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Boundary Test", "Testing threshold boundary", 'OTHER');

    assert(proposal_id == 1, 'Proposal should be created');

    // Test voting with exactly 1 token
    let small_holder = SHAREHOLDER_2();
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(small_holder, 1_u256);

    cheat_caller_address(
        voting_mechanism.contract_address, small_holder, CheatSpan::TargetCalls(1),
    );
    let weight = voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
    assert(weight == 1_u256, 'Should work with 1 token weight');
}

#[test]
fn test_proposal_id_sequence() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 20_u256);

    // Create multiple proposals and verify ID sequence
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(3));

    let id1 = proposal_system.submit_proposal(token_address, "Proposal 1", "Desc 1", 'OTHER');
    let id2 = proposal_system.submit_proposal(token_address, "Proposal 2", "Desc 2", 'OTHER');
    let id3 = proposal_system.submit_proposal(token_address, "Proposal 3", "Desc 3", 'OTHER');

    assert(id1 == 1, '1st proposal should have ID 1');
    assert(id2 == 2, '2nd proposal should have ID 2');
    assert(id3 == 3, '3rd proposal should have ID 3');

    // Verify total count
    assert(proposal_system.get_total_proposals_count() == 3, 'Should have 3 total proposals');
}

#[test]
fn test_proposal_events() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    let mut spy = spy_events();

    // Submit proposal
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Test Proposal", "Test Description", 'REVENUE');

    // Check ProposalCreated event
    spy
        .assert_emitted(
            @array![
                (
                    proposal_system.contract_address,
                    ProposalSystem::Event::ProposalCreated(
                        ProposalCreated {
                            proposal_id,
                            token_contract: token_address,
                            proposer: shareholder,
                            category: 'REVENUE',
                            title: "Test Proposal",
                        },
                    ),
                ),
            ],
        );

    // Test artist response event
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system.respond_to_proposal(proposal_id, 1, "Approved");

    // Check ProposalStatusChanged event
    spy
        .assert_emitted(
            @array![
                (
                    proposal_system.contract_address,
                    ProposalSystem::Event::ProposalStatusChanged(
                        ProposalStatusChanged {
                            proposal_id, old_status: 0, new_status: 1, responder: artist,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_comment_events() {
    let (token_address, artist, proposal_system, _voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Comment Test", "Testing comments", 'OTHER');

    let mut spy = spy_events();

    // Add comment
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    proposal_system.add_comment(proposal_id, "Great proposal!");

    spy
        .assert_emitted(
            @array![
                (
                    proposal_system.contract_address,
                    ProposalSystem::Event::CommentAdded(
                        CommentAdded { proposal_id, comment_id: 0, commenter: shareholder },
                    ),
                ),
            ],
        );
}

// ============================================================================
// VOTING MECHANISM TESTS
// ============================================================================
#[test]
fn test_voting_mechanism_initialization() {
    let owner = OWNER();
    let factory = deploy_token_factory(owner);
    let proposal_system = deploy_proposal_system(
        factory.contract_address, MIN_THRESHOLD_PERCENTAGE,
    );

    let voting_mechanism = deploy_voting_mechanism(
        proposal_system.contract_address, DEFAULT_VOTING_PERIOD, MIN_TOKEN_THRESHOLD_PERCENTAGE,
    );

    // Test initial voting state for non-existent proposal
    let breakdown = voting_mechanism.get_vote_breakdown(1);
    assert(breakdown.votes_for == 0, 'Should start with 0 for votes');
    assert(breakdown.votes_against == 0, 'Should start with 0 votes');
    assert(breakdown.votes_abstain == 0, 'Should start with 0 votes');
    assert(breakdown.total_voters == 0, 'Should start with 0 voters');
}

#[test]
fn test_voting_mechanism() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _governance_token) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();

    // Distribute tokens to shareholders
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    music_token.transfer(shareholder1, 30_u256);
    music_token.transfer(shareholder2, 20_u256);

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
fn test_vote_delegation() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();

    // Setup tokens and proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    music_token.transfer(shareholder1, 25_u256);
    music_token.transfer(shareholder2, 25_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Delegation Test", "Testing vote delegation", 'OTHER');

    // Test initial delegation state
    assert(
        voting_mechanism.get_delegation(shareholder1) == ZERO_ADDRESS(),
        'Should have no delegations',
    );

    // Shareholder1 delegates to shareholder2
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.delegate_vote(token_address, shareholder2);

    // Verify delegation
    assert(
        voting_mechanism.get_delegation(shareholder1) == shareholder2,
        'Delegation not set correctly',
    );

    // Shareholder2 votes (should include delegated weight)
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder2, CheatSpan::TargetCalls(1),
    );
    let weight = voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    // Weight should be shareholder2's tokens (50) since delegation affects the delegate's balance
    assert(weight == 50_u256, 'Delegated weight incorrect');

    let delegation_breakdown = voting_mechanism.get_vote_breakdown(proposal_id);
    assert(delegation_breakdown.votes_for == 50_u256, 'Delegated votes_for mismatch');
}

#[test]
fn test_delegation_chain_updates() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let delegator1 = SHAREHOLDER_1();
    let delegator2 = SHAREHOLDER_2();
    let delegate = SHAREHOLDER_3();

    // Setup tokens
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(3));
    music_token.transfer(delegator1, 30_u256);
    music_token.transfer(delegator2, 20_u256);
    music_token.transfer(delegate, 25_u256);

    // Create proposal
    cheat_caller_address(proposal_system.contract_address, delegator1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Delegation Chain", "Testing delegation", 'OTHER');

    // Both delegators delegate to same delegate
    cheat_caller_address(voting_mechanism.contract_address, delegator1, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(token_address, delegate);

    cheat_caller_address(voting_mechanism.contract_address, delegator2, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(token_address, delegate);

    // Delegate votes (should have combined power)
    cheat_caller_address(voting_mechanism.contract_address, delegate, CheatSpan::TargetCalls(1));
    let weight = voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    // Weight should only be delegate's combined tokens (75), not delegated tokens
    assert(weight == 75_u256, 'Delegate weight is incorrect');
}

#[test]
#[should_panic(expected: ('Already delegated',))]
fn test_delegation_revocation() {
    let (token_address, artist, _proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let delegator = SHAREHOLDER_1();
    let delegate1 = SHAREHOLDER_2();
    let delegate2 = SHAREHOLDER_3();

    // Setup tokens
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(3));
    music_token.transfer(delegator, 30_u256);
    music_token.transfer(delegate1, 20_u256);
    music_token.transfer(delegate2, 25_u256);

    // Initial delegation
    cheat_caller_address(voting_mechanism.contract_address, delegator, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(token_address, delegate1);

    assert(voting_mechanism.get_delegation(delegator) == delegate1, 'Initial delegation wrong');

    // Attempt to change delegation - will panic
    cheat_caller_address(voting_mechanism.contract_address, delegator, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(token_address, delegate2);
}

#[test]
#[should_panic(expected: ('Cannot vote after delegation',))]
fn test_delegator_cannot_vote_after_delegation() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let delegator = SHAREHOLDER_1();
    let delegate = SHAREHOLDER_2();

    // Setup tokens and proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    music_token.transfer(delegator, 30_u256);
    music_token.transfer(delegate, 20_u256);

    cheat_caller_address(proposal_system.contract_address, delegator, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Delegation Test", "Testing delegation", 'OTHER');

    // Delegate first
    cheat_caller_address(voting_mechanism.contract_address, delegator, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(token_address, delegate);

    // Delegate votes
    cheat_caller_address(voting_mechanism.contract_address, delegate, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    // Delegator tries to vote - should fail
    cheat_caller_address(voting_mechanism.contract_address, delegator, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::Against, token_address);
}

#[test]
fn test_change_vote() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup shareholder
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 30_u256);

    // Create proposal
    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Change Vote Test", "Testing vote changing", 'OTHER');

    // Initial vote - MUST cast a vote first before changing it
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let initial_weight = voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
    assert(initial_weight == 30_u256, 'Initial vote weight wrong');

    // Verify initial vote
    let initial_breakdown = voting_mechanism.get_vote_breakdown(proposal_id);
    assert(initial_breakdown.votes_for == 30_u256, 'Initial votes_for wrong');
    assert(initial_breakdown.votes_against == 0_u256, 'Initial votes_against wrong');

    // Now change the existing vote
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let new_weight = voting_mechanism.change_vote(proposal_id, VoteType::Against, token_address);
    assert(new_weight == 30_u256, 'Changed vote weight wrong');

    // Verify vote changed
    let updated_breakdown = voting_mechanism.get_vote_breakdown(proposal_id);
    assert(updated_breakdown.votes_for == 0_u256, 'Updated votes_for wrong');
    assert(updated_breakdown.votes_against == 30_u256, 'Updated votes_against wrong');
    assert(updated_breakdown.total_voters == 1, 'Voter count should stay same');
}

#[test]
fn test_start_voting_period() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(
            token_address, "Start Period Test", "Testing start voting period", 'OTHER',
        );

    // Test initial state (no period set)
    assert(voting_mechanism.get_voting_period(proposal_id) == 0, 'Should have no period set');
    assert(!voting_mechanism.is_voting_active(proposal_id), 'Should be active initially');

    // Start voting period
    let duration = 3600_u64; // 1 hour
    voting_mechanism.start_voting_period(proposal_id, duration);

    // Verify period was set correctly
    let period_end = voting_mechanism.get_voting_period(proposal_id);
    assert(period_end > 0, 'Voting period should be set');
    assert(voting_mechanism.is_voting_active(proposal_id), 'Should still be active');
}

#[test]
#[should_panic(expected: ('Voting has already ended',))]
fn test_end_voting_period() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "End Period Test", "Testing end voting period", 'OTHER');

    // Start voting period first
    voting_mechanism.start_voting_period(proposal_id, 3600_u64);
    assert(voting_mechanism.is_voting_active(proposal_id), 'Should be active after start');

    // End voting period
    voting_mechanism.end_voting_period(proposal_id);

    let period_end = voting_mechanism.get_voting_period(proposal_id);
    cheat_block_timestamp(
        voting_mechanism.contract_address, period_end + 1, CheatSpan::TargetCalls(1),
    );

    // Now check if voting is inactive
    assert(!voting_mechanism.is_voting_active(proposal_id), 'Should be inactive after end');

    // Attempt to vote after expiry should fail
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
    assert(
        voting_mechanism.get_vote_weight(proposal_id, shareholder) == 0_u256,
        'Should not be able to vote',
    );
    // This should either fail or not count the vote
}

#[test]
fn test_finalize_proposal_status() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();

    // Setup shareholders
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    music_token.transfer(shareholder1, 60_u256); // Majority
    music_token.transfer(shareholder2, 30_u256);

    // Create proposal
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Finalize Test", "Testing proposal finalization", 'OTHER');

    // Vote with majority for approval
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    cheat_caller_address(
        voting_mechanism.contract_address, shareholder2, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.cast_vote(proposal_id, VoteType::Against, token_address);

    // End voting period to allow finalization
    voting_mechanism.end_voting_period(proposal_id);

    // Check and finalize proposal
    let final_status = voting_mechanism.finalize_proposal_status(proposal_id, token_address);
    assert(final_status == 1, 'Should be approved status'); // Approved
}

#[test]
fn test_proposal_finalization_with_insufficient_votes() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup with minimal votes
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256); // Only 10% of total supply

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Low Vote Test", "Testing low votes", 'OTHER');

    // Vote with insufficient tokens to meet threshold
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    // End voting period
    voting_mechanism.end_voting_period(proposal_id);

    // Finalize should result in rejection due to insufficient votes
    let final_status = voting_mechanism.finalize_proposal_status(proposal_id, token_address);
    assert(final_status == 2, 'Should be rejected'); // 2 = Rejected
}

#[test]
fn test_proposal_finalization_with_updated_threshold() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup with minimal votes
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 25_u256); // Only 25% of total supply

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(
            token_address, "Updated Threshold Test", "Testing updated threshold", 'OTHER',
        );

    // Update threshold to a lower value to allow for finalization
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    voting_mechanism.set_proposal_token_threshold(proposal_id, 25_u8);

    // Vote with insufficient tokens to meet default threshold
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    // End voting period
    voting_mechanism.end_voting_period(proposal_id);

    // Finalize should result in rejection due to insufficient votes
    let final_status = voting_mechanism.finalize_proposal_status(proposal_id, token_address);
    assert(final_status == 1, 'Should be approved'); // 1 = Approved
}

#[test]
fn test_proposal_status_progression() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 60_u256); // Majority

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Status Test", "Testing status progression", 'OTHER');

    // Initial status should be Pending (0)
    let initial_proposal = proposal_system.get_proposal(proposal_id);
    assert(initial_proposal.status == 0, 'Should start as pending');

    // Vote with majority
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    // End voting and finalize
    voting_mechanism.end_voting_period(proposal_id);
    let final_status = voting_mechanism.finalize_proposal_status(proposal_id, token_address);
    assert(final_status == 1, 'Should be approved');

    // Check that proposal status was updated in proposal system
    let final_proposal = proposal_system.get_proposal(proposal_id);
    assert(final_proposal.status == 1, 'Proposal status should update');
}

#[test]
#[should_panic(expected: ('Voting period is still active',))]
fn test_cannot_finalize_active_voting() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 30_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Active Test", "Testing active voting", 'OTHER');

    // Start voting period
    voting_mechanism.start_voting_period(proposal_id, 3600_u64);

    // Attempt to finalize while voting is still active should fail
    voting_mechanism.finalize_proposal_status(proposal_id, token_address);
}

#[test]
fn test_get_proposal_threshold_status() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();

    // Setup shareholders
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    music_token.transfer(shareholder1, 40_u256);
    music_token.transfer(shareholder2, 30_u256);

    // Create proposal
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Threshold Test", "Testing threshold status", 'OTHER');

    // Check threshold status before voting
    let (_meets_threshold_before, total_votes_before, threshold_before) = voting_mechanism
        .get_proposal_threshold_status(proposal_id, token_address);
    assert(total_votes_before == 0_u256, 'Should have no votes initially');
    assert(threshold_before > 0_u256, 'Threshold should be positive');

    // Vote
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    // Check threshold status after voting
    let (_meets_threshold_after, total_votes_after, threshold_after) = voting_mechanism
        .get_proposal_threshold_status(proposal_id, token_address);
    assert(total_votes_after == 40_u256, 'Should have votes after voting');
    assert(threshold_after > 0_u256, 'Threshold should be positive');
}

#[test]
fn test_handle_token_transfer_during_voting_direct() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();

    // Setup shareholders
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    music_token.transfer(shareholder1, 50_u256);
    music_token.transfer(shareholder2, 30_u256);

    // Create proposal and vote
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Transfer Test", "Testing transfer handling", 'OTHER');

    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    // Check initial vote weight
    let initial_weight = voting_mechanism.get_vote_weight(proposal_id, shareholder1);
    assert(initial_weight == 50_u256, 'Initial weight wrong');

    // Directly call handle_token_transfer_during_voting
    voting_mechanism
        .handle_token_transfer_during_voting(proposal_id, shareholder1, shareholder2, 20_u256);

    // Check updated vote weight
    let updated_weight = voting_mechanism.get_vote_weight(proposal_id, shareholder1);
    assert(updated_weight == 30_u256, 'Weight should be reduced');

    // Check vote breakdown was updated
    let breakdown = voting_mechanism.get_vote_breakdown(proposal_id);
    assert(breakdown.votes_for == 30_u256, 'Vote breakdown not updated');
}

#[test]
fn test_all_vote_types() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();
    let shareholder3 = SHAREHOLDER_3();

    // Distribute tokens
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(3));
    music_token.transfer(shareholder1, 20_u256);
    music_token.transfer(shareholder2, 30_u256);
    music_token.transfer(shareholder3, 25_u256);

    // Create proposal
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Vote Types Test", "Testing all vote types", 'OTHER');

    // Cast different vote types
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    let weight1 = voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    cheat_caller_address(
        voting_mechanism.contract_address, shareholder2, CheatSpan::TargetCalls(1),
    );
    let weight2 = voting_mechanism.cast_vote(proposal_id, VoteType::Against, token_address);

    cheat_caller_address(
        voting_mechanism.contract_address, shareholder3, CheatSpan::TargetCalls(1),
    );
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
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();
    let mut spy = spy_events();

    // Setup tokens and proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    music_token.transfer(shareholder1, 30_u256);
    music_token.transfer(shareholder2, 20_u256);

    

    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Tracking Test", "Testing vote tracking", 'OTHER');

    spy
        .assert_emitted(
            @array![
                (
                    proposal_system.contract_address,
                    ProposalSystem::Event::ProposalCreated(
                        ProposalCreated {
                            proposal_id,
                            token_contract: token_address,
                            proposer: shareholder1,
                            category: 'OTHER',
                            title: "Tracking Test"
                        },
                    ),
                ),
            ],
        );

    // Test initial state
    assert(!voting_mechanism.has_voted(proposal_id, shareholder1), 'Should not have voted yet');
    assert(voting_mechanism.get_voter_count(proposal_id) == 0, 'Should have 0 voters initially');
    assert(
        voting_mechanism.get_vote_weight(proposal_id, shareholder1) == 0,
        'Should have 0 weight initially',
    );

    // Cast votes
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
    spy
        .assert_emitted(
            @array![
                (
                    voting_mechanism.contract_address,
                    VotingMechanism::Event::VoteCast(
                        VoteCast {
                            voter: shareholder1,
                            proposal_id,
                            vote_type: VoteType::For,
                            weight: 30,
                        },
                    ),
                ),
            ],
        );

    cheat_caller_address(
        voting_mechanism.contract_address, shareholder2, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.cast_vote(proposal_id, VoteType::Against, token_address);

    // Test tracking function
    assert(voting_mechanism.has_voted(proposal_id, shareholder1), 'Should have voted');
    assert(voting_mechanism.has_voted(proposal_id, shareholder2), 'Should have voted');
    assert(voting_mechanism.get_voter_count(proposal_id) == 2, 'Should have 2 voters');
    assert(
        voting_mechanism.get_vote_weight(proposal_id, shareholder1) == 30_u256, 'Weight mismatch',
    );
    assert(
        voting_mechanism.get_vote_weight(proposal_id, shareholder2) == 20_u256, 'Weight mismatch',
    );
}

#[test]
fn test_voting_period_management() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Period Test", "Testing voting periods", 'OTHER');

    // Test initial state (no period set)
    assert(voting_mechanism.get_voting_period(proposal_id) == 0, 'Should have no period initially');
    assert(!voting_mechanism.is_voting_active(proposal_id), 'Should be active initially');

    // Set voting period to 1 hour from now
    let current_time = get_block_timestamp();
    let end_time = current_time + 3600; // 1 hour
    voting_mechanism.start_voting_period(proposal_id, end_time);

    assert(voting_mechanism.get_voting_period(proposal_id) == end_time, 'Period not set correctly');
    assert(voting_mechanism.is_voting_active(proposal_id), 'Should be active');

    // Simulate time passing beyond voting period
    cheat_block_timestamp(
        voting_mechanism.contract_address, end_time + 1, CheatSpan::TargetCalls(1),
    );
    assert(!voting_mechanism.is_voting_active(proposal_id), 'Should be inactive after period');
}

#[test]
#[should_panic(expect: ('Already voted',))]
fn test_double_voting_fails() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup and vote
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Double Vote Test", "Test", 'OTHER');

    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(2));
    // First vote
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
    // Second vote - this should fail
    voting_mechanism.cast_vote(proposal_id, VoteType::Against, token_address);
}

#[test]
#[should_panic(expected: ('Invalid proposal ID',))]
fn test_vote_on_nonexistent_proposal() {
    let (token_address, artist, _proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 30_u256);

    // Try to vote on proposal that doesn't exist
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(999_u64, VoteType::For, token_address);
}

#[test]
#[should_panic(expected: ('Proposal is not in voting state',))]
fn test_vote_on_finalized_proposal() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 60_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Finalized Test", "Testing finalized", 'OTHER');

    // Artist responds to finalize the proposal
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system.respond_to_proposal(proposal_id, 1, "Approved");

    // Try to vote on finalized proposal - should fail
    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
}

#[test]
#[should_panic(expected: ('Voting period must be > 0',))]
fn test_zero_duration_voting_period() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Zero Duration", "Testing zero duration", 'OTHER');

    // Try to set zero duration - should fail or handle gracefully
    voting_mechanism.start_voting_period(proposal_id, 0_u64);
    // Implementation should validate this appropriately
}

#[test]
#[should_panic(expect: ('No voting power',))]
fn test_zero_balance_voting_fails() {
    let (token_address, _artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();
    let zero_balance_user = SHAREHOLDER_2();

    // Only shareholder has tokens
    cheat_caller_address(token_address, _artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Zero Balance Test", "Test", 'OTHER');

    // User with zero balance tries to vote
    cheat_caller_address(
        voting_mechanism.contract_address, zero_balance_user, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);
}

#[test]
#[should_panic(expect: ('Cannot delegate to self',))]
fn test_self_delegation_fails() {
    let (token_address, _artist, _proposal_system, voting_mechanism, _token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    cheat_caller_address(voting_mechanism.contract_address, shareholder, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(token_address, shareholder);
}

#[test]
fn test_voting_events() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();

    // Setup and create proposal
    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(2));
    music_token.transfer(shareholder1, 30_u256);
    music_token.transfer(shareholder2, 20_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Vote Test", "Testing votes", 'OTHER');

    let mut spy = spy_events();

    // Test voting events
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.cast_vote(proposal_id, VoteType::For, token_address);

    spy
        .assert_emitted(
            @array![
                (
                    voting_mechanism.contract_address,
                    VotingMechanism::Event::VoteCast(
                        VoteCast {
                            proposal_id,
                            voter: shareholder1,
                            vote_type: VoteType::For,
                            weight: 30_u256,
                        },
                    ),
                ),
            ],
        );

    // Test delegation events
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder2, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.delegate_vote(token_address, shareholder1);

    spy
        .assert_emitted(
            @array![
                (
                    voting_mechanism.contract_address,
                    VotingMechanism::Event::VoteDelegated(
                        VoteDelegated { delegator: shareholder2, delegate: shareholder1 },
                    ),
                ),
            ],
        );
}

#[test]
fn test_voting_period_events() {
    let (token_address, artist, proposal_system, voting_mechanism, music_token, _) =
        setup_governance_environment();
    let shareholder = SHAREHOLDER_1();

    cheat_caller_address(token_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder, 10_u256);

    cheat_caller_address(proposal_system.contract_address, shareholder, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(token_address, "Period Events", "Testing period events", 'OTHER');

    let mut spy = spy_events();

    // Start voting period
    voting_mechanism.start_voting_period(proposal_id, 3600_u64);

    spy
        .assert_emitted(
            @array![
                (
                    voting_mechanism.contract_address,
                    VotingMechanism::Event::VotingPeriodStarted(
                        VotingPeriodStarted {
                            proposal_id,
                            end_timestamp: get_block_timestamp() + 3600_u64,
                            duration_seconds: 3600_u64,
                        },
                    ),
                ),
            ],
        );

    // End voting period
    voting_mechanism.end_voting_period(proposal_id);

    spy
        .assert_emitted(
            @array![
                (
                    voting_mechanism.contract_address,
                    VotingMechanism::Event::VotingPeriodEnded(
                        VotingPeriodEnded {
                            proposal_id,
                            final_status: 2, // Rejected (no votes)
                            votes_for: 0_u256,
                            votes_against: 0_u256,
                            votes_abstain: 0_u256,
                        },
                    ),
                ),
            ],
        );
}

// ============================================================================
// GOVERNANCE TOKEN TESTS
// ============================================================================

#[test]
fn test_governance_token_basic_functionality() {
    let owner = OWNER();

    let (_token_address, _, proposal_system, voting_mechanism, _music_token, governance_token) =
        setup_governance_environment();

    // Test governance contracts are set correctly after deployment
    let (proposal_addr, voting_addr) = governance_token.get_governance_contracts();
    assert(proposal_addr == proposal_system.contract_address, 'Proposal system mismatch');
    assert(voting_addr == voting_mechanism.contract_address, 'Voting mechanism mismatch');

    let gov_token = IERC20MixinDispatcher { contract_address: governance_token.contract_address };
    let gov_token_ext = IERC20ExtensionDispatcher {
        contract_address: governance_token.contract_address,
    };

    // Test basic and extended ERC20 functions work through the token wrappers
    assert(gov_token.total_supply() == 1000_u256, 'Total supply mismatch');
    assert(gov_token.balance_of(owner) == 1000_u256, 'Owner balance mismatch');
    assert(gov_token_ext.get_decimals() == 6, 'Decimals mismatch');

    cheat_caller_address(governance_token.contract_address, owner, CheatSpan::TargetCalls(1));
    gov_token_ext.burn(500_u256);

    // Check balance after burning
    assert(gov_token.balance_of(owner) == 500_u256, 'Balance after burn wrong');

    // Check total supply decreased
    assert(gov_token.total_supply() == 500_u256, 'Total supply wrong after burn');
}

#[test]
fn test_governance_token_transfer_during_voting() {
    let (
        _token_address, _artist, proposal_system, voting_mechanism, _music_token, governance_token,
    ) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let mut spy = spy_events();
    let shareholder2 = SHAREHOLDER_2();
    let owner = OWNER();

    let gov_token = IERC20MixinDispatcher { contract_address: governance_token.contract_address };
    let gov_token_address = gov_token.contract_address;
    assert(gov_token.balance_of(owner) == 1000_u256, 'Owner balance mismatch');
    assert(gov_token_address == gov_token_address, 'Token address mismatch');

    // Setup initial token distribution using underlying token
    cheat_caller_address(gov_token_address, owner, CheatSpan::TargetCalls(2));
    gov_token.transfer(shareholder1, 300_u256);
    gov_token.transfer(shareholder2, 200_u256);

    // Create a proposal (this should be tracked as active)
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(
            gov_token_address, "Test Proposal", "Testing governance transfers", 'REVENUE',
        );

    // Shareholder1 votes on the proposal
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    let vote_weight = voting_mechanism.cast_vote(proposal_id, VoteType::For, gov_token_address);
    assert(vote_weight == 300_u256, 'Initial vote weight wrong');

    // Check initial vote breakdown
    let initial_breakdown = voting_mechanism.get_vote_breakdown(proposal_id);
    assert(initial_breakdown.votes_for == 300_u256, 'Initial votes_for wrong');
    assert(initial_breakdown.votes_against == 0_u256, 'Initial votes_against wrong');
    assert(initial_breakdown.total_voters == 1, 'Initial voter count wrong');

    let mut spy = spy_events();

    // Transfer tokens during voting period using governance token
    cheat_caller_address(gov_token_address, shareholder1, CheatSpan::TargetCalls(1));

    // Now use governance token transfer function to trigger governance hooks
    gov_token.transfer(shareholder2, 100_u256);

    // Check that GovernanceTransfer event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    governance_token.contract_address,
                    GovernanceToken::Event::GovernanceTokenTransfer(
                        GovernanceToken::GovernanceTokenTransfer {
                            from: shareholder1,
                            to: shareholder2,
                            amount: 100_u256,
                            active_proposals_affected: 1,
                        },
                    ),
                ),
            ],
        );

    // Verify that voting weights were updated by the governance system
    let updated_weight = voting_mechanism.get_vote_weight(proposal_id, shareholder1);
    assert(updated_weight == 200_u256, 'Vote weight should be reduced');

    // Check updated vote breakdown
    let updated_breakdown = voting_mechanism.get_vote_breakdown(proposal_id);
    assert(updated_breakdown.votes_for == 200_u256, 'Updated votes_for wrong');
    assert(updated_breakdown.total_voters == 1, 'Voter count should stay same');
}

#[test]
fn test_governance_token_transfer_invalidates_insufficient_vote() {
    let (
        _token_address, _artist, proposal_system, voting_mechanism, _music_token, governance_token,
    ) =
        setup_governance_environment();
    let owner = OWNER();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();

    let mut spy = spy_events();

    // Setup: shareholder1 gets exactly 100 tokens using underlying token
    let gov_token = IERC20MixinDispatcher { contract_address: governance_token.contract_address };
    let gov_token_address = gov_token.contract_address;
    cheat_caller_address(gov_token_address, owner, CheatSpan::TargetCalls(1));
    gov_token.transfer(shareholder1, 100_u256);

    // Create proposal and vote
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(
            gov_token_address, "Invalidation Test", "Testing vote invalidation", 'OTHER',
        );

    spy
        .assert_emitted(
            @array![
                (
                    proposal_system.contract_address,
                    ProposalSystem::Event::ProposalCreated(
                        ProposalCreated {
                            proposal_id,
                            token_contract: gov_token_address,
                            proposer: shareholder1,
                            category: 'OTHER',
                            title: "Invalidation Test",
                        },
                    ),
                ),
            ],
        );


    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.cast_vote(proposal_id, VoteType::For, gov_token_address);

    spy
        .assert_emitted(
            @array![
                (
                    voting_mechanism.contract_address,
                    VotingMechanism::Event::VoteCast(
                        VoteCast {
                            proposal_id,
                            voter: shareholder1,
                            vote_type: VoteType::For,
                            weight: 100_u256 // All 3 proposals should be affected
                        },
                    ),
                ),
            ],
        );

    // Verify initial vote
    let initial_breakdown = voting_mechanism.get_vote_breakdown(proposal_id);
    assert(initial_breakdown.votes_for == 100_u256, 'Initial vote wrong');

    // Transfer with governance token to trigger governance hooks
    cheat_caller_address(gov_token_address, shareholder1, CheatSpan::TargetCalls(1));

    // Now use governance token transfer function to trigger governance hooks
    gov_token.transfer(shareholder2, 100_u256);

    // Check that vote was invalidated
    let final_breakdown = voting_mechanism.get_vote_breakdown(proposal_id);
    assert(final_breakdown.votes_for == 0_u256, 'Vote should be invalidated');

    let final_weight = voting_mechanism.get_vote_weight(proposal_id, shareholder1);
    assert(final_weight == 0_u256, 'Vote weight should be zero');
}

#[test]
fn test_governance_token_delegation_weight_updates() {
    let (
        _token_address, _artist, proposal_system, voting_mechanism, _music_token, governance_token,
    ) =
        setup_governance_environment();
    let owner = OWNER();
    let delegator = SHAREHOLDER_1();
    let delegate = SHAREHOLDER_2();
    let token_sender = SHAREHOLDER_3();

    // Setup initial distribution using governance token
    let gov_token = IERC20MixinDispatcher { contract_address: governance_token.contract_address };
    let gov_token_address = gov_token.contract_address;
    cheat_caller_address(gov_token_address, owner, CheatSpan::TargetCalls(3));
    gov_token.transfer(delegator, 200_u256);
    gov_token.transfer(delegate, 150_u256);
    gov_token.transfer(token_sender, 250_u256);

    // Create proposal
    cheat_caller_address(proposal_system.contract_address, delegator, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(
            gov_token_address, "Delegation Test", "Testing delegation updates", 'MARKETING',
        );

    // Set up delegation
    cheat_caller_address(voting_mechanism.contract_address, delegator, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(gov_token_address, delegate);

    // Delegate votes (with their own + delegated power)
    cheat_caller_address(voting_mechanism.contract_address, delegate, CheatSpan::TargetCalls(1));
    let initial_weight = voting_mechanism.cast_vote(proposal_id, VoteType::For, gov_token_address);
    assert(initial_weight == 350_u256, 'Initial delegate weight wrong');

    // Transfer tokens to delegator during voting using governance token
    cheat_caller_address(gov_token_address, token_sender, CheatSpan::TargetCalls(1));
    gov_token.approve(owner, 250_u256);
    cheat_caller_address(gov_token_address, owner, CheatSpan::TargetCalls(1));
    gov_token.transfer_from(token_sender, delegator, 100_u256);

    // Check that delegate's effective voting power was updated
    let updated_weight = voting_mechanism.get_vote_weight(proposal_id, delegate);
    assert(
        updated_weight == 450_u256, 'Delegate weight should increase',
    ); // 150 + 200 from delegation + 100 from transfer

    let breakdown = voting_mechanism.get_vote_breakdown(proposal_id);
    assert(breakdown.votes_for == 450_u256, 'Votes should reflect delegation');
}

#[test]
fn test_governance_token_multiple_active_proposals() {
    let (_, _, proposal_system, voting_mechanism, _, governance_token) =
        setup_governance_environment();
    let owner = OWNER();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();

    // Setup tokens using governance token
    let gov_token = IERC20MixinDispatcher { contract_address: governance_token.contract_address };
    let gov_token_address = gov_token.contract_address;
    cheat_caller_address(gov_token_address, owner, CheatSpan::TargetCalls(2));
    gov_token.transfer(shareholder1, 400_u256);
    gov_token.transfer(shareholder2, 300_u256);

    // Create multiple active proposals
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(3));
    let proposal_id1 = proposal_system
        .submit_proposal(gov_token_address, "Proposal 1", "First active", 'REVENUE');
    let proposal_id2 = proposal_system
        .submit_proposal(gov_token_address, "Proposal 2", "Second proposal", 'MARKETING');
    let proposal_id3 = proposal_system
        .submit_proposal(gov_token_address, "Proposal 3", "Third proposal", 'CREATIVE');

    // Vote on all proposals
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(3),
    );
    voting_mechanism.cast_vote(proposal_id1, VoteType::For, gov_token_address);
    voting_mechanism.cast_vote(proposal_id2, VoteType::Against, gov_token_address);
    voting_mechanism.cast_vote(proposal_id3, VoteType::Abstain, gov_token_address);

    // Verify initial votes
    assert(
        voting_mechanism.get_vote_breakdown(proposal_id1).votes_for == 400_u256, 'P1 initial wrong',
    );
    assert(
        voting_mechanism.get_vote_breakdown(proposal_id2).votes_against == 400_u256,
        'P2 initial wrong',
    );
    assert(
        voting_mechanism.get_vote_breakdown(proposal_id3).votes_abstain == 400_u256,
        'P3 initial wrong',
    );

    let mut spy = spy_events();

    // Transfer tokens using governance token to trigger governance hooks
    cheat_caller_address(gov_token_address, shareholder1, CheatSpan::TargetCalls(1));
    gov_token.approve(shareholder1, 150_u256);

    cheat_caller_address(gov_token.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    gov_token.transfer_from(shareholder1, shareholder2, 150_u256);

    // Check that transfer affected all 3 active proposals
    spy
        .assert_emitted(
            @array![
                (
                    governance_token.contract_address,
                    GovernanceToken::Event::GovernanceTokenTransfer(
                        GovernanceToken::GovernanceTokenTransfer {
                            from: shareholder1,
                            to: shareholder2,
                            amount: 150_u256,
                            active_proposals_affected: 3 // All 3 proposals should be affected
                        },
                    ),
                ),
            ],
        );

    // Verify all proposal votes were updated
    assert(
        voting_mechanism.get_vote_breakdown(proposal_id1).votes_for == 250_u256, 'P1 final wrong',
    );
    assert(
        voting_mechanism.get_vote_breakdown(proposal_id2).votes_against == 250_u256,
        'P2 final wrong',
    );
    assert(
        voting_mechanism.get_vote_breakdown(proposal_id3).votes_abstain == 250_u256,
        'P3 final wrong',
    );
}

#[test]
fn test_token_transfer_updates_multiple_delegations() {
    let (
        _token_address, _artist, proposal_system, voting_mechanism, _music_token, governance_token,
    ) =
        setup_governance_environment();
    let delegator1 = SHAREHOLDER_1();
    let delegator2 = SHAREHOLDER_2();
    let delegate = SHAREHOLDER_3();
    let owner = OWNER();

    // Setup governance token balances
    let gov_token = IERC20MixinDispatcher { contract_address: governance_token.contract_address };
    let gov_token_address = gov_token.contract_address;

    cheat_caller_address(governance_token.contract_address, owner, CheatSpan::TargetCalls(3));
    gov_token.transfer(delegator1, 200_u256);
    gov_token.transfer(delegator2, 150_u256);
    gov_token.transfer(delegate, 100_u256);

    // Create proposal
    cheat_caller_address(proposal_system.contract_address, delegator1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(gov_token_address, "Multi Delegation", "Testing", 'OTHER');

    // Set up delegations
    cheat_caller_address(voting_mechanism.contract_address, delegator1, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(gov_token_address, delegate);

    cheat_caller_address(voting_mechanism.contract_address, delegator2, CheatSpan::TargetCalls(1));
    voting_mechanism.delegate_vote(gov_token_address, delegate);

    // Delegate votes
    cheat_caller_address(voting_mechanism.contract_address, delegate, CheatSpan::TargetCalls(1));
    voting_mechanism.cast_vote(proposal_id, VoteType::For, governance_token.contract_address);

    // Transfer tokens between delegators (should update delegate's effective power)
    cheat_caller_address(governance_token.contract_address, delegator1, CheatSpan::TargetCalls(1));
    gov_token.transfer(delegator2, 50_u256);

    // Check that delegate's voting weight reflects the delegation changes
    let updated_weight = voting_mechanism.get_vote_weight(proposal_id, delegate);
    assert(updated_weight == 450_u256, 'Delegate weight shouldnt update');
}

#[test]
fn test_full_governance_workflow() {
    let (_token_address, artist, proposal_system, voting_mechanism, music_token, governance_token) =
        setup_governance_environment();
    let shareholder1 = SHAREHOLDER_1();
    let shareholder2 = SHAREHOLDER_2();
    let owner = OWNER();

    // Complete workflow: proposal creation → voting → finalization → response
    let gov_token = IERC20MixinDispatcher { contract_address: governance_token.contract_address };
    cheat_caller_address(governance_token.contract_address, owner, CheatSpan::TargetCalls(2));
    gov_token.transfer(shareholder1, 300_u256);
    gov_token.transfer(shareholder2, 200_u256);

    cheat_caller_address(music_token.contract_address, artist, CheatSpan::TargetCalls(1));
    music_token.transfer(shareholder1, 50_u256);

    // 1. Create proposal
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    let proposal_id = proposal_system
        .submit_proposal(music_token.contract_address, "Full Workflow", "Complete test", 'REVENUE');

    // 2. Start voting period
    voting_mechanism.start_voting_period(proposal_id, 3600_u64);

    // 3. Cast votes
    cheat_caller_address(
        voting_mechanism.contract_address, shareholder1, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.cast_vote(proposal_id, VoteType::For, governance_token.contract_address);

    cheat_caller_address(
        voting_mechanism.contract_address, shareholder2, CheatSpan::TargetCalls(1),
    );
    voting_mechanism.cast_vote(proposal_id, VoteType::For, governance_token.contract_address);

    // 4. Add comments
    cheat_caller_address(proposal_system.contract_address, shareholder1, CheatSpan::TargetCalls(1));
    proposal_system.add_comment(proposal_id, "Great proposal!");

    // 5. End voting period
    voting_mechanism.end_voting_period(proposal_id);

    // 6. Finalize proposal
    let final_status = voting_mechanism
        .finalize_proposal_status(proposal_id, governance_token.contract_address);
    assert(final_status == 1, 'Should be approved');

    // 7. Artist responds
    cheat_caller_address(proposal_system.contract_address, artist, CheatSpan::TargetCalls(1));
    proposal_system.respond_to_proposal(proposal_id, 3, "Implemented successfully");

    // Verify final state
    let final_proposal = proposal_system.get_proposal(proposal_id);
    assert(final_proposal.status == 3, 'Should be implemented');
}
