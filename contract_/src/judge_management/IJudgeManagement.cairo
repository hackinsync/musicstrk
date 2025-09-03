use starknet::ContractAddress;
use core::array::Array;
use super::types::{
    JudgeProfile, WeightLimits, JudgePayment, JudgeStats, BatchJudgeAssignment, 
    BatchAssignmentResult, AuditionJudgeInfo, JudgePerformanceMetrics, WeightAdjustment,
    WeightRedistributionResult, WeightDistribution, PaymentConfiguration, PaymentCalculation,
    BatchPaymentResult, JudgePaymentInfo, JudgesByCategory, AuditionStatistics, 
    JudgeAuditionParticipation, SystemOverview
};

// ============================================
// MAIN JUDGE MANAGEMENT INTERFACE
// ============================================

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

// ============================================
// PHASE 2: ACCESS CONTROL INTERFACE
// ============================================

#[starknet::interface]
pub trait IAccessControl<TContractState> {
    // Emergency stop functions
    fn emergency_stop(ref self: TContractState, reason: felt252);
    fn emergency_resume(ref self: TContractState);
    
    // Operator management
    fn authorize_operator(ref self: TContractState, operator: ContractAddress);
    fn revoke_operator(ref self: TContractState, operator: ContractAddress);
    
    // System configuration
    fn set_season_audition_contract(ref self: TContractState, contract_address: ContractAddress);
    
    // Query functions
    fn is_emergency_stopped(self: @TContractState) -> bool;
    fn is_authorized_operator(self: @TContractState, operator: ContractAddress) -> bool;
    fn get_season_audition_contract(self: @TContractState) -> ContractAddress;
}

// ============================================
// PHASE 4: WEIGHT MANAGEMENT INTERFACE
// ============================================

#[starknet::interface]
pub trait IWeightManagement<TContractState> {
    // Weight redistribution functions
    fn redistribute_weights_proportionally(
        ref self: TContractState,
        audition_id: felt252,
        target_total_weight: u256,
    ) -> WeightRedistributionResult;
    
    // Voting status management
    fn set_voting_status(
        ref self: TContractState,
        audition_id: felt252,
        voting_started: bool,
    );
    
    // Weight analysis functions
    fn analyze_weight_distribution(
        self: @TContractState,
        audition_id: felt252,
    ) -> WeightDistribution;
    
    fn get_weight_adjustment_history(
        self: @TContractState,
        audition_id: felt252,
        judge_address: ContractAddress,
    ) -> Array<WeightAdjustment>;
    
    // Query functions
    fn is_voting_started(self: @TContractState, audition_id: felt252) -> bool;
    fn get_weight_concentration(self: @TContractState, audition_id: felt252) -> u256;
    fn can_adjust_weights(self: @TContractState, audition_id: felt252) -> bool;
}

// ============================================
// PHASE 5: PAYMENT MANAGEMENT INTERFACE
// ============================================

#[starknet::interface]
pub trait IPaymentManagement<TContractState> {
    // Payment configuration functions
    fn set_payment_configuration(
        ref self: TContractState,
        config: PaymentConfiguration,
    );
    
    fn set_payment_pool(
        ref self: TContractState,
        pool_address: ContractAddress,
    );
    
    // Audition completion management
    fn complete_audition(
        ref self: TContractState,
        audition_id: felt252,
    );
    
    fn set_payment_eligibility(
        ref self: TContractState,
        audition_id: felt252,
        judge_address: ContractAddress,
        is_eligible: bool,
        reason: felt252,
    );
    
    // Payment calculation and processing
    fn calculate_judge_payment(
        self: @TContractState,
        judge_address: ContractAddress,
        audition_id: felt252,
    ) -> PaymentCalculation;
    
    fn get_judge_payment_info(
        self: @TContractState,
        judge_address: ContractAddress,
        audition_id: felt252,
    ) -> JudgePaymentInfo;
    
    // Query functions
    fn get_payment_configuration(self: @TContractState) -> PaymentConfiguration;
    fn get_payment_pool(self: @TContractState) -> ContractAddress;
    fn is_audition_completed(self: @TContractState, audition_id: felt252) -> bool;
    fn get_audition_completion_time(self: @TContractState, audition_id: felt252) -> u64;
}

// ============================================
// PHASE 7: ADVANCED QUERY INTERFACE
// ============================================

#[starknet::interface]
pub trait IAdvancedQuery<TContractState> {
    // Judge categorization queries
    fn get_judges_by_category(
        self: @TContractState,
        audition_id: felt252,
    ) -> JudgesByCategory;
    
    fn get_judges_by_season(
        self: @TContractState,
        season_id: felt252,
    ) -> Array<ContractAddress>;
    
    // Audition statistics
    fn get_audition_statistics(
        self: @TContractState,
        audition_id: felt252,
    ) -> AuditionStatistics;
    
    fn get_judge_audition_participation(
        self: @TContractState,
        judge_address: ContractAddress,
    ) -> JudgeAuditionParticipation;
    
    // System overview
    fn get_system_overview(self: @TContractState) -> SystemOverview;
    
    // Advanced filtering functions
    fn get_judges_by_expertise_level(
        self: @TContractState,
        audition_id: felt252,
        min_expertise: u8,
        max_expertise: u8,
    ) -> Array<ContractAddress>;
    
    fn get_top_performing_judges(
        self: @TContractState,
        limit: u32,
    ) -> Array<(ContractAddress, u256)>; // (address, reputation_score)
    
    fn get_auditions_requiring_judges(
        self: @TContractState,
    ) -> Array<felt252>; // audition_ids that haven't met minimum requirements
}