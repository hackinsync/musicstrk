use contract_::erc20::{IMusicShareTokenDispatcher, IMusicShareTokenDispatcherTrait, MusicStrk};
use contract_::token_factory::{
    IMusicShareTokenFactoryDispatcher, IMusicShareTokenFactoryDispatcherTrait,
    MusicShareTokenFactory,
};
use contract_::events::{TokenDeployedEvent};
use core::array::ArrayTrait;
use core::result::ResultTrait;
use core::traits::Into;
use openzeppelin::token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_caller_address, declare, spy_events,
};
use starknet::{ContractAddress, get_block_timestamp};
use starknet::class_hash::ClassHash;


// Address constants for testing
fn artist_1() -> ContractAddress {
    'artist_1'.try_into().unwrap()
}

fn artist_2() -> ContractAddress {
    'artist_2'.try_into().unwrap()
}

fn non_auth() -> ContractAddress {
    'non-auth'.try_into().unwrap()
}

fn owner() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn zero() -> ContractAddress {
    0.try_into().unwrap()
}

// Constants
fn MUSICSTRK_HASH() -> ClassHash {
    MusicStrk::TEST_CLASS_HASH.try_into().unwrap()
}

const TOTAL_SHARES: u256 = 100_u256;

/// Helper function to setup token test data
fn setup_token_data() -> (ByteArray, ByteArray, u8, ByteArray) {
    // Set up test parameters
    let name = "Test Music Token";
    let symbol = "TMT";
    let decimals = 6_u8;
    let metadata_uri = "ipfs://QmTestMetadataHash";

    (name, symbol, decimals, metadata_uri)
}

/// Utility functions to deploy the MusicStrk factory contract
fn deploy_music_share_token(owner: ContractAddress) -> (ContractAddress, ClassHash) {
    // Declare the MusicStrk contract to get contract class and class hash
    let contract_class = declare("MusicStrk").unwrap().contract_class();
    let contract_class_hash = contract_class.class_hash;

    // Initialize music share token calldata
    let mut calldata = array![];
    calldata.append_serde(owner);

    // Deploy MusicStrk token contract and return address and class hash
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    (contract_address, *contract_class_hash)
}

fn deploy_music_share_token_factory(
    owner: ContractAddress,
) -> (ContractAddress, IMusicShareTokenFactoryDispatcher) {
    // Deploy the MusicStrk contract to get contract class hash
    let (_, music_token_class_hash) = deploy_music_share_token(owner);

    // Set up factory constructor calldata with relevant arguments
    let factory_class = declare("MusicShareTokenFactory").unwrap().contract_class();
    let mut calldata = array![];

    // Initialize music share token factory calldata
    calldata.append(owner.into());
    calldata.append(music_token_class_hash.into());

    // Deploy the MusicShareTokenFactory contract
    let (factory_address, _) = factory_class.deploy(@calldata).unwrap();
    (factory_address, IMusicShareTokenFactoryDispatcher { contract_address: factory_address })
}

