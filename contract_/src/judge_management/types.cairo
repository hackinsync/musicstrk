use starknet::ContractAddress;
use core::array::Array;

// ============================================
// CORE JUDGE TYPES
// ============================================

#[derive(Drop, Serde, starknet::Store)]
pub struct JudgeProfile {
    pub address: ContractAddress,
    pub weight: u256,
    pub is_celebrity: bool,
    pub expertise_level: u8,         // 1-5 scale
    pub assigned_timestamp: u64,
    pub is_active: bool,
    pub payment_amount: u256,        // Fixed payment per audition
    pub specialty_genres: Array<felt252>,
    pub total_evaluations: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct WeightLimits {
    pub max_regular_judge_weight: u256,    // e.g., 50
    pub max_celebrity_weight: u256,        // e.g., 200
    pub max_total_judge_percentage: u8,    // e.g., 80% of total voting power
    pub min_judges_per_audition: u8,       // e.g., 3
    pub max_judges_per_audition: u8,       // e.g., 10
}

#[derive(Drop, Serde, starknet::Store)]
pub struct JudgePayment {
    pub judge_address: ContractAddress,
    pub audition_id: felt252,
    pub season_id: felt252,
    pub amount_paid: u256,
    pub payment_timestamp: u64,
    pub payment_status: PaymentStatus,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct JudgeStats {
    pub total_auditions_judged: u256,
    pub total_payments_received: u256,
    pub average_score_given: u256,
    pub reputation_score: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct AuditionJudgeRequirements {
    pub audition_id: felt252,
    pub required_count: u8,
    pub weight_percentage: u8,
    pub assigned_count: u8,
    pub evaluation_deadline: u64,
    pub total_weight_assigned: u256,
}

// ============================================
// EVALUATION TYPES
// ============================================

#[derive(Drop, Serde, starknet::Store)]
pub struct JudgeEvaluation {
    pub audition_id: felt252,
    pub judge_address: ContractAddress,
    pub artist_id: felt252,
    pub scores: Array<u8>, // [vocal_power, diction, confidence, timing, stage_presence, expression]
    pub evaluation_timestamp: u64,
    pub weight: u256,
    pub total_score: u256,
}

// ============================================
// ENUMS FOR TYPE SAFETY
// ============================================

#[derive(Drop, Serde, starknet::Store, PartialEq)]
pub enum JudgeType {
    Regular,
    Celebrity,
}

#[derive(Drop, Serde, starknet::Store, PartialEq)]
pub enum PaymentStatus {
    Pending,
    Paid,
    Failed,
}

#[derive(Drop, Serde, starknet::Store, PartialEq)]
pub enum JudgeStatus {
    Inactive,
    Active,
    Suspended,
}

// ============================================
// BATCH OPERATION TYPES
// ============================================

#[derive(Drop, Serde)]
pub struct BatchJudgeAssignment {
    pub judge_address: ContractAddress,
    pub weight: u256,
    pub is_celebrity: bool,
    pub payment_amount: u256,
    pub specialty_genres: Array<felt252>,
    pub expertise_level: u8,
}

#[derive(Drop, Serde)]
pub struct BatchAssignmentResult {
    pub successful_assignments: u8,
    pub failed_assignments: u8,
    pub total_weight_assigned: u256,
}

// ============================================
// QUERY RESULT TYPES
// ============================================

#[derive(Drop, Serde)]
pub struct AuditionJudgeInfo {
    pub audition_id: felt252,
    pub assigned_judges: Array<ContractAddress>,
    pub total_weight: u256,
    pub evaluation_deadline: u64,
    pub requirements_met: bool,
}

#[derive(Drop, Serde)]
pub struct JudgePerformanceMetrics {
    pub judge_address: ContractAddress,
    pub total_auditions: u256,
    pub average_evaluation_time: u64,
    pub consistency_score: u256,
    pub reputation_score: u256,
}

// ============================================
// PHASE 4: WEIGHT MANAGEMENT TYPES
// ============================================

#[derive(Drop, Serde, starknet::Store)]
pub struct WeightAdjustment {
    pub audition_id: felt252,
    pub judge_address: ContractAddress,
    pub old_weight: u256,
    pub new_weight: u256,
    pub adjustment_reason: felt252,
    pub adjusted_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, Serde)]
pub struct WeightDistribution {
    pub audition_id: felt252,
    pub judge_weights: Array<(ContractAddress, u256)>, // (judge_address, weight)
    pub total_judge_weight: u256,
    pub celebrity_judge_weight: u256,
    pub regular_judge_weight: u256,
    pub weight_concentration: u256, // Highest individual judge percentage
}

#[derive(Drop, Serde)]
pub struct WeightRedistributionResult {
    pub successful_adjustments: u8,
    pub failed_adjustments: u8,
    pub total_weight_before: u256,
    pub total_weight_after: u256,
    pub redistribution_applied: bool,
}

// ============================================
// PHASE 5: PAYMENT INTEGRATION TYPES
// ============================================

#[derive(Drop, Serde, starknet::Store)]
pub struct PaymentConfiguration {
    pub regular_judge_rate: u256,      // Percentage of pool per audition (e.g., 50 = 0.5%)
    pub celebrity_judge_rate: u256,    // Percentage of pool per audition (e.g., 200 = 2%)
    pub minimum_pool_balance: u256,    // Minimum pool balance required
    pub payment_delay: u64,           // Delay after audition completion (seconds)
}

#[derive(Drop, Serde)]
pub struct PaymentCalculation {
    pub judge_address: ContractAddress,
    pub audition_id: felt252,
    pub base_amount: u256,
    pub celebrity_bonus: u256,
    pub total_amount: u256,
    pub pool_percentage: u256,
}

#[derive(Drop, Serde)]
pub struct BatchPaymentResult {
    pub successful_payments: u8,
    pub failed_payments: u8,
    pub total_amount_paid: u256,
    pub remaining_pool_balance: u256,
}

#[derive(Drop, Serde)]
pub struct JudgePaymentInfo {
    pub judge_address: ContractAddress,
    pub is_eligible: bool,
    pub payment_amount: u256,
    pub payment_status: PaymentStatus,
    pub participation_verified: bool,
    pub audition_completed: bool,
}

// ============================================
// PHASE 7: ADVANCED QUERY TYPES
// ============================================

#[derive(Drop, Serde)]
pub struct JudgesByCategory {
    pub active_judges: Array<ContractAddress>,
    pub inactive_judges: Array<ContractAddress>,
    pub celebrity_judges: Array<ContractAddress>,
    pub regular_judges: Array<ContractAddress>,
    pub total_count: u32,
}

#[derive(Drop, Serde)]
pub struct AuditionStatistics {
    pub audition_id: felt252,
    pub total_judges: u32,
    pub active_judges: u32,
    pub celebrity_count: u32,
    pub regular_count: u32,
    pub total_weight: u256,
    pub average_weight: u256,
    pub completion_status: bool,
    pub requirements_met: bool,
}

#[derive(Drop, Serde)]
pub struct JudgeAuditionParticipation {
    pub judge_address: ContractAddress,
    pub audition_participations: Array<felt252>, // audition_ids
    pub total_auditions: u32,
    pub payment_received_count: u32,
    pub current_active_auditions: u32,
}

#[derive(Drop, Serde)]
pub struct SystemOverview {
    pub total_judges_registered: u32,
    pub total_auditions_with_judges: u32,
    pub total_payments_processed: u256,
    pub emergency_stopped: bool,
    pub weight_limits: WeightLimits,
    pub average_judges_per_audition: u32,
}