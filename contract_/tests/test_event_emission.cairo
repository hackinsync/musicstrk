use contract_::erc20::{
    IMusicShareTokenDispatcher, IMusicShareTokenDispatcherTrait, IBurnableDispatcher,
    IBurnableDispatcherTrait, MusicStrk,
};
use contract_::erc20::MusicStrk::{TokenInitializedEvent, BurnEvent};
use openzeppelin::token::erc20::ERC20Component::{Event as ERC20Event, Transfer as ERC20Transfer};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, spy_events,
    EventSpyTrait, EventSpyAssertionsTrait,
};
use starknet::ContractAddress;
use core::array::ArrayTrait;

fn owner() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn zero() -> ContractAddress {
    0.try_into().unwrap()
}

fn kim() -> ContractAddress {
    'kim'.try_into().unwrap()
}

fn thurston() -> ContractAddress {
    'thurston'.try_into().unwrap()
}

fn lee() -> ContractAddress {
    'lee'.try_into().unwrap()
}

pub const TOTAL_SHARES: u256 = 100_u256;

// Helper function to deploy the music share token contract
fn deploy_music_share_token() -> ContractAddress {
    let owner = owner();
    let contract_class = declare("MusicStrk").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(owner);
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}


#[test]
fn test_initialization_emits_events() {
    // Setup
    let recipient = kim();
    let contract_address = deploy_music_share_token();
    let share_token = IMusicShareTokenDispatcher { contract_address };
    let metadata_uri: ByteArray = "ipfs://test";

    // Start spying on events before initialization
    let mut spy = spy_events();

    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    share_token.initialize(recipient, metadata_uri.clone(), "RecordToken", "REC", 2);

    // Get emitted events
    let events = spy.get_events();

    // Should emit TokenInitializedEvent and Transfer event
    assert(events.events.len() == 2, 'Should emit 2 events');

    // Expected ERC20Transfer event emitted by `initialize` function
    // This event is emitted by the `mint` function
    let expected_erc20_transfer_event = MusicStrk::Event::ERC20Event(
        ERC20Event::Transfer(
            ERC20Transfer {
                from: zero(), // Minting happens from the zero address
                to: recipient,
                value: TOTAL_SHARES,
            },
        ),
    );

    // Expected TokenInitializedEvent emitted by `initialize` function
    let expected_token_initialized_event = MusicStrk::Event::TokenInitializedEvent(
        TokenInitializedEvent {
            recipient,
            amount: TOTAL_SHARES,
            metadata_uri: metadata_uri.clone() // Use the cloned uri used in the emit call
        },
    );
    // Assert both events were emitted in MusicStrk contract
    // in order of occurrence of events in the transaction receipt
    spy
        .assert_emitted(
            @array![
                (
                    contract_address, expected_erc20_transfer_event,
                ), // ERC20 Transfer is emitted first
                (
                    contract_address, expected_token_initialized_event,
                ) // MusicStrk custom event is emitted after mint
            ],
        );
}

#[test]
fn test_burn_emits_events() {
    // Setup
    let recipient = kim();
    let contract_address = deploy_music_share_token();
    let share_token = IMusicShareTokenDispatcher { contract_address };
    let burnable = IBurnableDispatcher { contract_address };
    let metadata_uri: ByteArray = "ipfs://test";

    // Start spying on events before `initialize`
    // This is important to ensure we capture all events emitted during the test
    let mut spy = spy_events();
    let burn_amount: u256 = 20;

    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    share_token.initialize(recipient, metadata_uri.clone(), "RecordToken", "REC", 2);

    // Burn tokens (called by `mint` recipient)
    cheat_caller_address(contract_address, kim(), CheatSpan::TargetCalls(1));
    burnable.burn(burn_amount.clone());

    // Get emitted events
    let events = spy.get_events();

    // Verify total events (2 from init, 2 from burn)
    assert(events.events.len() == 4, 'Should emit 4 events');

    // Expected events in order of emission

    // 1. Initial Mint Transfer (from initialize)
    let expected_mint_transfer = MusicStrk::Event::ERC20Event(
        ERC20Event::Transfer(
            ERC20Transfer {
                from: zero(), // Mint comes from zero address
                to: recipient, value: TOTAL_SHARES,
            },
        ),
    );

    // 2. TokenInitializedEvent (from initialize)
    let expected_init_event = MusicStrk::Event::TokenInitializedEvent(
        TokenInitializedEvent {
            recipient, amount: TOTAL_SHARES, metadata_uri: metadata_uri.clone(),
        },
    );

    // 3. BurnEvent (from burn operation)
    let expected_burn_event = MusicStrk::Event::BurnEvent(
        BurnEvent { from: recipient, amount: burn_amount.clone() },
    );

    // 4. Burn Transfer (from burn operation)
    let expected_burn_transfer = MusicStrk::Event::ERC20Event(
        ERC20Event::Transfer(
            ERC20Transfer {
                from: recipient,
                to: zero(), // Burning sends to zero address
                value: burn_amount.clone(),
            },
        ),
    );

    // Assert all events were emitted in correct order
    spy
        .assert_emitted(
            @array![
                (contract_address, expected_mint_transfer),
                (contract_address, expected_init_event),
                (contract_address, expected_burn_event),
                (contract_address, expected_burn_transfer),
            ],
        );
}
// #[test]
// fn test_zero_amount_transfer_emits_event() {
//     // Setup
//     let sender = kim();
//     let recipient = thurston();
//     let contract_address = deploy_music_share_token();
//     let share_token = IMusicShareTokenDispatcher { contract_address };
//     let metadata_uri = "ipfs://test";

//     // Start spying on events before `initialize`
//     let mut spy = spy_events();

//     // Initialize the token
//     cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
//     share_token.initialize(sender, metadata_uri.clone(), "RecordToken", "REC", 2);

//     // Transfer zero tokens
//     cheat_caller_address(contract_address, sender, CheatSpan::TargetCalls(1));
//     share_token.transfer(recipient, 0_u256);

//     // Expected ERC20Transfer event should still be emitted
//     let expected_transfer_event = MusicStrk::Event::ERC20Event(
//         ERC20Event::Transfer(
//             ERC20Transfer {
//                 from: sender,
//                 to: recipient,
//                 value: 0_u256,
//             }
//         )
//     );

//     // Assert event was emitted
//     spy.assert_emitted(@array![
//         (contract_address, expected_transfer_event)
//     ]);
// }


