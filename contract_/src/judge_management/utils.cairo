use starknet::{ContractAddress, get_block_timestamp};
use core::array::{Array, ArrayTrait};
use super::types::{WeightLimits, JudgeProfile, PaymentStatus};
use contract_::errors::errors;

// ============================================
// VALIDATION UTILITIES
// ============================================

pub fn validate_judge_address(judge_address: ContractAddress) {
    assert(!judge_address.is_zero(), errors::ZERO_ADDRESS_DETECTED);
}

pub fn validate_audition_id(audition_id: felt252) {
    assert(audition_id != 0, errors::AUDITION_DOES_NOT_EXIST);
}

pub fn validate_expertise_level(expertise_level: u8) {
    assert(expertise_level >= 1 && expertise_level <= 5, errors::EXPERTISE_LEVEL_INVALID);
}

pub fn validate_weight_against_limits(
    weight: u256, 
    is_celebrity: bool, 
    limits: WeightLimits
) {
    if is_celebrity {
        assert(weight <= limits.max_celebrity_weight, errors::CELEBRITY_WEIGHT_EXCEEDS_LIMIT);
    } else {
        assert(weight <= limits.max_regular_judge_weight, errors::JUDGE_WEIGHT_EXCEEDS_LIMIT);
    }
}

pub fn validate_total_weight_percentage(
    current_total_weight: u256,
    new_weight: u256,
    total_voting_power: u256,
    max_percentage: u8
) {
    let new_total = current_total_weight + new_weight;
    let percentage = (new_total * 100) / total_voting_power;
    assert(percentage <= max_percentage.into(), errors::TOTAL_JUDGE_WEIGHT_EXCEEDED);
}

pub fn validate_array_lengths_match<T, U>(arr1: @Array<T>, arr2: @Array<U>) {
    assert(arr1.len() == arr2.len(), errors::ARRAY_LENGTH_MISMATCH);
}

// ============================================
// WEIGHT CALCULATION UTILITIES
// ============================================

pub fn calculate_total_judge_weight(judge_weights: Array<u256>) -> u256 {
    let mut total = 0;
    let mut i = 0;
    loop {
        if i >= judge_weights.len() {
            break;
        }
        total += *judge_weights.at(i);
        i += 1;
    };
    total
}

pub fn calculate_weight_percentage(judge_weight: u256, total_weight: u256) -> u256 {
    if total_weight == 0 {
        return 0;
    }
    (judge_weight * 100) / total_weight
}

pub fn redistribute_weights_proportionally(
    current_weights: Array<u256>,
    target_total: u256
) -> Array<u256> {
    let current_total = calculate_total_judge_weight(current_weights.clone());
    if current_total == 0 {
        return current_weights;
    }
    
    let mut redistributed = ArrayTrait::new();
    let mut i = 0;
    loop {
        if i >= current_weights.len() {
            break;
        }
        let current_weight = *current_weights.at(i);
        let new_weight = (current_weight * target_total) / current_total;
        redistributed.append(new_weight);
        i += 1;
    };
    redistributed
}

// ============================================
// PAYMENT UTILITIES
// ============================================

pub fn calculate_judge_payment(
    base_amount: u256,
    is_celebrity: bool,
    celebrity_multiplier: u256 // e.g., 3 for 3x payment
) -> u256 {
    if is_celebrity {
        base_amount * celebrity_multiplier
    } else {
        base_amount
    }
}

pub fn is_payment_eligible(
    judge_participated: bool,
    audition_completed: bool,
    already_paid: bool
) -> bool {
    judge_participated && audition_completed && !already_paid
}

// ============================================
// TIMESTAMP UTILITIES
// ============================================

pub fn get_current_timestamp() -> u64 {
    get_block_timestamp()
}

pub fn is_evaluation_period_active(evaluation_deadline: u64) -> bool {
    get_current_timestamp() < evaluation_deadline
}

pub fn has_evaluation_deadline_passed(evaluation_deadline: u64) -> bool {
    get_current_timestamp() >= evaluation_deadline
}

// ============================================
// SCORE CALCULATION UTILITIES
// ============================================

pub fn calculate_total_score(scores: Array<u8>) -> u256 {
    let mut total = 0_u256;
    let mut i = 0;
    loop {
        if i >= scores.len() {
            break;
        }
        total += (*scores.at(i)).into();
        i += 1;
    };
    total
}

pub fn calculate_weighted_score(score: u256, weight: u256) -> u256 {
    score * weight
}

pub fn calculate_average_score(total_score: u256, num_criteria: u8) -> u256 {
    if num_criteria == 0 {
        return 0;
    }
    total_score / num_criteria.into()
}

// ============================================
// ARRAY UTILITIES
// ============================================

pub fn contains_address(addresses: @Array<ContractAddress>, target: ContractAddress) -> bool {
    let mut i = 0;
    loop {
        if i >= addresses.len() {
            break false;
        }
        if *addresses.at(i) == target {
            break true;
        }
        i += 1;
    }
}

pub fn remove_address_from_array(
    mut addresses: Array<ContractAddress>, 
    target: ContractAddress
) -> Array<ContractAddress> {
    let mut result = ArrayTrait::new();
    let mut i = 0;
    loop {
        if i >= addresses.len() {
            break;
        }
        let address = *addresses.at(i);
        if address != target {
            result.append(address);
        }
        i += 1;
    };
    result
}

pub fn filter_active_judges(
    judges: Array<ContractAddress>, 
    profiles: @Array<JudgeProfile>
) -> Array<ContractAddress> {
    let mut active_judges = ArrayTrait::new();
    let mut i = 0;
    loop {
        if i >= judges.len() {
            break;
        }
        let judge = *judges.at(i);
        let mut j = 0;
        loop {
            if j >= profiles.len() {
                break;
            }
            let profile = profiles.at(j);
            if profile.address == judge && profile.is_active {
                active_judges.append(judge);
                break;
            }
            j += 1;
        };
        i += 1;
    };
    active_judges
}

// ============================================
// VALIDATION CONSTANTS
// ============================================

pub const MIN_WEIGHT: u256 = 1;
pub const MAX_EXPERTISE_LEVEL: u8 = 5;
pub const MIN_EXPERTISE_LEVEL: u8 = 1;
pub const EVALUATION_CRITERIA_COUNT: u8 = 6;
pub const DEFAULT_CELEBRITY_PAYMENT_MULTIPLIER: u256 = 3;