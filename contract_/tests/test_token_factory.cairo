use contract_::erc20::MusicStrk;
use contract_::token_factory::{
    IMusicShareToken, IMusicShareTokenDispatcher, IMusicShareTokenDispatcherTrait,
    IMusicShareTokenFactoryDispatcher, IMusicShareTokenFactoryDispatcherTrait,
    MusicShareTokenFactory,
};
use core::array::ArrayTrait;
use core::byte_array::ByteArrayTrait;
use core::result::ResultTrait;
use core::traits::Into;
use openzeppelin::token::erc20::interface::{ 
    IERC20MixinDispatcher, IERC20MixinDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::{class_hash::ClassHash, ContractAddress, contract_address_const, get_caller_address};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_caller_address, declare, spy_events,
};


// Address constants for testing
fn ARTIST_1() -> ContractAddress {
    contract_address_const::<'artist_1'>()
}

fn ARTIST_2() -> ContractAddress {
    contract_address_const::<'artist_2'>()
}

fn NON_AUTH() -> ContractAddress {
    contract_address_const::<'non-auth'>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn ZERO_ADDRESS() -> ContractAddress {
    contract_address_const::<0>()
}

// Constants
fn MUSICSTRK_HASH() -> ClassHash {
    let music_token_class_hash = declare("MusicStrk").unwrap();
    MusicStrk::TEST_CLASS_HASH.try_into().unwrap()
}

const TOTAL_SHARES: u256 = 100_u256;

/// Helper function to setup token test data
fn setup_token_data() -> (ByteArray, ByteArray, u8, ByteArray) {
    // Set up test parameters
    let name = "Test Music Token";
    let symbol = "TMT";
    let decimals = 18_u8;
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
    // Define factory deployer (owner)
    let owner = OWNER();

    // Deploy music share token factory
    let (factory_address, factory_dispatcher) = deploy_music_share_token_factory(owner);

    // Setup test data
    let artist_1 = ARTIST_1();
    let (name, symbol, decimals, metadata_uri) = setup_token_data();

    // Start calls as the deployer (owner)
    cheat_caller_address(factory_address, owner, CheatSpan::TargetCalls(1));

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
    assert(erc20_token.balance_of(owner.into()) == TOTAL_SHARES, 'Balance should be 100 tokens');
}

// fn test_deploy_music_share_token_event() {
//     // Deploy music share token factory
//     let (factory_address, factory_contract) = deploy_music_share_token_factory(OWNER());

//     // Setup test data
//     let artist_1 = ARTIST_1();
//     let (name, symbol, decimals, metadata_uri) = setup_token_data();

//     // Start calls as the artist
//     cheat_caller_address(factory_address, artist_1, CheatSpan::TargetCalls(1));

//     // Spy on events
//     let mut event_spy = spy_events();

//     // Deploy a token through the factory
//     let token_address = factory_contract
//         .deploy_music_token(name.into(), symbol.into(), decimals, metadata_uri.into());

//     event_spy
//         .assert_emitted(
//             @array![
//                 (
//                     factory_address,
//                     MusicShareTokenFactory::Event::TokenDeployedEvent(
//                         MusicShareTokenFactory::TokenDeployedEvent {
//                             deployer: artist_1,
//                             token_address,
//                             name: name.clone(),
//                             symbol: symbol.clone(),
//                             metadata_uri: metadata_uri.clone(),
//                         },
//                     ),
//                 ),
//             ],
//         );
// }

// #[test]
// fn test_multiple_tokens_per_artist() {
//     // Declare the token class
//     let music_token_class = declare("MusicStrk").unwrap();
//     let music_token_hash = music_token_class.class_hash;

//     // Deploy the factory
//     let factory_constructor_args = array![OWNER.into(), music_token_hash.into()];
//     let factory_address = deploy(
//         MusicShareTokenFactory::TEST_CLASS_HASH, factory_constructor_args.span()
//     ).unwrap();
//     let factory = IMusicShareTokenFactoryDispatcher { contract_address: factory_address };

//     // Start acting as the artist
//     start_prank(CheatTarget::One(factory_address), ARTIST_1.into());

//     // Deploy first token
//     let token1_address = factory.deploy_music_token(
//         "First Album".into(), "FA".into(), 18_u8, "ipfs://first-uri".into()
//     );

//     // Deploy second token
//     let token2_address = factory.deploy_music_token(
//         "Second Album".into(), "SA".into(), 18_u8, "ipfs://second-uri".into()
//     );

//     // Stop acting as the artist
//     stop_prank(CheatTarget::One(factory_address));

//     // Verify token count and registration
//     assert(factory.get_token_count() == 2, 'Token count should be 2');
//     assert(factory.get_token_at_index(0) == token1_address, 'First token address mismatch');
//     assert(factory.get_token_at_index(1) == token2_address, 'Second token address mismatch');

//     // Verify artist tokens
//     let artist_tokens = factory.get_tokens_by_artist(ARTIST_1.into());
//     assert(artist_tokens.len() == 2, 'Artist should have 2 tokens');
//     assert(artist_tokens.at(0) == @token1_address, 'First artist token mismatch');
//     assert(artist_tokens.at(1) == @token2_address, 'Second artist token mismatch');

//     // Verify all tokens retrieval
//     let all_tokens = factory.get_all_tokens();
//     assert(all_tokens.len() == 2, 'Should return 2 tokens total');
//     assert(all_tokens.at(0) == @token1_address, 'First token mismatch in all tokens');
//     assert(all_tokens.at(1) == @token2_address, 'Second token mismatch in all tokens');
// }

// #[test]
// fn test_multiple_artists() {
//     // Declare the token class
//     let music_token_class = declare("MusicStrk").unwrap();
//     let music_token_hash = music_token_class.class_hash;

//     // Deploy the factory
//     let factory_constructor_args = array![OWNER.into(), music_token_hash.into()];
//     let factory_address = deploy(
//         MusicShareTokenFactory::TEST_CLASS_HASH, factory_constructor_args.span()
//     ).unwrap();
//     let factory = IMusicShareTokenFactoryDispatcher { contract_address: factory_address };

//     // Artist 1 deploys a token
//     start_prank(CheatTarget::One(factory_address), ARTIST_1.into());
//     let token1_address = factory.deploy_music_token(
//         "Artist 1 Album".into(), "A1A".into(), 18_u8, "ipfs://artist1-uri".into()
//     );
//     stop_prank(CheatTarget::One(factory_address));

//     // Artist 2 deploys a token
//     start_prank(CheatTarget::One(factory_address), ARTIST_2.into());
//     let token2_address = factory.deploy_music_token(
//         "Artist 2 Album".into(), "A2A".into(), 18_u8, "ipfs://artist2-uri".into()
//     );
//     stop_prank(CheatTarget::One(factory_address));

//     // Verify token count
//     assert(factory.get_token_count() == 2, 'Token count should be 2');

//     // Verify Artist 1 tokens
//     let artist1_tokens = factory.get_tokens_by_artist(ARTIST_1.into());
//     assert(artist1_tokens.len() == 1, 'Artist 1 should have 1 token');
//     assert(artist1_tokens.at(0) == @token1_address, 'Artist 1 token mismatch');

//     // Verify Artist 2 tokens
//     let artist2_tokens = factory.get_tokens_by_artist(ARTIST_2.into());
//     assert(artist2_tokens.len() == 1, 'Artist 2 should have 1 token');
//     assert(artist2_tokens.at(0) == @token2_address, 'Artist 2 token mismatch');

//     // Verify token balances
//     let token1 = IERC20Dispatcher { contract_address: token1_address };
//     let token2 = IERC20Dispatcher { contract_address: token2_address };

//     assert(token1.balance_of(ARTIST_1.into()) == TOTAL_SHARES, 'Artist 1 should have 100
//     tokens');
//     assert(token2.balance_of(ARTIST_2.into()) == TOTAL_SHARES, 'Artist 2 should have 100
//     tokens');
// }

// #[test]
// fn test_token_functionality() {
//     // Declare the token class
//     let music_token_class = declare("MusicStrk").unwrap();
//     let music_token_hash = music_token_class.class_hash;

//     // Deploy the factory
//     let factory_constructor_args = array![OWNER.into(), music_token_hash.into()];
//     let factory_address = deploy(
//         MusicShareTokenFactory::TEST_CLASS_HASH, factory_constructor_args.span()
//     ).unwrap();
//     let factory = IMusicShareTokenFactoryDispatcher { contract_address: factory_address };

//     // Deploy a token
//     start_prank(CheatTarget::One(factory_address), ARTIST_1.into());
//     let token_address = factory.deploy_music_token(
//         "Functional Test".into(), "FT".into(), 18_u8, "ipfs://functional-test".into()
//     );
//     stop_prank(CheatTarget::One(factory_address));

//     // Get ERC20 interface
//     let token = IERC20Dispatcher { contract_address: token_address };

//     // Test transfer functionality
//     start_prank(CheatTarget::One(token_address), ARTIST_1.into());
//     token.transfer(ARTIST_2.into(), 10_u256);
//     stop_prank(CheatTarget::One(token_address));

//     // Verify balances after transfer
//     assert(token.balance_of(ARTIST_1.into()) == 90_u256, 'Artist 1 should have 90 tokens');
//     assert(token.balance_of(ARTIST_2.into()) == 10_u256, 'Artist 2 should have 10 tokens');

//     // Test approval and transferFrom
//     start_prank(CheatTarget::One(token_address), ARTIST_2.into());
//     token.approve(ARTIST_1.into(), 5_u256);
//     stop_prank(CheatTarget::One(token_address));

//     start_prank(CheatTarget::One(token_address), ARTIST_1.into());
//     token.transfer_from(ARTIST_2.into(), ARTIST_1.into(), 5_u256);
//     stop_prank(CheatTarget::One(token_address));

//     // Verify balances after transferFrom
//     assert(token.balance_of(ARTIST_1.into()) == 95_u256, 'Artist 1 should have 95 tokens');
//     assert(token.balance_of(ARTIST_2.into()) == 5_u256, 'Artist 2 should have 5 tokens');
// }

// #[test]
// #[should_panic(expected: ('Index out of bounds', 'ENTRYPOINT_FAILED'))]
// fn test_invalid_token_index() {
//     // Declare the token class
//     let music_token_class = declare("MusicStrk").unwrap();
//     let music_token_hash = music_token_class.class_hash;

//     // Deploy the factory
//     let factory_constructor_args = array![OWNER.into(), music_token_hash.into()];
//     let factory_address = deploy(
//         MusicShareTokenFactory::TEST_CLASS_HASH, factory_constructor_args.span()
//     ).unwrap();
//     let factory = IMusicShareTokenFactoryDispatcher { contract_address: factory_address };

//     // No tokens deployed, so index 0 should fail
//     factory.get_token_at_index(0);
// }

// #[test]
// fn test_gas_measurement() {
//     // This is a simplified gas measurement example
//     // In a real scenario, you would use a gas profiling tool or framework

//     // Declare the token class
//     let music_token_class = declare("MusicStrk").unwrap();
//     let music_token_hash = music_token_class.class_hash;

//     // Deploy the factory
//     let factory_constructor_args = array![OWNER.into(), music_token_hash.into()];
//     let factory_address = deploy(
//         MusicShareTokenFactory::TEST_CLASS_HASH, factory_constructor_args.span()
//     ).unwrap();
//     let factory = IMusicShareTokenFactoryDispatcher { contract_address: factory_address };

//     // Start acting as the artist
//     start_prank(CheatTarget::One(factory_address), ARTIST_1.into());

//     // Deploy a token and note that in a real test framework you would measure gas here
//     let token_address = factory.deploy_music_token(
//         "Gas Test".into(), "GT".into(), 18_u8, "ipfs://gas-test".into()
//     );

//     // Print the result - in a real scenario this would include gas measurements
//     println!("Deployed token at: {}", token_address.into());

//     stop_prank(CheatTarget::One(factory_address));
// }

// #[test]
// fn test_unauthorized_deployment() {
//     // Declare the token class
//     let music_token_class = declare("MusicStrk").unwrap();
//     let music_token_hash = music_token_class.class_hash;

//     // Deploy the factory with restricted deployment permissions
//     // In this scenario, we assume only the owner and approved artists can deploy
//     let factory_constructor_args = array![OWNER.into(), music_token_hash.into()];
//     let factory_address = deploy(
//         MusicShareTokenFactory::TEST_CLASS_HASH, factory_constructor_args.span()
//     ).unwrap();
//     let factory = IMusicShareTokenFactoryDispatcher { contract_address: factory_address };

//     // Set up test parameters
//     let name = "Unauthorized Test";
//     let symbol = "UT";
//     let decimals = 18_u8;
//     let metadata_uri = "ipfs://unauthorized-test";

//     // First, let's verify the owner can deploy
//     start_prank(CheatTarget::One(factory_address), OWNER.into());
//     let owner_token = factory.deploy_music_token(
//         name.into(), symbol.into(), decimals, metadata_uri.into()
//     );
//     stop_prank(CheatTarget::One(factory_address));

//     // Verify the token was deployed successfully
//     assert(factory.is_token_deployed(owner_token), 'Owner token should be deployed');

//     // Now verify that an authorized artist can deploy
//     start_prank(CheatTarget::One(factory_address), ARTIST_1.into());
//     let artist_token = factory.deploy_music_token(
//         "Artist Token".into(), "AT".into(), decimals, "ipfs://artist-uri".into()
//     );
//     stop_prank(CheatTarget::One(factory_address));

//     // Verify the token was deployed successfully
//     assert(factory.is_token_deployed(artist_token), 'Artist token should be deployed');

//     // Check token counts
//     assert(factory.get_token_count() == 2, 'Should have 2 tokens deployed');

//     // For this test case, we're demonstrating that any account can technically deploy tokens
//     // In a real-world scenario with authorization, we would add permission checks to the
//     contract // and this test would verify those restrictions

//     // Verify non-authorized account can also deploy (showing no restrictions in current
//     implementation)
//     start_prank(CheatTarget::One(factory_address), NON_AUTHORIZED.into());
//     let unauthorized_token = factory.deploy_music_token(
//         "Unauthorized Token".into(), "UT".into(), decimals, "ipfs://unauthorized-uri".into()
//     );
//     stop_prank(CheatTarget::One(factory_address));

//     // Verify token was deployed
//     assert(factory.is_token_deployed(unauthorized_token), 'Unauthorized token deployed');

//     // Check token counts
//     assert(factory.get_token_count() == 3, 'Should have 3 tokens deployed');

//     // Note: This test shows that the current implementation allows any account to deploy tokens.
//     // If authorization is required, the contract would need to be modified to include
//     // permission checks, and this test would be updated to verify those restrictions.
// }


