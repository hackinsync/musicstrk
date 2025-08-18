use starknet::ContractAddress;
#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Season {
    pub season_id: u256,
    pub name: felt252,
    pub start_timestamp: u64,
    pub end_timestamp: u64,
    pub last_updated_timestamp: u64,
    pub paused: bool,
    pub ended: bool,
}

#[derive(Drop, Serde, Default, starknet::Store, Copy)]
pub struct Audition {
    pub audition_id: u256,
    pub season_id: u256,
    pub name: felt252,
    pub genre: Genre,
    pub start_timestamp: u64,
    pub end_timestamp: u64,
    pub paused: bool,
}

#[derive(Drop, Serde, starknet::Store, Copy, Clone, PartialEq, Default)]
pub enum Genre {
    #[default]
    Generic,
    Pop,
    Rock,
    Jazz,
    Classical,
    HipHop,
    Electronic,
    Country,
    AfroHouse,
    RnB,
    Reggae,
    Other,
}


#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Vote {
    pub audition_id: u256,
    pub performer: felt252,
    pub voter: felt252,
    pub weight: felt252,
}

/// @notice Evaluation struct for storing performer evaluations
/// @param audition_id The ID of the audition being evaluated
/// @param performer The ID of the performer being evaluated
/// @param voter The ID of the voter submitting the evaluation
/// @param weight The weight of each evaluation (e.g. (40%, 30%, 30%))
/// @param criteria A tuple containing technical skills, creativity, and presentation scores
#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Evaluation {
    pub audition_id: u256,
    pub performer: felt252,
    pub criteria: (u256, u256, u256),
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Appeal {
    pub evaluation_id: u256,
    pub appellant: ContractAddress,
    pub reason: felt252,
    pub resolved: bool,
    pub resolution_comment: felt252,
}