#[test]
fn test_successful_music_share_token_deployment() {
    // Setup test accounts from address constants
    let artist_1 = artist_1();
    let owner = owner();

    // Deploy music share token factory as owner
    let (factory_address, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // Grant artist role before token deployment
    cheat_caller_address(factory_address, owner, CheatSpan::TargetCalls(1));
    factory_dispatcher.grant_artist_role(artist_1);

    // Setup test data
    let (name, symbol, decimals, metadata_uri) = setup_token_data();

    // Start calls as the deployer (artist)
    cheat_caller_address(factory_address, artist_1, CheatSpan::TargetCalls(1));

    // Deploy a token through the factory
    let token_address = factory_dispatcher
        .deploy_music_token(name.clone(), symbol.clone(), decimals, metadata_uri.clone());

    // Verify token registration in factory
    assert(factory_dispatcher.get_token_count() == 1, 'Token count should be 1');
    assert(factory_dispatcher.get_token_at_index(0) == token_address, 'Token address mismatch');
    assert(factory_dispatcher.is_token_deployed(token_address), 'Token should be deployed');

    // Verify token properties using ERC20 interface
    let erc20_token = IERC20MixinDispatcher { contract_address: token_address };
    assert(erc20_token.name() == name.into(), 'Name mismatch');
    assert(erc20_token.symbol() == symbol.into(), 'Symbol mismatch');

    // Get token through the music token interface
    let music_token = IMusicShareTokenDispatcher { contract_address: token_address };
    assert(music_token.get_decimals() == decimals, 'Decimals mismatch');
    assert(music_token.get_metadata_uri() == metadata_uri.into(), 'Metadata URI mismatch');

    // Verify 100 tokens were minted to the deployer
    assert(erc20_token.balance_of(artist_1.into()) == TOTAL_SHARES, 'Balance should be 100 tokens');
}

#[test]
fn test_deploy_music_share_token_event() {
    // Setup test accounts from address constants
    let owner = owner();
    let artist_1 = artist_1();

    // Deploy music share token factory as owner
    let (factory_address, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // Grant artist role before token deployment
    cheat_caller_address(factory_address, owner, CheatSpan::TargetCalls(1));
    factory_dispatcher.grant_artist_role(artist_1);

    // Setup test data
    let (name, symbol, decimals, metadata_uri) = setup_token_data();

    // Start calls as the deployer (artist)
    cheat_caller_address(factory_address, artist_1, CheatSpan::TargetCalls(1));

    // Spy on events
    let mut event_spy = spy_events();

    // Deploy a token through the factory
    let token_address = factory_dispatcher
        .deploy_music_token(name.clone(), symbol.clone(), decimals, metadata_uri.clone());

    event_spy
        .assert_emitted(
            @array![
                (
                    factory_address,
                    MusicShareTokenFactory::Event::TokenDeployedEvent(
                        TokenDeployedEvent {
                            deployer: artist_1,
                            token_address,
                            name: name.into(),
                            symbol: symbol.into(),
                            metadata_uri: metadata_uri.into(),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_multiple_tokens_per_artist() {
    // Setup test accounts from address constants
    let owner = owner();
    let artist_1 = artist_1();

    // Deploy music share token factory
    let (factory_address, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // Grant artist role before token deployment
    cheat_caller_address(factory_address, owner, CheatSpan::TargetCalls(1));
    factory_dispatcher.grant_artist_role(artist_1);

    // Start calls as the deployer (artist)
    cheat_caller_address(factory_address, artist_1, CheatSpan::TargetCalls(2));

    // Deploy first token through the factory
    let token1_address = factory_dispatcher
        .deploy_music_token("First Album", "FA", 6_u8, "ipfs://first-uri");

    // Deploy second token through the factory
    let token2_address = factory_dispatcher
        .deploy_music_token("Second Album", "SA", 6_u8, "ipfs://second-uri");

    // Verify token count and registration
    assert(factory_dispatcher.get_token_count() == 2, 'Token count should be 2');
    assert(
        factory_dispatcher.get_token_at_index(0) == token1_address, 'First token address mismatch',
    );
    assert(
        factory_dispatcher.get_token_at_index(1) == token2_address, 'Second token address mismatch',
    );

    // Verify artist tokens
    let artist_tokens = factory_dispatcher.get_tokens_by_artist(artist_1.into());
    assert(artist_tokens.len() == 2, 'Artist should have 2 tokens');
    assert(artist_tokens.at(0) == @token1_address, 'First artist token mismatch');
    assert(artist_tokens.at(1) == @token2_address, 'Second artist token mismatch');

    // Verify all tokens retrieval
    let all_tokens = factory_dispatcher.get_all_tokens();
    assert(all_tokens.len() == 2, 'Should return 2 tokens total');
    assert(all_tokens.at(0) == @token1_address, 'First token err in all_tokens');
    assert(all_tokens.at(1) == @token2_address, 'Second token err in all_tokens');
}

#[test]
fn test_multiple_artists() {
    // Setup test accounts from address constants
    let owner = owner();
    let artist_1 = artist_1();
    let artist_2 = artist_2();

    // Deploy music share token factory
    let (factory_address, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // Grant artists role before token deployment
    cheat_caller_address(factory_address, owner, CheatSpan::TargetCalls(2));
    factory_dispatcher.grant_artist_role(artist_1);
    factory_dispatcher.grant_artist_role(artist_2);

    // Start calls as the deployer (artist_1)
    cheat_caller_address(factory_address, artist_1, CheatSpan::TargetCalls(1));

    let token1_address = factory_dispatcher
        .deploy_music_token("Artist 1 Album", "A1A", 6_u8, "ipfs://artist1-uri");

    // Start calls as the deployer (artist_2)
    cheat_caller_address(factory_address, artist_2, CheatSpan::TargetCalls(1));

    let token2_address = factory_dispatcher
        .deploy_music_token("Artist 2 Album", "A2A", 6_u8, "ipfs://artist2-uri");

    // Verify token count
    assert(factory_dispatcher.get_token_count() == 2, 'Token count should be 2');

    // Verify Artist 1 tokens
    let artist1_tokens = factory_dispatcher.get_tokens_by_artist(artist_1);
    assert(artist1_tokens.len() == 1, 'Artist 1 token count incorrect');
    assert(artist1_tokens.at(0) == @token1_address, 'Artist 1 token mismatch');

    // Verify Artist 2 tokens
    let artist2_tokens = factory_dispatcher.get_tokens_by_artist(artist_2);
    assert(artist2_tokens.len() == 1, 'Artist 2 token count incorrect');
    assert(artist2_tokens.at(0) == @token2_address, 'Artist 2 token mismatch');

    // Verify token balances
    let token1 = IERC20MixinDispatcher { contract_address: token1_address };
    let token2 = IERC20MixinDispatcher { contract_address: token2_address };

    assert(token1.balance_of(artist_1) == TOTAL_SHARES, 'Artist 1 should have 100 tokens');
    assert(token2.balance_of(artist_2) == TOTAL_SHARES, 'Artist 2 should have 100 tokens');
}

#[test]
fn test_token_functionality() {
    // Setup test accounts from address constants
    let owner = owner();
    let artist_1 = artist_1();
    let artist_2 = artist_2();

    // Deploy music share token factory as owner
    let (factory_address, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // Grant artist role before token deployment
    cheat_caller_address(factory_address, owner, CheatSpan::TargetCalls(2));
    factory_dispatcher.grant_artist_role(artist_1);
    factory_dispatcher.grant_artist_role(artist_2);

    // Setup test data
    let (name, symbol, decimals, metadata_uri) = setup_token_data();

    // Start calls as the deployer (artist_1)
    cheat_caller_address(factory_address, artist_1, CheatSpan::TargetCalls(1));

    // Deploy a token through the factory
    let token_address = factory_dispatcher
        .deploy_music_token(name.clone(), symbol.clone(), decimals, metadata_uri.clone());

    // Get ERC20 interface
    let token = IERC20MixinDispatcher { contract_address: token_address };

    // Test transfer functionality
    cheat_caller_address(token_address, artist_1, CheatSpan::TargetCalls(1));
    token.transfer(artist_2, 10_u256);

    // Verify balances after transfer
    assert(token.balance_of(artist_1) == 90_u256, 'Artist 1 should have 90 tokens');
    assert(token.balance_of(artist_2) == 10_u256, 'Artist 2 should have 10 tokens');

    // Test approval and transferFrom with artist_2
    cheat_caller_address(token_address, artist_2, CheatSpan::TargetCalls(1));
    token.approve(artist_1, 5_u256);

    cheat_caller_address(token_address, artist_1, CheatSpan::TargetCalls(1));
    token.transfer_from(artist_2, artist_1, 5_u256);

    // Verify balances after transferFrom
    assert(token.balance_of(artist_1) == 95_u256, 'Artist 1 should have 95 tokens');
    assert(token.balance_of(artist_2) == 5_u256, 'Artist 2 should have 5 tokens');
}

#[test]
#[should_panic(expect: 'Index out of bounds;')]
fn test_no_deploy_invalid_token_index() {
    // Setup test accounts from address constants
    let owner = owner();

    // Deploy music share token factory as owner
    let (_, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // No tokens deployed, so index 0 should fail
    factory_dispatcher.get_token_at_index(0);
}

#[test]
#[should_panic(expect: 'Not owner or authorized artist')]
fn test_unauthorized_user_deploy_failure() {
    // Setup test accounts from address constants
    let owner = owner();
    let unauthorized_user = non_auth();

    // Deploy music share token factory
    let (factory_address, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // Setup test data
    let (name, symbol, decimals, metadata_uri) = setup_token_data();

    // Attempt to deploy as unauthorized user
    cheat_caller_address(factory_address, unauthorized_user, CheatSpan::TargetCalls(1));

    // This should fail since the user doesn't have artist role
    factory_dispatcher
        .deploy_music_token(name.clone(), symbol.clone(), decimals, metadata_uri.clone());
}

#[test]
fn test_artist_role_management() {
    // Setup test accounts from address constants
    let owner = owner();
    let artist = artist_1();

    // Deploy music share token factory
    let (factory_address, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // Verify initial state - user doesn't have artist role
    assert(!factory_dispatcher.has_artist_role(artist), 'Artist should not have role yet');

    // Grant artist role (as owner)
    cheat_caller_address(factory_address, owner, CheatSpan::TargetCalls(1));
    factory_dispatcher.grant_artist_role(artist);

    // Verify artist role was granted
    assert(factory_dispatcher.has_artist_role(artist), 'Artist should have role');

    // Now artist should be able to deploy a token
    let (name, symbol, decimals, metadata_uri) = setup_token_data();
    cheat_caller_address(factory_address, artist, CheatSpan::TargetCalls(1));

    let token_address = factory_dispatcher
        .deploy_music_token(name.clone(), symbol.clone(), decimals, metadata_uri.clone());

    // Verify token was deployed
    assert(factory_dispatcher.is_token_deployed(token_address), 'Token should be deployed');

    // Revoke artist role (as owner)
    cheat_caller_address(factory_address, owner, CheatSpan::TargetCalls(1));
    factory_dispatcher.revoke_artist_role(artist);

    // Verify artist role was revoked
    assert(!factory_dispatcher.has_artist_role(artist), 'Artist should not have role');
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_grant_artist_role_unauthorized() {
    // Setup test accounts from address constants
    let owner = owner();
    let unauthorized = non_auth();
    let artist = artist_1();

    // Deploy music share token factory
    let (factory_address, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // Try to grant artist role as unauthorized user
    cheat_caller_address(factory_address, unauthorized, CheatSpan::TargetCalls(1));

    // This should fail because only owner can grant artist role
    factory_dispatcher.grant_artist_role(artist);
}

#[test]
fn test_update_token_class_hash() {
    // Setup test accounts from address constants
    let owner = owner();

    // Deploy music share token factory
    let (factory_address, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // Get initial class hash
    let initial_class_hash = factory_dispatcher.get_token_class_hash();

    // Ensure the new class hash is different
    assert(initial_class_hash != MUSICSTRK_HASH(), 'Class hash should be different');

    // Update class hash as owner
    cheat_caller_address(factory_address, owner, CheatSpan::TargetCalls(1));
    factory_dispatcher.update_token_class_hash(MUSICSTRK_HASH());

    // Verify class hash was updated
    assert(factory_dispatcher.get_token_class_hash() == MUSICSTRK_HASH(), 'Class hash not updated');
}

#[test]
#[should_panic(expect: 'Caller is not the owner')]
fn test_update_token_class_hash_unauthorized() {
    // Setup test accounts from address constants
    let owner = owner();
    let unauthorized = non_auth();

    // Deploy music share token factory
    let (factory_address, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // Try to update class hash as unauthorized user
    cheat_caller_address(factory_address, unauthorized, CheatSpan::TargetCalls(1));

    // This should fail because only owner can update class hash
    factory_dispatcher.update_token_class_hash(MUSICSTRK_HASH());
}

#[test]
#[should_panic(expect: 'Result::unwrap failed.')]
fn test_deploy_factory_with_zero_owner() {
    // For this test, we need to modify the deploy function to handle zero address directly
    // Get the token class hash
    let (_, music_token_class_hash) = deploy_music_share_token(owner());

    // Set up factory constructor calldata with zero address as owner
    let factory_class = declare("MusicShareTokenFactory").unwrap().contract_class();
    let mut calldata = array![];

    // Use zero address as owner
    calldata.append(zero().into());
    calldata.append(music_token_class_hash.into());

    // Attempt to deploy with zero address owner - should fail
    let (_, _) = factory_class.deploy(@calldata).unwrap();
}
