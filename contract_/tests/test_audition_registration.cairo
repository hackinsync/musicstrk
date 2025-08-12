use contract_::audition::season_and_audition::SeasonAndAudition;
use contract_::audition::season_and_audition_interface::{
    ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait,
    ISeasonAndAuditionSafeDispatcher, ISeasonAndAuditionSafeDispatcherTrait,
};
use contract_::audition::season_and_audition_types::{
    ArtistRegistration, Audition, RegistrationConfig,
};
use contract_::events::RegistrationConfigSet;
use core::num::traits::Zero;
use openzeppelin::access::ownable::interface::IOwnableDispatcher;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, EventSpyAssertionsTrait, cheat_block_timestamp, cheat_caller_address, spy_events,
};
use starknet::ContractAddress;
use crate::test_utils::*;

const DEFAULT_TIMESTAMP: u64 = 1672531200;
fn feign_update_config() {}

// fn update_registration_config(
//     ref self: TContractState, audition_id: felt252, config: RegistrationConfig,
// );
// fn get_registration_config(
//     ref self: TContractState, audition_id: felt252,
// ) -> Option<RegistrationConfig>;

// fn register_performer(
//     ref self: TContractState,
//     audition_id: felt252,
//     tiktok_id: felt252,
//     tiktok_username: felt252,
//     email_hash: felt252,
// ) -> felt252;

fn default_season() -> ISeasonAndAuditionDispatcher {
    let (audition, _, _) = deploy_contract();
    // Registration config must be none for a non existent audition
    let registration_config = audition.get_registration_config(1);
    assert(registration_config.is_none(), 'CONFIG SHOULD BE NONE');
    cheat_caller_address(audition.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    default_contract_create_season(audition);
    audition
}

#[test]
fn test_audition_registration_config_update_flow() {
    let mut spy = spy_events();
    let audition = default_season();
    cheat_caller_address(audition.contract_address, OWNER(), CheatSpan::Indefinite);
    let registration_config = audition.get_registration_config(1);
    assert(registration_config.is_some(), 'CONFIG SHOULD BE SOME');
    let config = registration_config.unwrap();
    assert(config == Default::default(), 'WRONG CONFIG VALUES');

    // Test default values manually
    assert(config.fee_amount == 100_000_000, 'WRONG FEE AMOUNT');
    assert(
        config
            .fee_token == 0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
            .try_into()
            .unwrap(),
        'WRONG FEE TOKEN',
    );
    assert(!config.registration_open, 'REGISTRATION SHOULD BE OPEN');
    assert(config.max_participants == 25, 'WRONG MAX PARTICIPANTS');

    let token = deploy_mock_erc20_contract();
    let mut events = array![];

    let fee_amount = 10000;
    let fee_token = token.contract_address;
    let registration_open = true;
    let max_participants = 5;
    let new_config = build_config(fee_amount, fee_token, true, 5);
    audition.update_registration_config(1, new_config);

    let config_updated = SeasonAndAudition::Event::RegistrationConfigSet(
        RegistrationConfigSet {
            audition_id: 1, fee_amount, fee_token, registration_open, max_participants,
        },
    );

    let event1 = (audition.contract_address, config_updated);
    events.append(event1);

    let config_opt = audition.get_registration_config(1);
    assert(config_opt.is_some(), 'CONFIG SHOULD BE SOME 2.');
    let config = config_opt.unwrap();
    assert(config.fee_amount == fee_amount, 'FEE AMOUNT MISMATCH');
    assert(config.fee_token == fee_token, 'FEE TOKEN MISMATCH');
    assert(config.registration_open, 'REGISTRATION SHOULD BE OPEN 2.');
    assert(config.max_participants == max_participants, 'MAX PARTICIPANTS MISMATCH');

    // on zero address, uses the previous token address
    let new_config = build_config(500, Zero::zero(), false, 2);
    audition.update_registration_config(1, new_config);

    let config_updated = SeasonAndAudition::Event::RegistrationConfigSet(
        RegistrationConfigSet {
            audition_id: 1,
            fee_amount: 500,
            fee_token,
            registration_open: false,
            max_participants: 2,
        },
    );

    let event2 = (audition.contract_address, config_updated);
    events.append(event2);

    spy.assert_emitted(@events);
}

fn feign_artists_registration(amount: u32) -> () {// Get all the artists using get_artists, and simulate a registration.
}

fn get_artists(amount: u32) -> Array<ArtistRegistration> {
    array![]
}

fn build_config(
    amount: u256, token: ContractAddress, open: bool, max_participants: u32,
) -> RegistrationConfig {
    RegistrationConfig {
        fee_amount: amount, fee_token: token, registration_open: open, max_participants,
    }
}

#[test]
fn test_audition_registration_register_performer_success() {// update with a regular amount
// extract all into a separate function
}

#[test]
fn test_audition_registration_register_performer_success_on_zero_amount() {// update with zero amount
// test registration
}

#[test]
#[should_panic(expected: 'Caller not owner')]
fn test_audition_registration_config_update_should_panic_on_non_owner() {}

#[test]
#[should_panic(expected: 'Audition does not exist')]
fn test_audition_registration_config_update_on_invalid_audition() {}

#[test]
#[should_panic(expected: 'Registration Started')]
fn test_audition_registration_config_update_on_registration_already_started() {}

#[test]
#[should_panic(expected: 'Registration not open')]
fn test_audition_registration_register_performer_should_panic_on_config_not_set() {}

#[test]
#[should_panic(expected: 'Performer already registered')]
fn test_audition_registration_register_performer_should_panic_on_performer_already_registered() {}

#[test]
#[should_panic(expected: 'Insufficient balance')]
fn test_audition_registration_register_performer_should_panic_on_insufficient_funds() {}
