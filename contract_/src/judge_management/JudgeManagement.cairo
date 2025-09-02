#[starknet::contract]
pub mod JudgeManagement {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use core::array::{Array, ArrayTrait};
    use core::option::OptionTrait;
    use core::traits::Into;
    
    // Import existing system components
    use super::errors::errors;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    
    // Import judge management types and interfaces
    use super::types::{
        JudgeProfile, WeightLimits, JudgePayment, JudgeStats, AuditionJudgeRequirements,
        JudgeEvaluation, PaymentStatus, JudgeType, JudgeStatus, BatchJudgeAssignment,
        BatchAssignmentResult, AuditionJudgeInfo, JudgePerformanceMetrics
    };
    use super::events::{
        JudgeAssigned, BatchJudgeAssignment as BatchJudgeAssignmentEvent, JudgeStatusChanged,
        JudgeActivated, JudgeDeactivated, JudgeWeightUpdated, WeightLimitsUpdated,
        JudgePaymentProcessed, BatchJudgePayment, JudgePaymentFailed, JudgeEvaluationSubmitted,
        EvaluationWeightCalculated, JudgeManagementInitialized, AuditionJudgeRequirementsSet,
        JudgeProfileUpdated
    };
    use super::utils;
    use super::IJudgeManagement::IJudgeManagement;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ReentrancyGuardImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    // ============================================
    // STORAGE DEFINITION - Phase 1.2 Storage Setup
    // ============================================

    #[storage]
    struct Storage {
        // Component storage
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        
        // Judge profiles mapping: ContractAddress -> JudgeProfile
        judge_profiles: LegacyMap<ContractAddress, JudgeProfile>,
        
        // Season judge assignments: (season_id, judge_address) -> bool
        season_judge_assignments: LegacyMap<(felt252, ContractAddress), bool>,
        
        // Audition judge participation: (audition_id, judge_address) -> bool
        audition_judge_assignments: LegacyMap<(felt252, ContractAddress), bool>,
        
        // Audition judge requirements: audition_id -> AuditionJudgeRequirements
        audition_requirements: LegacyMap<felt252, AuditionJudgeRequirements>,
        
        // Judge evaluations: (audition_id, judge_address, artist_id) -> JudgeEvaluation
        judge_evaluations: LegacyMap<(felt252, ContractAddress, felt252), JudgeEvaluation>,
        
        // Judge payment history: (judge_address, audition_id) -> JudgePayment
        judge_payments: LegacyMap<(ContractAddress, felt252), JudgePayment>,
        
        // Judge statistics: judge_address -> JudgeStats
        judge_stats: LegacyMap<ContractAddress, JudgeStats>,
        
        // Weight limits configuration
        weight_limits: WeightLimits,
        
        // Total weight tracking per audition: audition_id -> u256
        audition_total_weight: LegacyMap<felt252, u256>,
        
        // Audition assigned judges list: audition_id -> Array<ContractAddress>
        audition_judges_list: LegacyMap<felt252, Array<ContractAddress>>,
        
        // Judge assignment tracking: (audition_id, index) -> ContractAddress
        audition_judges_by_index: LegacyMap<(felt252, u32), ContractAddress>,
        
        // Audition judge count: audition_id -> u32
        audition_judge_count: LegacyMap<felt252, u32>,
        
        // Payment pool integration (for future phases)
        payment_pool_contract: ContractAddress,
        
        // System initialization flag
        is_initialized: bool,
    }

    // ============================================
    // EVENTS DEFINITION - Phase 1.3 Events Definition
    // ============================================

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        
        // Judge Assignment Events
        JudgeAssigned: JudgeAssigned,
        BatchJudgeAssignment: BatchJudgeAssignmentEvent,
        
        // Judge Status Events
        JudgeStatusChanged: JudgeStatusChanged,
        JudgeActivated: JudgeActivated,
        JudgeDeactivated: JudgeDeactivated,
        
        // Weight Management Events
        JudgeWeightUpdated: JudgeWeightUpdated,
        WeightLimitsUpdated: WeightLimitsUpdated,
        
        // Payment Events
        JudgePaymentProcessed: JudgePaymentProcessed,
        BatchJudgePayment: BatchJudgePayment,
        JudgePaymentFailed: JudgePaymentFailed,
        
        // Evaluation Events
        JudgeEvaluationSubmitted: JudgeEvaluationSubmitted,
        EvaluationWeightCalculated: EvaluationWeightCalculated,
        
