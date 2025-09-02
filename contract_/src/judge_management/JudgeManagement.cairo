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
        JudgeProfileUpdated, EmergencyStopped, EmergencyResumed, OperatorAuthorized, 
        OperatorRevoked, SeasonAuditionContractSet
    };
    use super::utils;
    use super::IJudgeManagement::{IJudgeManagement, IAccessControl};

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
        
        // Phase 2: Access Control Events
        EmergencyStopped: EmergencyStopped,
        EmergencyResumed: EmergencyResumed,
        OperatorAuthorized: OperatorAuthorized,
        OperatorRevoked: OperatorRevoked,
        SeasonAuditionContractSet: SeasonAuditionContractSet,
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
}