use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct StakingConfig {
    pub required_stake_amount: u256,
    pub stake_token: ContractAddress,
    pub withdrawal_delay_after_results: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct StakerInfo {
    pub address: ContractAddress,
    pub audition_id: felt252,
    pub staked_amount: u256,
    pub stake_timestamp: u64,
    pub is_eligible_voter: bool,
    pub has_voted: bool,
}

impl StakerInfoImpl of Default<StakerInfo> {
    fn default() -> StakerInfo {
        let felt_default: felt252 = Default::default();
        let u256_default: u256 = Default::default();
        let u64_default: u64 = Default::default();
        let bool_default: bool = Default::default();

        StakerInfo {
            address: 0x0.try_into().unwrap(),
            audition_id: felt_default,
            staked_amount: u256_default,
            stake_timestamp: u64_default,
            is_eligible_voter: bool_default,
            has_voted: bool_default,
        }
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
