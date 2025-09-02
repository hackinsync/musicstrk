use starknet::ContractAddress;
use core::array::Array;
use super::types::{
    JudgeProfile, WeightLimits, JudgePayment, JudgeStats, BatchJudgeAssignment, 
    BatchAssignmentResult, AuditionJudgeInfo, JudgePerformanceMetrics
};

#[starknet::interface]
pub trait IJudgeManagement<TContractState> {
    // ============================================
    // JUDGE ASSIGNMENT FUNCTIONS
    // ============================================
    
    fn assign_judge(
        ref self: TContractState,
        judge_address: ContractAddress,
        audition_id: felt252,
        weight: u256,
        is_celebrity: bool,
        payment_amount: u256,
        expertise_level: u8,
        specialty_genres: Array<felt252>,
    );
    
    fn assign_multiple_judges(
        ref self: TContractState,
        audition_id: felt252,
        judges: Array<BatchJudgeAssignment>,
    ) -> BatchAssignmentResult;

    // ============================================
    // JUDGE STATUS MANAGEMENT
    // ============================================
    
    fn activate_judge(
        ref self: TContractState, 
        judge_address: ContractAddress, 
        audition_id: felt252
    );
    
    fn deactivate_judge(
        ref self: TContractState, 
        judge_address: ContractAddress, 
        audition_id: felt252
    );

    // ============================================
    // WEIGHT MANAGEMENT
    // ============================================
    
    fn adjust_judge_weight(
        ref self: TContractState,
        judge_address: ContractAddress,
        audition_id: felt252,
        new_weight: u256,
    );
    
    fn set_weight_limits(ref self: TContractState, limits: WeightLimits);

    // ============================================
    // PAYMENT FUNCTIONS
    // ============================================
    
    fn pay_judge(
        ref self: TContractState,
        judge_address: ContractAddress,
        audition_id: felt252,
    );
    
    fn process_audition_judge_payments(ref self: TContractState, audition_id: felt252);

    // ============================================
    // EVALUATION FUNCTIONS
    // ============================================
    
    fn submit_judge_evaluation(
        ref self: TContractState,
        audition_id: felt252,
        artist_id: felt252,
        scores: Array<u8>, // [vocal_power, diction, confidence, timing, stage_presence, expression]
    );

    // ============================================
    // QUERY FUNCTIONS - Judge Information
    // ============================================
    
    fn get_judge_profile(
        self: @TContractState, 
        judge_address: ContractAddress
    ) -> JudgeProfile;
    
    fn get_audition_judges(
        self: @TContractState, 
        audition_id: felt252
    ) -> Array<ContractAddress>;
    
    fn get_active_judges(
        self: @TContractState, 
        audition_id: felt252
    ) -> Array<ContractAddress>;
    
    fn get_celebrity_judges(
        self: @TContractState, 
        audition_id: felt252
    ) -> Array<ContractAddress>;

    // ============================================
    // QUERY FUNCTIONS - Validation & Status
    // ============================================
    
    fn is_judge_assigned_to_audition(
        self: @TContractState,
        audition_id: felt252,
        judge_address: ContractAddress,
    ) -> bool;
    
    fn is_judge_eligible_for_payment(
        self: @TContractState,
        judge_address: ContractAddress,
        audition_id: felt252,
    ) -> bool;

    // ============================================
    // QUERY FUNCTIONS - Weight & Statistics
    // ============================================
    
    fn get_total_judge_weight(
        self: @TContractState, 
        audition_id: felt252
    ) -> u256;
    
    fn get_weight_limits(self: @TContractState) -> WeightLimits;
    
    fn get_judge_participation_stats(
        self: @TContractState, 
        judge_address: ContractAddress
    ) -> JudgeStats;
    
    fn get_audition_judge_info(
        self: @TContractState, 
        audition_id: felt252
    ) -> AuditionJudgeInfo;

    // ============================================
    // QUERY FUNCTIONS - Payment & History
    // ============================================
    
    fn get_payment_history(
        self: @TContractState, 
        judge_address: ContractAddress
    ) -> Array<JudgePayment>;
    
    fn get_judge_performance_metrics(
        self: @TContractState, 
        judge_address: ContractAddress
    ) -> JudgePerformanceMetrics;

    // ============================================
    // SYSTEM CONFIGURATION
    // ============================================
    
    fn set_audition_judge_requirements(
        ref self: TContractState,
        audition_id: felt252,
        required_count: u8,
        weight_percentage: u8,
        evaluation_deadline: u64,
    );
}