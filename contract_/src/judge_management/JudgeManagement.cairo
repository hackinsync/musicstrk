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
        BatchAssignmentResult, AuditionJudgeInfo, JudgePerformanceMetrics, WeightAdjustment,
        WeightRedistributionResult, WeightDistribution, PaymentConfiguration, PaymentCalculation,
        BatchPaymentResult, JudgePaymentInfo
    };
    use super::events::{
        JudgeAssigned, BatchJudgeAssignment as BatchJudgeAssignmentEvent, JudgeStatusChanged,
        JudgeActivated, JudgeDeactivated, JudgeWeightUpdated, WeightLimitsUpdated,
        JudgePaymentProcessed, BatchJudgePayment, JudgePaymentFailed, JudgeEvaluationSubmitted,
        EvaluationWeightCalculated, JudgeManagementInitialized, AuditionJudgeRequirementsSet,
        JudgeProfileUpdated, EmergencyStopped, EmergencyResumed, OperatorAuthorized, 
        OperatorRevoked, SeasonAuditionContractSet, VotingStatusChanged, 
        WeightRedistributionCompleted, WeightDistributionAnalyzed, PaymentConfigurationUpdated,
        PaymentPoolSet, AuditionCompleted, PaymentEligibilityUpdated, BatchPaymentProcessed,
        PaymentCalculated
    };
    use super::utils;
    use super::IJudgeManagement::{IJudgeManagement, IAccessControl, IWeightManagement, IPaymentManagement};

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
        
        // Phase 2: Emergency Stop & Access Control
        emergency_stopped: bool,
        authorized_operators: LegacyMap<ContractAddress, bool>,
        season_audition_contract: ContractAddress, // For audition existence validation
        
        // Phase 4: Weight Management System Storage
        // Voting status tracking: audition_id -> bool (true if voting started)
        audition_voting_started: LegacyMap<felt252, bool>,
        
        // Weight adjustment history: (audition_id, judge_address, adjustment_index) -> WeightAdjustment
        weight_adjustment_history: LegacyMap<(felt252, ContractAddress, u32), WeightAdjustment>,
        
        // Weight adjustment count: (audition_id, judge_address) -> u32
        weight_adjustment_count: LegacyMap<(felt252, ContractAddress), u32>,
        
        // Phase 5: Payment Integration Storage
        // Payment configuration
        payment_configuration: PaymentConfiguration,
        
        // Payment pool contract address for judge payments
        judge_payment_pool: ContractAddress,
        
        // Payment eligibility: (audition_id, judge_address) -> bool
        payment_eligibility: LegacyMap<(felt252, ContractAddress), bool>,
        
        // Payment status tracking: (audition_id, judge_address) -> PaymentStatus  
        payment_status_tracking: LegacyMap<(felt252, ContractAddress), PaymentStatus>,
        
        // Audition completion status: audition_id -> bool
        audition_completed: LegacyMap<felt252, bool>,
        
        // Audition completion timestamp: audition_id -> u64
        audition_completion_time: LegacyMap<felt252, u64>,
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
        WeightRedistributionCompleted: WeightRedistributionCompleted,
        WeightDistributionAnalyzed: WeightDistributionAnalyzed,
        
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
        
        // Phase 2: Access Control Events
        EmergencyStopped: EmergencyStopped,
        EmergencyResumed: EmergencyResumed,
        OperatorAuthorized: OperatorAuthorized,
        OperatorRevoked: OperatorRevoked,
        SeasonAuditionContractSet: SeasonAuditionContractSet,
        VotingStatusChanged: VotingStatusChanged,
        
        // Phase 5: Payment Events
        PaymentConfigurationUpdated: PaymentConfigurationUpdated,
        PaymentPoolSet: PaymentPoolSet,
        AuditionCompleted: AuditionCompleted,
        PaymentEligibilityUpdated: PaymentEligibilityUpdated,
        BatchPaymentProcessed: BatchPaymentProcessed,
        PaymentCalculated: PaymentCalculated,
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
            // Phase 2: Enhanced access control and validation
            self.assert_only_owner_or_operator();
            self.assert_not_emergency_stopped();
            self.assert_system_initialized();
            
            // Phase 2: Comprehensive input validation
            self.validate_judge_assignment_inputs(
                judge_address, audition_id, weight, is_celebrity, expertise_level
            );
            self.validate_judge_limits_for_audition(audition_id, weight);
            
            // Phase 3: Complete Judge Assignment Implementation
            self._assign_single_judge(
                judge_address, audition_id, weight, is_celebrity, 
                payment_amount, expertise_level, specialty_genres
            );
        }
        
        fn assign_multiple_judges(
            ref self: ContractState,
            audition_id: felt252,
            judges: Array<BatchJudgeAssignment>,
        ) -> BatchAssignmentResult {
            // Phase 2: Enhanced access control and validation
            self.assert_only_owner_or_operator();
            self.assert_not_emergency_stopped();
            self.assert_system_initialized();
            
            // Phase 2: Batch validation
            self.validate_batch_assignment_inputs(audition_id, @judges);
            
            // Phase 3: Complete Batch Assignment Implementation
            self._assign_multiple_judges_internal(audition_id, judges)
        }

        // ============================================
        // JUDGE STATUS MANAGEMENT - Phase 3 Implementation (Stub for Phase 1)
        // ============================================
        
        fn activate_judge(
            ref self: ContractState, 
            judge_address: ContractAddress, 
            audition_id: felt252
        ) {
            // Phase 2: Access control and validation
            self.assert_only_owner_or_operator();
            self.assert_not_emergency_stopped();
            self.assert_system_initialized();
            
            // Phase 3: Complete Judge Activation Implementation
            self._activate_judge_internal(judge_address, audition_id);
        }
        
        fn deactivate_judge(
            ref self: ContractState, 
            judge_address: ContractAddress, 
            audition_id: felt252
        ) {
            // Phase 2: Access control and validation
            self.assert_only_owner_or_operator();
            self.assert_not_emergency_stopped();
            self.assert_system_initialized();
            
            // Phase 3: Complete Judge Deactivation Implementation
            self._deactivate_judge_internal(judge_address, audition_id);
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
            // Phase 2: Access control and validation
            self.assert_only_owner_or_operator();
            self.assert_not_emergency_stopped();
            self.assert_system_initialized();
            
            // Phase 4: Weight adjustment implementation
            self._adjust_judge_weight_internal(judge_address, audition_id, new_weight, 'Manual adjustment');
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
        // PAYMENT FUNCTIONS - Phase 5 Implementation
        // ============================================
        
        fn pay_judge(
            ref self: ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
        ) {
            // Phase 2: Access control and validation
            self.assert_only_owner_or_operator();
            self.assert_not_emergency_stopped();
            self.assert_system_initialized();
            
            // Phase 5: Complete Payment Implementation
            self._pay_single_judge_internal(judge_address, audition_id);
        }
        
        fn process_audition_judge_payments(ref self: ContractState, audition_id: felt252) {
            // Phase 2: Access control and validation
            self.assert_only_owner_or_operator();
            self.assert_not_emergency_stopped();
            self.assert_system_initialized();
            
            // Phase 5: Complete Batch Payment Implementation
            self._process_batch_payments_internal(audition_id);
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

    // ============================================
    // PHASE 2: ACCESS CONTROL & VALIDATION IMPLEMENTATION
    // ============================================

    #[generate_trait]
    impl AccessControlImpl of AccessControlTrait {
        // ============================================
        // 2.1 OWNER-ONLY FUNCTIONS & MODIFIER/ASSERTION FUNCTIONS
        // ============================================

        fn assert_only_owner_or_operator(self: @ContractState) {
            let caller = get_caller_address();
            let is_owner = caller == self.ownable.owner();
            let is_operator = self.authorized_operators.read(caller);
            assert(is_owner || is_operator, errors::CALLER_UNAUTHORIZED);
        }

        fn assert_not_emergency_stopped(self: @ContractState) {
            assert(!self.emergency_stopped.read(), 'Emergency stop active');
        }

        fn assert_system_initialized(self: @ContractState) {
            assert(self.is_initialized.read(), 'System not initialized');
        }

        // ============================================
        // 2.2 COMPREHENSIVE INPUT VALIDATION
        // ============================================

        fn validate_judge_assignment_inputs(
            self: @ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
            weight: u256,
            is_celebrity: bool,
            expertise_level: u8,
        ) {
            // Address validation
            utils::validate_judge_address(judge_address);
            
            // Audition validation
            self.validate_audition_exists(audition_id);
            
            // Judge not already assigned validation
            assert(!self.audition_judge_assignments.read((audition_id, judge_address)), errors::JUDGE_ALREADY_ASSIGNED);
            
            // Weight limit validation
            let limits = self.weight_limits.read();
            utils::validate_weight_against_limits(weight, is_celebrity, limits);
            
            // Expertise level validation
            utils::validate_expertise_level(expertise_level);
            
            // Weight must be greater than zero
            assert(weight > 0, errors::JUDGE_WEIGHT_EXCEEDS_LIMIT);
        }

        fn validate_audition_exists(self: @ContractState, audition_id: felt252) {
            // Basic audition ID validation
            utils::validate_audition_id(audition_id);
            
            // If season_audition_contract is set, validate with that contract
            let season_contract = self.season_audition_contract.read();
            if !season_contract.is_zero() {
                // TODO: Call season_audition_contract to verify audition exists
                // For now, we'll validate that the audition has requirements set
                let requirements = self.audition_requirements.read(audition_id);
                assert(requirements.audition_id != 0, errors::AUDITION_DOES_NOT_EXIST);
            }
        }

        fn validate_judge_limits_for_audition(
            self: @ContractState,
            audition_id: felt252,
            new_weight: u256,
        ) {
            let limits = self.weight_limits.read();
            let requirements = self.audition_requirements.read(audition_id);
            
            // Check maximum judges per audition
            let current_count = self.audition_judge_count.read(audition_id);
            assert(current_count < limits.max_judges_per_audition.into(), errors::MAX_JUDGES_LIMIT_REACHED);
            
            // Check total weight percentage
            let current_total_weight = self.audition_total_weight.read(audition_id);
            let new_total_weight = current_total_weight + new_weight;
            
            // For this validation, we assume a base voting power (this would come from the main voting system)
            let assumed_total_voting_power: u256 = 1000; // This should come from integration
            utils::validate_total_weight_percentage(
                current_total_weight,
                new_weight,
                assumed_total_voting_power,
                limits.max_total_judge_percentage
            );
        }

        fn validate_batch_assignment_inputs(
            self: @ContractState,
            audition_id: felt252,
            judges: @Array<BatchJudgeAssignment>,
        ) {
            // Basic validations
            utils::validate_audition_id(audition_id);
            self.validate_audition_exists(audition_id);
            
            // Check if batch size is reasonable
            assert(judges.len() > 0, errors::ARRAY_LENGTH_MISMATCH);
            assert(judges.len() <= 20, 'Batch size too large'); // Reasonable gas limit
            
            // Validate each judge in the batch
            let mut i = 0;
            loop {
                if i >= judges.len() {
                    break;
                }
                let judge_assignment = judges.at(i);
                
                // Validate each judge's inputs
                self.validate_judge_assignment_inputs(
                    judge_assignment.judge_address,
                    audition_id,
                    judge_assignment.weight,
                    judge_assignment.is_celebrity,
                    judge_assignment.expertise_level,
                );
                
                i += 1;
            };
        }
    }

    // ============================================
    // PHASE 2: PUBLIC ACCESS CONTROL FUNCTIONS
    // ============================================

    #[abi(embed_v0)]
    impl AccessControlPublicImpl of IAccessControl<ContractState> {
        
        fn emergency_stop(ref self: ContractState, reason: felt252) {
            self.ownable.assert_only_owner();
            assert(!self.emergency_stopped.read(), 'Already emergency stopped');
            
            self.emergency_stopped.write(true);
            
            self.emit(EmergencyStopped {
                stopped_by: get_caller_address(),
                reason,
                timestamp: get_block_timestamp(),
            });
        }

        fn emergency_resume(ref self: ContractState) {
            self.ownable.assert_only_owner();
            assert(self.emergency_stopped.read(), 'Not emergency stopped');
            
            self.emergency_stopped.write(false);
            
            self.emit(EmergencyResumed {
                resumed_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }

        fn authorize_operator(ref self: ContractState, operator: ContractAddress) {
            self.ownable.assert_only_owner();
            utils::validate_judge_address(operator); // Reuse address validation
            
            assert(!self.authorized_operators.read(operator), 'Already authorized');
            
            self.authorized_operators.write(operator, true);
            
            self.emit(OperatorAuthorized {
                operator,
                authorized_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }

        fn revoke_operator(ref self: ContractState, operator: ContractAddress) {
            self.ownable.assert_only_owner();
            
            assert(self.authorized_operators.read(operator), 'Not authorized');
            
            self.authorized_operators.write(operator, false);
            
            self.emit(OperatorRevoked {
                operator,
                revoked_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }

        fn set_season_audition_contract(ref self: ContractState, contract_address: ContractAddress) {
            self.ownable.assert_only_owner();
            
            let old_contract = self.season_audition_contract.read();
            self.season_audition_contract.write(contract_address);
            
            self.emit(SeasonAuditionContractSet {
                old_contract,
                new_contract: contract_address,
                set_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }

        // ============================================
        // ACCESS CONTROL QUERY FUNCTIONS
        // ============================================

        fn is_emergency_stopped(self: @ContractState) -> bool {
            self.emergency_stopped.read()
        }

        fn is_authorized_operator(self: @ContractState, operator: ContractAddress) -> bool {
            self.authorized_operators.read(operator)
        }

        fn get_season_audition_contract(self: @ContractState) -> ContractAddress {
            self.season_audition_contract.read()
        }
    }

    // ============================================
    // PHASE 3: JUDGE ASSIGNMENT SYSTEM IMPLEMENTATION
    // ============================================

    #[generate_trait]
    impl JudgeAssignmentImpl of JudgeAssignmentTrait {
        
        // ============================================
        // 3.1 SINGLE JUDGE ASSIGNMENT IMPLEMENTATION
        // ============================================

        fn _assign_single_judge(
            ref self: ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
            weight: u256,
            is_celebrity: bool,
            payment_amount: u256,
            expertise_level: u8,
            specialty_genres: Array<felt252>,
        ) {
            let timestamp = get_block_timestamp();
            
            // Create judge profile
            let judge_profile = JudgeProfile {
                address: judge_address,
                weight,
                is_celebrity,
                expertise_level,
                assigned_timestamp: timestamp,
                is_active: true,
                payment_amount,
                specialty_genres: specialty_genres.clone(),
                total_evaluations: 0,
            };
            
            // Store judge profile
            self.judge_profiles.write(judge_address, judge_profile);
            
            // Mark judge as assigned to this audition
            self.audition_judge_assignments.write((audition_id, judge_address), true);
            
            // Add judge to audition's judge list
            let current_count = self.audition_judge_count.read(audition_id);
            self.audition_judges_by_index.write((audition_id, current_count), judge_address);
            self.audition_judge_count.write(audition_id, current_count + 1);
            
            // Update total weight for audition
            let current_total = self.audition_total_weight.read(audition_id);
            self.audition_total_weight.write(audition_id, current_total + weight);
            
            // Update audition requirements
            let mut requirements = self.audition_requirements.read(audition_id);
            requirements.assigned_count += 1;
            requirements.total_weight_assigned += weight;
            self.audition_requirements.write(audition_id, requirements);
            
            // Initialize judge stats if first time
            let mut stats = self.judge_stats.read(judge_address);
            if stats.total_auditions_judged == 0 {
                stats = JudgeStats {
                    total_auditions_judged: 1,
                    total_payments_received: 0,
                    average_score_given: 0,
                    reputation_score: 100, // Starting reputation
                };
            } else {
                stats.total_auditions_judged += 1;
            }
            self.judge_stats.write(judge_address, stats);
            
            // Emit assignment event
            self.emit(JudgeAssigned {
                judge_address,
                audition_id,
                weight,
                is_celebrity,
                assigned_by: get_caller_address(),
                timestamp,
                payment_amount,
            });
        }

        // ============================================
        // 3.2 BATCH JUDGE OPERATIONS IMPLEMENTATION
        // ============================================

        fn _assign_multiple_judges_internal(
            ref self: ContractState,
            audition_id: felt252,
            judges: Array<BatchJudgeAssignment>,
        ) -> BatchAssignmentResult {
            let mut successful_assignments = 0_u8;
            let mut failed_assignments = 0_u8;
            let mut total_weight_assigned = 0_u256;
            let timestamp = get_block_timestamp();
            
            // Process each judge assignment
            let mut i = 0;
            loop {
                if i >= judges.len() {
                    break;
                }
                
                let judge_assignment = judges.at(i);
                
                // Try to assign each judge (with individual error handling)
                let assignment_result = self._try_assign_judge(
                    judge_assignment.judge_address,
                    audition_id,
                    judge_assignment.weight,
                    judge_assignment.is_celebrity,
                    judge_assignment.payment_amount,
                    judge_assignment.expertise_level,
                    judge_assignment.specialty_genres.clone(),
                );
                
                if assignment_result {
                    successful_assignments += 1;
                    total_weight_assigned += judge_assignment.weight;
                } else {
                    failed_assignments += 1;
                }
                
                i += 1;
            };
            
            // Emit batch assignment event
            self.emit(BatchJudgeAssignmentEvent {
                audition_id,
                judges_assigned: successful_assignments,
                total_weight: total_weight_assigned,
                assigned_by: get_caller_address(),
                timestamp,
            });
            
            BatchAssignmentResult {
                successful_assignments,
                failed_assignments,
                total_weight_assigned,
            }
        }

        fn _try_assign_judge(
            ref self: ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
            weight: u256,
            is_celebrity: bool,
            payment_amount: u256,
            expertise_level: u8,
            specialty_genres: Array<felt252>,
        ) -> bool {
            // Individual validation for batch processing
            // Return false instead of panicking to continue with other judges
            
            // Check if judge already assigned
            if self.audition_judge_assignments.read((audition_id, judge_address)) {
                return false;
            }
            
            // Check weight limits
            let limits = self.weight_limits.read();
            if is_celebrity && weight > limits.max_celebrity_weight {
                return false;
            }
            if !is_celebrity && weight > limits.max_regular_judge_weight {
                return false;
            }
            
            // Check audition capacity
            let current_count = self.audition_judge_count.read(audition_id);
            if current_count >= limits.max_judges_per_audition.into() {
                return false;
            }
            
            // If all checks pass, assign the judge
            self._assign_single_judge(
                judge_address, audition_id, weight, is_celebrity,
                payment_amount, expertise_level, specialty_genres
            );
            
            true
        }

        // ============================================
        // 3.3 JUDGE STATUS MANAGEMENT IMPLEMENTATION
        // ============================================

        fn _activate_judge_internal(
            ref self: ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
        ) {
            // Validation
            assert(self.audition_judge_assignments.read((audition_id, judge_address)), errors::JUDGE_NOT_ASSIGNED);
            
            let mut profile = self.judge_profiles.read(judge_address);
            assert(!profile.is_active, errors::JUDGE_ALREADY_ACTIVE);
            
            // Activate the judge
            profile.is_active = true;
            self.judge_profiles.write(judge_address, profile);
            
            // Emit activation event
            self.emit(JudgeActivated {
                judge_address,
                audition_id,
                activated_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }

        fn _deactivate_judge_internal(
            ref self: ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
        ) {
            // Validation
            assert(self.audition_judge_assignments.read((audition_id, judge_address)), errors::JUDGE_NOT_ASSIGNED);
            
            let mut profile = self.judge_profiles.read(judge_address);
            assert(profile.is_active, errors::JUDGE_NOT_ACTIVE);
            
            // Deactivate the judge
            profile.is_active = false;
            self.judge_profiles.write(judge_address, profile);
            
            // Emit deactivation event
            self.emit(JudgeDeactivated {
                judge_address,
                audition_id,
                deactivated_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }
    }

    // ============================================
    // PHASE 4: WEIGHT MANAGEMENT SYSTEM IMPLEMENTATION
    // ============================================

    #[generate_trait]
    impl WeightManagementImpl of WeightManagementTrait {
        
        // ============================================
        // 4.1 WEIGHT ADJUSTMENT IMPLEMENTATION
        // ============================================

        fn _adjust_judge_weight_internal(
            ref self: ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
            new_weight: u256,
            reason: felt252,
        ) {
            // Validation: Judge must be assigned to audition
            assert(self.audition_judge_assignments.read((audition_id, judge_address)), errors::JUDGE_NOT_ASSIGNED);
            
            // Validation: Voting must not have started
            assert(!self.audition_voting_started.read(audition_id), errors::VOTING_ALREADY_STARTED);
            
            let mut profile = self.judge_profiles.read(judge_address);
            let old_weight = profile.weight;
            
            // Validate new weight against limits
            let limits = self.weight_limits.read();
            utils::validate_weight_against_limits(new_weight, profile.is_celebrity, limits);
            
            // Validate total weight after adjustment
            let current_total = self.audition_total_weight.read(audition_id);
            let new_total = current_total - old_weight + new_weight;
            
            // Check against maximum total judge percentage
            let assumed_total_voting_power: u256 = 1000; // Integration point
            let new_percentage = (new_total * 100) / assumed_total_voting_power;
            assert(new_percentage <= limits.max_total_judge_percentage.into(), errors::TOTAL_JUDGE_WEIGHT_EXCEEDED);
            
            // Update judge profile with new weight
            profile.weight = new_weight;
            self.judge_profiles.write(judge_address, profile);
            
            // Update audition total weight
            self.audition_total_weight.write(audition_id, new_total);
            
            // Update audition requirements
            let mut requirements = self.audition_requirements.read(audition_id);
            requirements.total_weight_assigned = requirements.total_weight_assigned - old_weight + new_weight;
            self.audition_requirements.write(audition_id, requirements);
            
            // Record weight adjustment in history
            let adjustment_count = self.weight_adjustment_count.read((audition_id, judge_address));
            let adjustment = WeightAdjustment {
                audition_id,
                judge_address,
                old_weight,
                new_weight,
                adjustment_reason: reason,
                adjusted_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            };
            
            self.weight_adjustment_history.write((audition_id, judge_address, adjustment_count), adjustment);
            self.weight_adjustment_count.write((audition_id, judge_address), adjustment_count + 1);
            
            // Emit weight update event
            self.emit(JudgeWeightUpdated {
                judge_address,
                audition_id,
                old_weight,
                new_weight,
                updated_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }

        // ============================================
        // 4.2 WEIGHT REDISTRIBUTION IMPLEMENTATION
        // ============================================

        fn _redistribute_weights_proportionally_internal(
            ref self: ContractState,
            audition_id: felt252,
            target_total_weight: u256,
        ) -> WeightRedistributionResult {
            // Validation: Voting must not have started
            assert(!self.audition_voting_started.read(audition_id), errors::VOTING_ALREADY_STARTED);
            
            let judges = self.get_audition_judges(audition_id);
            let current_total = self.audition_total_weight.read(audition_id);
            
            if current_total == 0 || judges.len() == 0 {
                return WeightRedistributionResult {
                    successful_adjustments: 0,
                    failed_adjustments: 0,
                    total_weight_before: current_total,
                    total_weight_after: current_total,
                    redistribution_applied: false,
                };
            }
            
            let mut successful_adjustments = 0_u8;
            let mut failed_adjustments = 0_u8;
            let mut new_total_weight = 0_u256;
            
            // Redistribute weights proportionally
            let mut i = 0;
            loop {
                if i >= judges.len() {
                    break;
                }
                
                let judge_address = *judges.at(i);
                let profile = self.judge_profiles.read(judge_address);
                
                // Calculate new proportional weight
                let new_weight = (profile.weight * target_total_weight) / current_total;
                
                // Validate the new weight against limits
                let limits = self.weight_limits.read();
                let is_valid = if profile.is_celebrity {
                    new_weight <= limits.max_celebrity_weight
                } else {
                    new_weight <= limits.max_regular_judge_weight
                };
                
                if is_valid && new_weight > 0 {
                    self._adjust_judge_weight_internal(
                        judge_address,
                        audition_id,
                        new_weight,
                        'Weight redistribution'
                    );
                    successful_adjustments += 1;
                    new_total_weight += new_weight;
                } else {
                    failed_adjustments += 1;
                    new_total_weight += profile.weight; // Keep old weight
                }
                
                i += 1;
            };
            
            // Emit redistribution completed event
            self.emit(WeightRedistributionCompleted {
                audition_id,
                successful_adjustments,
                failed_adjustments,
                total_weight_before: current_total,
                total_weight_after: new_total_weight,
                redistributed_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
            
            WeightRedistributionResult {
                successful_adjustments,
                failed_adjustments,
                total_weight_before: current_total,
                total_weight_after: new_total_weight,
                redistribution_applied: successful_adjustments > 0,
            }
        }

        // ============================================
        // 4.3 VOTING STATUS MANAGEMENT
        // ============================================

        fn _set_voting_status_internal(
            ref self: ContractState,
            audition_id: felt252,
            voting_started: bool,
        ) {
            let current_status = self.audition_voting_started.read(audition_id);
            if current_status != voting_started {
                self.audition_voting_started.write(audition_id, voting_started);
                
                self.emit(VotingStatusChanged {
                    audition_id,
                    voting_started,
                    changed_by: get_caller_address(),
                    timestamp: get_block_timestamp(),
                });
            }
        }

        // ============================================
        // 4.4 WEIGHT DISTRIBUTION ANALYSIS
        // ============================================

        fn _analyze_weight_distribution_internal(
            self: @ContractState,
            audition_id: felt252,
        ) -> WeightDistribution {
            let judges = self.get_audition_judges(audition_id);
            let mut judge_weights = ArrayTrait::new();
            let mut total_judge_weight = 0_u256;
            let mut celebrity_weight = 0_u256;
            let mut regular_weight = 0_u256;
            let mut max_individual_weight = 0_u256;
            
            // Analyze each judge's weight
            let mut i = 0;
            loop {
                if i >= judges.len() {
                    break;
                }
                
                let judge_address = *judges.at(i);
                let profile = self.judge_profiles.read(judge_address);
                
                judge_weights.append((judge_address, profile.weight));
                total_judge_weight += profile.weight;
                
                if profile.is_celebrity {
                    celebrity_weight += profile.weight;
                } else {
                    regular_weight += profile.weight;
                }
                
                if profile.weight > max_individual_weight {
                    max_individual_weight = profile.weight;
                }
                
                i += 1;
            };
            
            // Calculate weight concentration (highest individual percentage)
            let weight_concentration = if total_judge_weight > 0 {
                (max_individual_weight * 100) / total_judge_weight
            } else {
                0
            };
            
            // Emit analysis event
            self.emit(WeightDistributionAnalyzed {
                audition_id,
                total_judge_weight,
                celebrity_weight,
                regular_weight,
                weight_concentration,
                analyzed_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
            
            WeightDistribution {
                audition_id,
                judge_weights,
                total_judge_weight,
                celebrity_judge_weight: celebrity_weight,
                regular_judge_weight: regular_weight,
                weight_concentration,
            }
        }
    }

    // ============================================
    // PHASE 4: PUBLIC WEIGHT MANAGEMENT FUNCTIONS
    // ============================================

    #[abi(embed_v0)]
    impl WeightManagementPublicImpl of IWeightManagement<ContractState> {
        
        fn redistribute_weights_proportionally(
            ref self: ContractState,
            audition_id: felt252,
            target_total_weight: u256,
        ) -> WeightRedistributionResult {
            // Access control
            self.assert_only_owner_or_operator();
            self.assert_not_emergency_stopped();
            self.assert_system_initialized();
            
            // Call internal implementation
            self._redistribute_weights_proportionally_internal(audition_id, target_total_weight)
        }

        fn set_voting_status(
            ref self: ContractState,
            audition_id: felt252,
            voting_started: bool,
        ) {
            // Access control - only owner/operator can change voting status
            self.assert_only_owner_or_operator();
            self.assert_not_emergency_stopped();
            self.assert_system_initialized();
            
            // Validate audition exists
            utils::validate_audition_id(audition_id);
            
            // Call internal implementation
            self._set_voting_status_internal(audition_id, voting_started);
        }

        fn analyze_weight_distribution(
            self: @ContractState,
            audition_id: felt252,
        ) -> WeightDistribution {
            // Validate audition exists
            utils::validate_audition_id(audition_id);
            
            // Call internal implementation
            self._analyze_weight_distribution_internal(audition_id)
        }

        fn get_weight_adjustment_history(
            self: @ContractState,
            audition_id: felt252,
            judge_address: ContractAddress,
        ) -> Array<WeightAdjustment> {
            let mut history = ArrayTrait::new();
            let count = self.weight_adjustment_count.read((audition_id, judge_address));
            
            let mut i = 0;
            loop {
                if i >= count {
                    break;
                }
                let adjustment = self.weight_adjustment_history.read((audition_id, judge_address, i));
                history.append(adjustment);
                i += 1;
            };
            
            history
        }

        fn is_voting_started(self: @ContractState, audition_id: felt252) -> bool {
            self.audition_voting_started.read(audition_id)
        }

        fn get_weight_concentration(self: @ContractState, audition_id: felt252) -> u256 {
            let distribution = self.analyze_weight_distribution(audition_id);
            distribution.weight_concentration
        }

        fn can_adjust_weights(self: @ContractState, audition_id: felt252) -> bool {
            // Can adjust weights if voting hasn't started and system is not emergency stopped
            !self.audition_voting_started.read(audition_id) && !self.emergency_stopped.read()
        }
    }

    // ============================================
    // PHASE 5: PAYMENT INTEGRATION IMPLEMENTATION
    // ============================================

    #[generate_trait]
    impl PaymentManagementImpl of PaymentManagementTrait {
        
        // ============================================
        // 5.1 PAYMENT CALCULATION IMPLEMENTATION
        // ============================================

        fn _calculate_judge_payment_internal(
            self: @ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
        ) -> PaymentCalculation {
            let profile = self.judge_profiles.read(judge_address);
            let config = self.payment_configuration.read();
            
            // Calculate base payment percentage based on judge type
            let payment_rate = if profile.is_celebrity {
                config.celebrity_judge_rate
            } else {
                config.regular_judge_rate
            };
            
            // Get pool balance from payment pool contract
            // TODO: Integrate with actual payment pool contract
            let assumed_pool_balance: u256 = 10000000; // Integration point
            
            // Calculate base amount (percentage of pool)
            let base_amount = (assumed_pool_balance * payment_rate) / 10000; // rate in basis points
            
            // Calculate celebrity bonus (additional amount for celebrity judges)
            let celebrity_bonus = if profile.is_celebrity {
                base_amount / 4 // 25% bonus for celebrity judges
            } else {
                0
            };
            
            let total_amount = base_amount + celebrity_bonus;
            
            PaymentCalculation {
                judge_address,
                audition_id,
                base_amount,
                celebrity_bonus,
                total_amount,
                pool_percentage: payment_rate,
            }
        }

        fn _validate_payment_eligibility_internal(
            self: @ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
        ) -> bool {
            // Check if judge is assigned to audition
            if !self.audition_judge_assignments.read((audition_id, judge_address)) {
                return false;
            }
            
            // Check if audition is completed
            if !self.audition_completed.read(audition_id) {
                return false;
            }
            
            // Check if payment delay has passed
            let config = self.payment_configuration.read();
            let completion_time = self.audition_completion_time.read(audition_id);
            let current_time = get_block_timestamp();
            
            if current_time < completion_time + config.payment_delay {
                return false;
            }
            
            // Check if judge hasn't been paid yet
            let payment_status = self.payment_status_tracking.read((audition_id, judge_address));
            if payment_status == PaymentStatus::Paid {
                return false;
            }
            
            // Check if payment is explicitly eligible
            self.payment_eligibility.read((audition_id, judge_address))
        }

        // ============================================
        // 5.2 SINGLE JUDGE PAYMENT IMPLEMENTATION
        // ============================================

        fn _pay_single_judge_internal(
            ref self: ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
        ) {
            // Validate payment eligibility
            assert(self._validate_payment_eligibility_internal(judge_address, audition_id), errors::JUDGE_NOT_ELIGIBLE_FOR_PAYMENT);
            
            // Calculate payment amount
            let payment_calc = self._calculate_judge_payment_internal(judge_address, audition_id);
            
            // Validate minimum pool balance
            let config = self.payment_configuration.read();
            let assumed_pool_balance: u256 = 10000000; // Integration point
            assert(assumed_pool_balance >= config.minimum_pool_balance, errors::INSUFFICIENT_POOL_BALANCE);
            assert(payment_calc.total_amount <= assumed_pool_balance, errors::INSUFFICIENT_POOL_BALANCE);
            
            let timestamp = get_block_timestamp();
            
            // Create payment record
            let payment_record = JudgePayment {
                judge_address,
                audition_id,
                season_id: 0, // TODO: Get from audition context
                amount_paid: payment_calc.total_amount,
                payment_timestamp: timestamp,
                payment_status: PaymentStatus::Paid,
            };
            
            // Store payment record
            self.judge_payments.write((judge_address, audition_id), payment_record);
            
            // Update payment status
            self.payment_status_tracking.write((audition_id, judge_address), PaymentStatus::Paid);
            
            // Update judge stats
            let mut stats = self.judge_stats.read(judge_address);
            stats.total_payments_received += payment_calc.total_amount;
            self.judge_stats.write(judge_address, stats);
            
            // TODO: Execute actual payment transfer via payment pool contract
            // This would typically call the payment pool contract to transfer tokens
            
            // Emit payment events
            self.emit(PaymentCalculated {
                judge_address: payment_calc.judge_address,
                audition_id: payment_calc.audition_id,
                base_amount: payment_calc.base_amount,
                celebrity_bonus: payment_calc.celebrity_bonus,
                total_amount: payment_calc.total_amount,
                pool_percentage: payment_calc.pool_percentage,
                timestamp,
            });
            
            self.emit(JudgePaymentProcessed {
                judge_address,
                audition_id,
                amount: payment_calc.total_amount,
                payment_status: PaymentStatus::Paid,
                processed_by: get_caller_address(),
                timestamp,
            });
        }

        // ============================================
        // 5.3 BATCH PAYMENT IMPLEMENTATION
        // ============================================

        fn _process_batch_payments_internal(
            ref self: ContractState,
            audition_id: felt252,
        ) {
            // Validate audition exists and is completed
            utils::validate_audition_id(audition_id);
            assert(self.audition_completed.read(audition_id), errors::AUDITION_NOT_COMPLETED);
            
            let judges = self.get_audition_judges(audition_id);
            let mut successful_payments = 0_u8;
            let mut failed_payments = 0_u8;
            let mut total_amount_paid = 0_u256;
            
            // Process payment for each judge
            let mut i = 0;
            loop {
                if i >= judges.len() {
                    break;
                }
                
                let judge_address = *judges.at(i);
                
                // Try to pay each judge individually
                let payment_result = self._try_pay_judge_internal(judge_address, audition_id);
                
                if payment_result.0 {
                    successful_payments += 1;
                    total_amount_paid += payment_result.1;
                } else {
                    failed_payments += 1;
                }
                
                i += 1;
            };
            
            // Emit batch payment event
            self.emit(BatchPaymentProcessed {
                audition_id,
                successful_payments,
                failed_payments,
                total_amount_paid,
                processed_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }

        fn _try_pay_judge_internal(
            ref self: ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
        ) -> (bool, u256) {
            // Return (success, amount_paid)
            
            // Check eligibility without panicking
            if !self._validate_payment_eligibility_internal(judge_address, audition_id) {
                // Emit failure event
                self.emit(JudgePaymentFailed {
                    judge_address,
                    audition_id,
                    amount: 0,
                    reason: 'Not eligible for payment',
                    timestamp: get_block_timestamp(),
                });
                return (false, 0);
            }
            
            // Calculate payment
            let payment_calc = self._calculate_judge_payment_internal(judge_address, audition_id);
            
            // Validate pool balance
            let config = self.payment_configuration.read();
            let assumed_pool_balance: u256 = 10000000; // Integration point
            
            if payment_calc.total_amount > assumed_pool_balance || assumed_pool_balance < config.minimum_pool_balance {
                self.emit(JudgePaymentFailed {
                    judge_address,
                    audition_id,
                    amount: payment_calc.total_amount,
                    reason: 'Insufficient pool balance',
                    timestamp: get_block_timestamp(),
                });
                return (false, 0);
            }
            
            // Process payment
            self._pay_single_judge_internal(judge_address, audition_id);
            
            (true, payment_calc.total_amount)
        }

        // ============================================
        // 5.4 AUDITION COMPLETION MANAGEMENT
        // ============================================

        fn _complete_audition_internal(
            ref self: ContractState,
            audition_id: felt252,
        ) {
            // Validate audition exists and is not already completed
            utils::validate_audition_id(audition_id);
            assert(!self.audition_completed.read(audition_id), errors::AUDITION_ALREADY_COMPLETED);
            
            let timestamp = get_block_timestamp();
            
            // Mark audition as completed
            self.audition_completed.write(audition_id, true);
            self.audition_completion_time.write(audition_id, timestamp);
            
            // Set payment eligibility for all judges
            let judges = self.get_audition_judges(audition_id);
            let mut i = 0;
            loop {
                if i >= judges.len() {
                    break;
                }
                
                let judge_address = *judges.at(i);
                self.payment_eligibility.write((audition_id, judge_address), true);
                
                // Emit eligibility update event
                self.emit(PaymentEligibilityUpdated {
                    audition_id,
                    judge_address,
                    is_eligible: true,
                    reason: 'Audition completed',
                    updated_by: get_caller_address(),
                    timestamp,
                });
                
                i += 1;
            };
            
            // Emit audition completion event
            self.emit(AuditionCompleted {
                audition_id,
                completed_by: get_caller_address(),
                timestamp,
                judges_count: judges.len().try_into().unwrap(),
            });
        }
    }

    // ============================================
    // PHASE 5: PUBLIC PAYMENT MANAGEMENT FUNCTIONS
    // ============================================

    #[abi(embed_v0)]
    impl PaymentManagementPublicImpl of IPaymentManagement<ContractState> {
        
        fn set_payment_configuration(
            ref self: ContractState,
            config: PaymentConfiguration,
        ) {
            // Access control
            self.ownable.assert_only_owner();
            self.assert_not_emergency_stopped();
            
            // Validate configuration parameters
            assert(config.regular_judge_rate > 0 && config.regular_judge_rate <= 1000, errors::INVALID_PAYMENT_RATE); // Max 10%
            assert(config.celebrity_judge_rate > 0 && config.celebrity_judge_rate <= 3000, errors::INVALID_PAYMENT_RATE); // Max 30%
            assert(config.minimum_pool_balance > 0, errors::INVALID_PAYMENT_CONFIG);
            assert(config.payment_delay <= 86400 * 7, errors::INVALID_PAYMENT_CONFIG); // Max 7 days delay
            
            self.payment_configuration.write(config);
            
            // Emit configuration update event
            self.emit(PaymentConfigurationUpdated {
                regular_judge_rate: config.regular_judge_rate,
                celebrity_judge_rate: config.celebrity_judge_rate,
                minimum_pool_balance: config.minimum_pool_balance,
                payment_delay: config.payment_delay,
                updated_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }

        fn set_payment_pool(
            ref self: ContractState,
            pool_address: ContractAddress,
        ) {
            // Access control
            self.ownable.assert_only_owner();
            
            let old_pool = self.judge_payment_pool.read();
            self.judge_payment_pool.write(pool_address);
            
            // Emit pool change event
            self.emit(PaymentPoolSet {
                old_pool,
                new_pool: pool_address,
                set_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }

        fn complete_audition(
            ref self: ContractState,
            audition_id: felt252,
        ) {
            // Access control
            self.assert_only_owner_or_operator();
            self.assert_not_emergency_stopped();
            self.assert_system_initialized();
            
            // Call internal implementation
            self._complete_audition_internal(audition_id);
        }

        fn set_payment_eligibility(
            ref self: ContractState,
            audition_id: felt252,
            judge_address: ContractAddress,
            is_eligible: bool,
            reason: felt252,
        ) {
            // Access control
            self.assert_only_owner_or_operator();
            self.assert_not_emergency_stopped();
            self.assert_system_initialized();
            
            // Validate judge is assigned to audition
            assert(self.audition_judge_assignments.read((audition_id, judge_address)), errors::JUDGE_NOT_ASSIGNED);
            
            // Update eligibility
            self.payment_eligibility.write((audition_id, judge_address), is_eligible);
            
            // Emit eligibility update event
            self.emit(PaymentEligibilityUpdated {
                audition_id,
                judge_address,
                is_eligible,
                reason,
                updated_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            });
        }

        fn calculate_judge_payment(
            self: @ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
        ) -> PaymentCalculation {
            // Validate judge is assigned
            assert(self.audition_judge_assignments.read((audition_id, judge_address)), errors::JUDGE_NOT_ASSIGNED);
            
            // Call internal calculation
            self._calculate_judge_payment_internal(judge_address, audition_id)
        }

        fn get_judge_payment_info(
            self: @ContractState,
            judge_address: ContractAddress,
            audition_id: felt252,
        ) -> JudgePaymentInfo {
            let is_eligible = self._validate_payment_eligibility_internal(judge_address, audition_id);
            let payment_status = self.payment_status_tracking.read((audition_id, judge_address));
            let participation_verified = self.audition_judge_assignments.read((audition_id, judge_address));
            let audition_completed = self.audition_completed.read(audition_id);
            
            let payment_amount = if is_eligible {
                let calc = self._calculate_judge_payment_internal(judge_address, audition_id);
                calc.total_amount
            } else {
                0
            };
            
            JudgePaymentInfo {
                judge_address,
                is_eligible,
                payment_amount,
                payment_status,
                participation_verified,
                audition_completed,
            }
        }

        fn get_payment_configuration(self: @ContractState) -> PaymentConfiguration {
            self.payment_configuration.read()
        }

        fn get_payment_pool(self: @ContractState) -> ContractAddress {
            self.judge_payment_pool.read()
        }

        fn is_audition_completed(self: @ContractState, audition_id: felt252) -> bool {
            self.audition_completed.read(audition_id)
        }

        fn get_audition_completion_time(self: @ContractState, audition_id: felt252) -> u64 {
            self.audition_completion_time.read(audition_id)
        }
    }
}