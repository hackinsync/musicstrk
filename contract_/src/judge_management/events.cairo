use starknet::ContractAddress;
use core::byte_array::ByteArray;
use super::types::{PaymentStatus, JudgeType};

// ============================================
// JUDGE ASSIGNMENT EVENTS
// ============================================

#[derive(Drop, starknet::Event)]
pub struct JudgeAssigned {
    #[key]
    pub judge_address: ContractAddress,
    #[key]
    pub audition_id: felt252,
    pub weight: u256,
    pub is_celebrity: bool,
    pub assigned_by: ContractAddress,
    pub timestamp: u64,
    pub payment_amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct BatchJudgeAssignment {
    #[key]
    pub audition_id: felt252,
    pub judges_assigned: u8,
    pub total_weight: u256,
    pub assigned_by: ContractAddress,
    pub timestamp: u64,
}

// ============================================
// JUDGE STATUS EVENTS
// ============================================

#[derive(Drop, starknet::Event)]
pub struct JudgeStatusChanged {
    #[key]
    pub judge_address: ContractAddress,
    #[key]
    pub audition_id: felt252,
    pub old_status: bool,
    pub new_status: bool,
    pub changed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct JudgeActivated {
    #[key]
    pub judge_address: ContractAddress,
    #[key]
    pub audition_id: felt252,
    pub activated_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct JudgeDeactivated {
    #[key]
    pub judge_address: ContractAddress,
    #[key]
    pub audition_id: felt252,
    pub deactivated_by: ContractAddress,
    pub timestamp: u64,
}

// ============================================
// WEIGHT MANAGEMENT EVENTS
// ============================================

#[derive(Drop, starknet::Event)]
pub struct JudgeWeightUpdated {
    #[key]
    pub judge_address: ContractAddress,
    #[key]
    pub audition_id: felt252,
    pub old_weight: u256,
    pub new_weight: u256,
    pub updated_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct WeightLimitsUpdated {
    pub max_regular_weight: u256,
    pub max_celebrity_weight: u256,
    pub max_total_percentage: u8,
    pub min_judges_per_audition: u8,
    pub max_judges_per_audition: u8,
    pub updated_by: ContractAddress,
    pub timestamp: u64,
}

// ============================================
// PAYMENT EVENTS
// ============================================

#[derive(Drop, starknet::Event)]
pub struct JudgePaymentProcessed {
    #[key]
    pub judge_address: ContractAddress,
    #[key]
    pub audition_id: felt252,
    pub amount: u256,
    pub payment_status: PaymentStatus,
    pub processed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct BatchJudgePayment {
    #[key]
    pub audition_id: felt252,
    pub judges_paid: u8,
    pub total_amount: u256,
    pub processed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct JudgePaymentFailed {
    #[key]
    pub judge_address: ContractAddress,
    #[key]
    pub audition_id: felt252,
    pub amount: u256,
    pub reason: felt252,
    pub timestamp: u64,
}

// ============================================
// EVALUATION EVENTS
// ============================================

#[derive(Drop, starknet::Event)]
pub struct JudgeEvaluationSubmitted {
    #[key]
    pub judge_address: ContractAddress,
    #[key]
    pub audition_id: felt252,
    #[key]
    pub artist_id: felt252,
    pub total_score: u256,
    pub weight: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct EvaluationWeightCalculated {
    #[key]
    pub audition_id: felt252,
    pub total_judge_evaluations: u256,
    pub total_weight: u256,
    pub timestamp: u64,
}

// ============================================
// SYSTEM EVENTS
// ============================================

#[derive(Drop, starknet::Event)]
pub struct JudgeManagementInitialized {
    pub owner: ContractAddress,
    pub initial_weight_limits: (u256, u256, u8), // (regular_max, celebrity_max, total_percentage)
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AuditionJudgeRequirementsSet {
    #[key]
    pub audition_id: felt252,
    pub required_count: u8,
    pub weight_percentage: u8,
    pub evaluation_deadline: u64,
    pub set_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct JudgeProfileUpdated {
    #[key]
    pub judge_address: ContractAddress,
    pub expertise_level: u8,
    pub specialty_genres_count: u8,
    pub updated_by: ContractAddress,
    pub timestamp: u64,
}

// ============================================
// PHASE 2: ACCESS CONTROL EVENTS
// ============================================

#[derive(Drop, starknet::Event)]
pub struct EmergencyStopped {
    pub stopped_by: ContractAddress,
    pub reason: felt252,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct EmergencyResumed {
    pub resumed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct OperatorAuthorized {
    #[key]
    pub operator: ContractAddress,
    pub authorized_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct OperatorRevoked {
    #[key]
    pub operator: ContractAddress,
    pub revoked_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SeasonAuditionContractSet {
    pub old_contract: ContractAddress,
    pub new_contract: ContractAddress,
    pub set_by: ContractAddress,
    pub timestamp: u64,
}