use contract_::audition::season_and_audition::SeasonAndAudition;
use contract_::audition::season_and_audition_interface::{
    ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait,
};
use contract_::audition::season_and_audition_types::RegistrationConfig;
use contract_::events::{ArtistRegistered, RegistrationConfigSet};
use core::num::traits::Zero;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, EventSpyAssertionsTrait, cheat_block_timestamp, cheat_caller_address, spy_events,
    test_address,
};
use starknet::ContractAddress;
use crate::test_utils::*;

const DEFAULT_TIMESTAMP: u64 = 1672531200;

pub fn feign_update_config(
    caller: ContractAddress, audition_id: u256, amount: u256,
) -> (ISeasonAndAuditionDispatcher, IERC20Dispatcher) {
    let audition = default_season();
    let token = deploy_mock_erc20_contract();
    cheat_caller_address(audition.contract_address, caller, CheatSpan::Indefinite);
    let new_config = build_config(amount, token.contract_address, true, 5);
    audition.update_registration_config(audition_id, new_config);
    (audition, token)
}

pub fn feign_artists_registration(
    artists_len: u32,
    erc20: IERC20Dispatcher,
    fee_amount: u256,
    audition: ISeasonAndAuditionDispatcher,
) -> Array<(ContractAddress, felt252)> {
    // Get all the artists using get_artists, and simulate a registration.
    let artists = get_artists(artists_len);
    let mut arr: Array<(ContractAddress, felt252)> = array![];
    for i in 0..artists.len() {
        let artist = *artists.at(i);
        cheat_caller_address(erc20.contract_address, OWNER(), CheatSpan::TargetCalls(1));
        erc20.transfer(artist, fee_amount);
        cheat_caller_address(erc20.contract_address, artist, CheatSpan::TargetCalls(1));
        erc20.approve(audition.contract_address, fee_amount);
        cheat_caller_address(audition.contract_address, artist, CheatSpan::Indefinite);
        let id: u256 = audition.register_performer(1, 'tiktok', 'tiktok', 'email').into();
        assert(id == i.into() + 1, 'INVALID ID');

        arr.append((artist, id.try_into().unwrap()));
    }
    arr
}

fn get_artists(len: u32) -> Array<ContractAddress> {
    let mut artists = array![];
    for i in 0..len {
        let artist: ContractAddress = Into::<u64, felt252>::into((i.into() + 1))
            .try_into()
            .unwrap();
        println!("Generated address: {:?}", artist);
        artists.append(artist);
    }
    artists
}

fn build_config(
    amount: u256, token: ContractAddress, open: bool, max_participants: u32,
) -> RegistrationConfig {
    RegistrationConfig {
        fee_amount: amount, fee_token: token, registration_open: open, max_participants,
    }
}

fn default_season() -> ISeasonAndAuditionDispatcher {
    let (audition, _, _) = deploy_contract();
    // Registration config must be none for a non existent audition
    let registration_config = audition.get_registration_config(1);
    assert(registration_config.is_none(), 'CONFIG SHOULD BE NONE');
    cheat_caller_address(audition.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    default_contract_create_season(audition);
    default_contract_create_audition(audition);
    audition
}

#[test]
fn test_audition_registration_config_update_flow() {
    let mut spy = spy_events();
    let audition = default_season();
    let season = audition.read_season(1);
    println!("Season id is: {}", season.season_id);
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

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_audition_registration_config_update_should_panic_on_non_owner() {
    let non_owner = test_address();
    feign_update_config(non_owner, 1, 10000);
}

#[test]
#[should_panic(expected: 'Audition does not exist')]
fn test_audition_registration_config_update_on_invalid_audition() {
    // simulate an update on a nonexistent id.
    feign_update_config(OWNER(), 2, 10000);
}

#[test]
#[should_panic(expected: 'Registration Started')]
fn test_audition_registration_config_update_on_registration_already_started() {
    let (audition, erc20) = feign_update_config(OWNER(), 1, 10000);
    feign_artists_registration(1, erc20, 10000, audition);
    cheat_caller_address(audition.contract_address, OWNER(), CheatSpan::Indefinite);
    audition.update_registration_config(1, Default::default());
}

#[test]
fn test_audition_registration_register_performer_success() { // update with a regular amount
    // extract all into a separate function
    let (audition, erc20) = feign_update_config(OWNER(), 1, 10000);
    let mut spy = spy_events();
    cheat_block_timestamp(audition.contract_address, 10, CheatSpan::Indefinite);
    let artists = feign_artists_registration(1, erc20, 100000, audition);
    // minted 100000, whereas registration is 10000
    // check the artist's balance
    let (artist, _) = *artists.at(0);
    let balance = erc20.balance_of(artist);
    assert_eq!(balance, 90000, "Balance at 0 is: {}", balance);

    let event = SeasonAndAudition::Event::ArtistRegistered(
        ArtistRegistered { artist_address: artist, audition_id: 1, registration_timestamp: 10 },
    );
    spy.assert_emitted(@array![(audition.contract_address, event)]);
}

#[test]
fn test_audition_registration_register_performer_success_on_zero_amount() { // update with zero amount
    // test registration
    let (audition, erc20) = feign_update_config(OWNER(), 1, 0);
    let mut spy = spy_events();
    cheat_block_timestamp(audition.contract_address, 10, CheatSpan::Indefinite);
    let artists = feign_artists_registration(1, erc20, 100, audition);
    let (artist, _) = *artists.at(0);
    let balance = erc20.balance_of(artist);
    assert_eq!(balance, 100, "BALANCE MISMATCH 2.");

    let event = SeasonAndAudition::Event::ArtistRegistered(
        ArtistRegistered { artist_address: artist, audition_id: 1, registration_timestamp: 10 },
    );
    spy.assert_emitted(@array![(audition.contract_address, event)]);
}

#[test]
#[should_panic(expected: 'Registration not open')]
fn test_audition_registration_register_performer_should_panic_on_config_not_set() {
    let audition = default_season();
    let artist = test_address();
    cheat_caller_address(audition.contract_address, artist, CheatSpan::Indefinite);
    audition.register_performer(1, 'tiktok', 'tiktok', 'email');
}

#[test]
#[should_panic(expected: 'Performer already registered')]
fn test_audition_registration_register_performer_should_panic_on_performer_already_registered() {
    let (audition, erc20) = feign_update_config(OWNER(), 1, 100);
    let artists = feign_artists_registration(1, erc20, 10000, audition);
    let (artist, _) = *artists.at(0);
    cheat_caller_address(audition.contract_address, artist, CheatSpan::Indefinite);
    audition.register_performer(1, 'tiktok', 'tiktok', 'email');
}

#[test]
#[should_panic(expected: 'Insufficient allowance')]
fn test_audition_registration_register_performer_should_panic_on_insufficient_funds() {
    let (audition, erc20) = feign_update_config(OWNER(), 1, 10000);
    // simulate artists registration with
    feign_artists_registration(1, erc20, 1000, audition);
}

#[test]
#[should_panic(expected: 'Max participants reached')]
fn test_audition_registration_register_performer_should_panic_on_max_participants_reached() {
    let (audition, erc20) = feign_update_config(OWNER(), 1, 1000);
    // default update config sets the max number of participants as 5
    // simulate registration with 6 performers
    feign_artists_registration(6, erc20, 1000, audition);
}
