use core::num::traits::Zero;
use starknet::ContractAddress;

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Season {
    pub season_id: u256,
    pub genre: Genre,
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
// converter not needed
// pub fn get_genre_from_number(number: u8) -> Genre {
//     match number {
//         0 => Genre::Generic,
//         1 => Genre::Pop,
//         2 => Genre::Rock,
//         3 => Genre::Jazz,
//         4 => Genre::Classical,
//         5 => Genre::HipHop,
//         6 => Genre::Electronic,
//         7 => Genre::Country,
//         8 => Genre::AfroHouse,
//         9 => Genre::RnB,
//         10 => Genre::Reggae,
//         11 => Genre::Other,
//         _ => Genre::Generic,
//     }
// }

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Vote {
    pub audition_id: u256,
    pub performer: ContractAddress,
    pub voter: ContractAddress,
    pub weight: felt252,
}

/// @notice Evaluation struct for storing performer evaluations
/// @param audition_id The ID of the audition being evaluated
/// @param performer The address of the performer being evaluated
/// @param voter The address of the voter submitting the evaluation
/// @param weight The weight of each evaluation (e.g. (40%, 30%, 30%))
/// @param criteria A tuple containing technical skills, creativity, and presentation scores
#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Evaluation {
    pub audition_id: u256,
    pub performer: ContractAddress,
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

// Implement default for contract address type
impl DefaultImpl of Default<ContractAddress> {
    fn default() -> ContractAddress {
        Zero::zero()
    }
}
