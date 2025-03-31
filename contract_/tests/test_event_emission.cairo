use contract_::erc20::{
    IMusicShareTokenDispatcher, IMusicShareTokenDispatcherTrait, IBurnableDispatcher,
    IBurnableDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
    spy_events, EventSpy, Event, EventSpyTrait, EventSpyAssertionsTrait};
use starknet::{ContractAddress, contract_address_const};
use core::array::ArrayTrait;

fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn zero() -> ContractAddress {
    contract_address_const::<0>()
}

fn kim() -> ContractAddress {
    contract_address_const::<'kim'>()
}

fn thurston() -> ContractAddress {
    contract_address_const::<'thurston'>()
}

fn lee() -> ContractAddress {
    contract_address_const::<'lee'>()
}

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

    // Start spying on events before initialization
    let mut spy = spy_events();

    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    share_token.initialize(recipient, "ipfs://test", "RecordToken", "REC", 2);

    // Get emitted events
    let events = spy.get_events();

    // Should emit TokenInitializedEvent and Transfer event
    assert(events.events.len() == 2, 'Should emit 2 events');

    // Verify TokenInitializedEvent
    // let init_event = events.events.at(0);
    // assert(init_event.keys.len() == 1, 'TokenInitializedEvent should have one key');
    // assert(
    //     init_event.keys.at(0) == selector!("TokenInitializedEvent"),
    //     'First event should be TokenInitializedEvent'
    // );


    // Verify TokenInitializedEvent
    let (from, init_event) = events.events.at(0); // Get the event tuple
    assert!(ArrayTrait::len(init_event.keys) == 1, "TokenInitializedEvent should have one key");
    assert!(
        *ArrayTrait::at(init_event.keys, 0) == selector!("TokenInitializedEvent"),
        "First event should be TokenInitializedEvent"
    );

    // // Verify event data
    // let init_data = init_event.data;
    // assert(init_data.len() == 3, 'TokenInitializedEvent should have 3 data elements');
    // assert(init_data.at(0) == recipient.into(), 'Recipient address should match');
    // assert(init_data.at(1) == 100_u256.into(), 'Amount should be 100 tokens');
    // assert(init_data.at(2) == "ipfs://test".into(), 'Metadata URI should match');

    // // Verify Transfer event (from minting)
    // let transfer_event = events.events.at(1);
    // assert(transfer_event.keys.len() == 1, 'Transfer event should have one key');
    // // assert(
    // //     transfer_event.keys.at(0) == selector!("Transfer"),
    // //     'Second event should be Transfer'
    // // );

    // let transfer_data = transfer_event.data;
    // assert(transfer_data.len() == 3, 'Transfer event should have 3 data elements');
    // assert(transfer_data.at(0) == zero().into(), 'Should be from zero address');
    // assert(transfer_data.at(1) == recipient.into(), 'Should be to recipient address');
    // assert(transfer_data.at(2) == 100_u256.into(), 'Amount should be 100 tokens');
}