        // System Events
        JudgeManagementInitialized: JudgeManagementInitialized,
        AuditionJudgeRequirementsSet: AuditionJudgeRequirementsSet,
        JudgeProfileUpdated: JudgeProfileUpdated,
    }

    // ============================================
    // CONSTRUCTOR - Initialize with default weight limits
    // ============================================

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        initial_weight_limits: WeightLimits,
    ) {
        // Initialize ownership
        self.ownable.initializer(owner);
        
        // Set initial weight limits
        self.weight_limits.write(initial_weight_limits);
        
        // Mark as initialized
        self.is_initialized.write(true);
        
        // Emit initialization event
        self.emit(JudgeManagementInitialized {
            owner,
            initial_weight_limits: (
                initial_weight_limits.max_regular_judge_weight,
                initial_weight_limits.max_celebrity_weight,
                initial_weight_limits.max_total_judge_percentage
            ),
            timestamp: get_block_timestamp(),
        });
    }

    // ============================================
    // INTERFACE IMPLEMENTATION - Basic structure for Phase 1
    // ============================================

    #[abi(embed_v0)]
    impl IJudgeManagementImpl of IJudgeManagement<ContractState> {
        
        // ============================================
        // JUDGE ASSIGNMENT FUNCTIONS - Phase 3 Implementation (Stub for Phase 1)
        // ============================================
        
        fn assign_judge(
            ref self: ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
            weight: u256,
            is_celebrity: bool,
            payment_amount: u256,
            expertise_level: u8,
            specialty_genres: Array<felt252>,
        ) {
            // Phase 1: Basic validation only - full implementation in Phase 3
            self.ownable.assert_only_owner();
            utils::validate_judge_address(judge_address);
            utils::validate_audition_id(audition_id);
            utils::validate_expertise_level(expertise_level);
            
            // TODO: Full implementation in Phase 3
            panic!("Implementation pending - Phase 3");
        }
        
        fn assign_multiple_judges(
            ref self: ContractState,
            audition_id: felt252,
            judges: Array<BatchJudgeAssignment>,
        ) -> BatchAssignmentResult {
            // Phase 1: Basic validation only
            self.ownable.assert_only_owner();
            utils::validate_audition_id(audition_id);
            
            // TODO: Full implementation in Phase 3
            panic!("Implementation pending - Phase 3");
        }

        // ============================================
        // JUDGE STATUS MANAGEMENT - Phase 3 Implementation (Stub for Phase 1)
        // ============================================
        
        fn activate_judge(
            ref self: ContractState, 
            judge_address: ContractAddress, 
            audition_id: felt252
        ) {
            // TODO: Implementation in Phase 3
            panic!("Implementation pending - Phase 3");
        }
        
        fn deactivate_judge(
            ref self: ContractState, 
            judge_address: ContractAddress, 
            audition_id: felt252
        ) {
            // TODO: Implementation in Phase 3
            panic!("Implementation pending - Phase 3");
        }

        // ============================================
        // WEIGHT MANAGEMENT - Phase 4 Implementation (Stub for Phase 1)
        // ============================================
        
        fn adjust_judge_weight(
            ref self: ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
            new_weight: u256,
        ) {
            // TODO: Implementation in Phase 4
            panic!("Implementation pending - Phase 4");
        }
        
        fn set_weight_limits(ref self: ContractState, limits: WeightLimits) {
            self.ownable.assert_only_owner();
            
            // Basic validation
            assert(limits.max_regular_judge_weight > 0, errors::INVALID_WEIGHT_LIMITS);
            assert(limits.max_celebrity_weight > 0, errors::INVALID_WEIGHT_LIMITS);
            assert(limits.max_total_judge_percentage <= 100, errors::INVALID_WEIGHT_LIMITS);
            assert(limits.min_judges_per_audition > 0, errors::INVALID_WEIGHT_LIMITS);
            assert(limits.max_judges_per_audition >= limits.min_judges_per_audition, errors::INVALID_WEIGHT_LIMITS);
            
            let old_limits = self.weight_limits.read();
            self.weight_limits.write(limits);
            
            self.emit(WeightLimitsUpdated {
                max_regular_weight: limits.max_regular_judge_weight,
                max_celebrity_weight: limits.max_celebrity_weight,
                max_total_percentage: limits.max_total_judge_percentage,
                min_judges_per_audition: limits.min_judges_per_audition,
                max_judges_per_audition: limits.max_judges_per_audition,
                updated_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }

        // ============================================
        // PAYMENT FUNCTIONS - Phase 5 Implementation (Stub for Phase 1)
        // ============================================
        
        fn pay_judge(
            ref self: ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
        ) {
            // TODO: Implementation in Phase 5
            panic!("Implementation pending - Phase 5");
        }
        
        fn process_audition_judge_payments(ref self: ContractState, audition_id: felt252) {
            // TODO: Implementation in Phase 5
            panic!("Implementation pending - Phase 5");
        }

        // ============================================
        // EVALUATION FUNCTIONS - Phase 6 Implementation (Stub for Phase 1)
        // ============================================
        
        fn submit_judge_evaluation(
            ref self: ContractState,
            audition_id: felt252,
            artist_id: felt252,
            scores: Array<u8>,
        ) {
            // TODO: Implementation in Phase 6
            panic!("Implementation pending - Phase 6");
        }

        // ============================================
        // QUERY FUNCTIONS - Phase 7 Implementation (Basic implementations for Phase 1)
        // ============================================
        
        fn get_judge_profile(
            self: @ContractState, 
            judge_address: ContractAddress
        ) -> JudgeProfile {
            self.judge_profiles.read(judge_address)
        }
        
        fn get_audition_judges(
            self: @ContractState, 
            audition_id: felt252
        ) -> Array<ContractAddress> {
            let mut judges = ArrayTrait::new();
            let count = self.audition_judge_count.read(audition_id);
            let mut i = 0;
            loop {
                if i >= count {
                    break;
                }
                let judge = self.audition_judges_by_index.read((audition_id, i));
                if !judge.is_zero() {
                    judges.append(judge);
                }
                i += 1;
            };
            judges
        }
        
        fn get_active_judges(
            self: @ContractState, 
            audition_id: felt252
        ) -> Array<ContractAddress> {
            // TODO: Full implementation in Phase 7
            ArrayTrait::new()
        }
        
        fn get_celebrity_judges(
            self: @ContractState, 
            audition_id: felt252
        ) -> Array<ContractAddress> {
            // TODO: Full implementation in Phase 7
            ArrayTrait::new()
        }

        fn is_judge_assigned_to_audition(
            self: @ContractState,
            audition_id: felt252,
            judge_address: ContractAddress,
        ) -> bool {
            self.audition_judge_assignments.read((audition_id, judge_address))
        }
        
        fn is_judge_eligible_for_payment(
            self: @ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
        ) -> bool {
            // TODO: Full implementation in Phase 5/7
            false
        }

        fn get_total_judge_weight(
            self: @ContractState, 
            audition_id: felt252
        ) -> u256 {
            self.audition_total_weight.read(audition_id)
        }
        
        fn get_weight_limits(self: @ContractState) -> WeightLimits {
            self.weight_limits.read()
        }
        
        fn get_judge_participation_stats(
            self: @ContractState, 
            judge_address: ContractAddress
        ) -> JudgeStats {
            self.judge_stats.read(judge_address)
        }
        
        fn get_audition_judge_info(
            self: @ContractState, 
            audition_id: felt252
        ) -> AuditionJudgeInfo {
            let requirements = self.audition_requirements.read(audition_id);
            let judges = self.get_audition_judges(audition_id);
            let total_weight = self.get_total_judge_weight(audition_id);
            
            AuditionJudgeInfo {
                audition_id,
                assigned_judges: judges,
                total_weight,
                evaluation_deadline: requirements.evaluation_deadline,
                requirements_met: requirements.assigned_count >= requirements.required_count,
            }
        }

        fn get_payment_history(
            self: @ContractState, 
            judge_address: ContractAddress
        ) -> Array<JudgePayment> {
            // TODO: Full implementation in Phase 7
            ArrayTrait::new()
        }
        
        fn get_judge_performance_metrics(
            self: @ContractState, 
            judge_address: ContractAddress
        ) -> JudgePerformanceMetrics {
            // TODO: Full implementation in Phase 7
            let stats = self.get_judge_participation_stats(judge_address);
            JudgePerformanceMetrics {
                judge_address,
                total_auditions: stats.total_auditions_judged,
                average_evaluation_time: 0, // To be calculated
                consistency_score: 0, // To be calculated  
                reputation_score: stats.reputation_score,
            }
        }

        fn set_audition_judge_requirements(
            ref self: ContractState,
            audition_id: felt252,
            required_count: u8,
            weight_percentage: u8,
            evaluation_deadline: u64,
        ) {
            self.ownable.assert_only_owner();
            utils::validate_audition_id(audition_id);
            
            assert(required_count > 0, errors::MIN_JUDGES_REQUIREMENT_NOT_MET);
            assert(weight_percentage <= 100, errors::INVALID_WEIGHT_LIMITS);
            assert(evaluation_deadline > get_block_timestamp(), errors::EVALUATION_PERIOD_ENDED);
            
            let requirements = AuditionJudgeRequirements {
                audition_id,
                required_count,
                weight_percentage,
                assigned_count: 0,
                evaluation_deadline,
                total_weight_assigned: 0,
            };
            
            self.audition_requirements.write(audition_id, requirements);
            
            self.emit(AuditionJudgeRequirementsSet {
                audition_id,
                required_count,
                weight_percentage,
                evaluation_deadline,
                set_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }
    }
}