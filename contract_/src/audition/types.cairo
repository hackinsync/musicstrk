use core::num::traits::Zero;
use starknet::ContractAddress;

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct StakingConfig {
    pub required_stake_amount: u256,
    pub stake_token: ContractAddress,
    pub withdrawal_delay_after_results: u64,
}

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct StakerInfo {
    pub address: ContractAddress,
    pub audition_id: felt252,
    pub staked_amount: u256,
    pub stake_timestamp: u64,
    pub is_eligible_voter: bool,
    pub has_voted: bool,
}

impl ContractAddressDefault of Default<ContractAddress> {
    fn default() -> ContractAddress {
        Zero::zero()
    }
}

#[derive(Drop, starknet::Event)]
pub struct StakingConfigSet {
    pub audition_id: felt252,
    pub required_stake_amount: u256,
    pub stake_token: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct StakePlaced {
    pub audition_id: felt252,
    pub staker: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct StakeWithdrawn {
    pub audition_id: felt252,
    pub staker: ContractAddress,
    pub amount: u256,
}
