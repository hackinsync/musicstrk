use contract_::audition::interfaces::iseason_and_audition::{
    ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait,
    ISeasonAndAuditionSafeDispatcher,
};
use contract_::audition::interfaces::istake_to_vote::{
    IStakeToVoteDispatcher, IStakeToVoteDispatcherTrait,
};
use contract_::audition::types::season_and_audition::{
    Appeal, Audition, Evaluation, Genre, Season, Vote,
};
use core::array::ArrayTrait;
use openzeppelin::access::ownable::interface::IOwnableDispatcher;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

// Test account -> Owner
pub fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

// Test account -> User
pub fn USER() -> ContractAddress {
    'USER'.try_into().unwrap()
}

pub fn NON_OWNER() -> ContractAddress {
    'NON_OWNER'.try_into().unwrap()
}

pub fn ORACLE() -> ContractAddress {
    'ORACLE'.try_into().unwrap()
}

pub fn NON_ORACLE() -> ContractAddress {
    'NON_ORACLE'.try_into().unwrap()
}


pub fn zero() -> ContractAddress {
    0.try_into().unwrap()
}

pub fn kim() -> ContractAddress {
    'kim'.try_into().unwrap()
}

pub fn thurston() -> ContractAddress {
    'thurston'.try_into().unwrap()
}

pub fn lee() -> ContractAddress {
    'lee'.try_into().unwrap()
}

pub fn VOTER1() -> ContractAddress {
    'VOTER1'.try_into().unwrap()
}

pub fn VOTER2() -> ContractAddress {
    'VOTER2'.try_into().unwrap()
}

// Helper function to deploy staking contract
pub fn deploy_staking_contract() -> IStakeToVoteDispatcher {
    // Deploy staking contract
    let staking_class = declare("StakeToVote")
        .expect('Failed to declare StakeToVote')
        .contract_class();

    let mut staking_calldata: Array<felt252> = array![];
    OWNER().serialize(ref staking_calldata);
    zero().serialize(ref staking_calldata); // temporary audition address, will be updated

    let (staking_address, _) = staking_class
        .deploy(@staking_calldata)
        .expect('Failed to deploy StakeToVote');

    IStakeToVoteDispatcher { contract_address: staking_address }
}

// Helper function to deploy the contract
pub fn deploy_contract() -> (
    ISeasonAndAuditionDispatcher, IOwnableDispatcher, ISeasonAndAuditionSafeDispatcher,
) {
    // Deploy real staking contract first
    let staking_dispatcher = deploy_staking_contract();

    // declare the audition contract
    let contract_class = declare("SeasonAndAudition")
        .expect('Failed to declare SAudition')
        .contract_class();

    // serialize constructor
    let mut calldata: Array<felt252> = array![];

    OWNER().serialize(ref calldata);
    staking_dispatcher.contract_address.serialize(ref calldata);

    // deploy the contract
    let (contract_address, _) = contract_class
        .deploy(@calldata)
        .expect('Failed to deploy contract');

    let contract = ISeasonAndAuditionDispatcher { contract_address };
    let ownable = IOwnableDispatcher { contract_address };
    let safe_dispatcher = ISeasonAndAuditionSafeDispatcher { contract_address };

    (contract, ownable, safe_dispatcher)
}

// Helper function to deploy both contracts and return both
pub fn deploy_contracts_with_staking() -> (
    ISeasonAndAuditionDispatcher, IStakeToVoteDispatcher, IOwnableDispatcher,
) {
    // Deploy real staking contract first
    let staking_dispatcher = deploy_staking_contract();

    // declare the audition contract
    let contract_class = declare("SeasonAndAudition")
        .expect('Failed to declare SAudition')
        .contract_class();

    // serialize constructor
    let mut calldata: Array<felt252> = array![];

    OWNER().serialize(ref calldata);
    staking_dispatcher.contract_address.serialize(ref calldata);

    // deploy the contract
    let (contract_address, _) = contract_class
        .deploy(@calldata)
        .expect('Failed to deploy contract');

    let contract = ISeasonAndAuditionDispatcher { contract_address };
    let ownable = IOwnableDispatcher { contract_address };

    (contract, staking_dispatcher, ownable)
}

// Helper function to create a default Season struct
pub fn create_default_season(season_id: u256) -> Season {
    Season {
        season_id,
        name: 'Summer Hits',
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        last_updated_timestamp: 1672531200,
        paused: false,
        ended: false,
    }
}

pub fn default_contract_create_season(contract: ISeasonAndAuditionDispatcher) {
    let name: felt252 = 'Summer Hits';
    let start_time: u64 = 1672531200;
    let end_time: u64 = 1675123200;
    contract.create_season(name, start_time, end_time);
}

pub fn deploy_mock_erc20_contract() -> IERC20Dispatcher {
    let erc20_class = declare("mock_erc20").unwrap().contract_class();
    let mut calldata = array![OWNER().into(), OWNER().into(), 6];
    let (erc20_address, _) = erc20_class.deploy(@calldata).unwrap();

    IERC20Dispatcher { contract_address: erc20_address }
}

pub fn deploy_music_share_token() -> ContractAddress {
    let owner = OWNER();
    let contract_class = declare("MusicStrk").unwrap().contract_class();
    let mut calldata = array![];
    owner.serialize(ref calldata);
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}
// Helper function to create a default Audition struct
pub fn create_default_audition(audition_id: u256, season_id: u256) -> Audition {
    Audition {
        audition_id,
        season_id,
        name: 'Live Audition',
        genre: Genre::Pop,
        start_timestamp: 1672531200,
        end_timestamp: 1675123200,
        paused: false,
    }
}

pub fn default_contract_create_audition(contract: ISeasonAndAuditionDispatcher) {
    let name: felt252 = 'Live Audition';
    let genre: Genre = Genre::Pop;
    let end_time: u64 = 1675123200;
    contract.create_audition(name, genre, end_time);
}
