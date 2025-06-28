use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Season {
    pub name: felt252,
    pub start_timestamp: u64,
    pub end_timestamp: u64,
    pub paused: bool,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Audition {
    pub season_id: felt252,
    pub genre: felt252,
    pub name: felt252,
    pub start_timestamp: u64,
    pub end_timestamp: u64,
    pub paused: bool,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Vote {
    pub audition_id: felt252,
    pub performer_id: felt252,
    pub voter_id: ContractAddress,
    pub score: u32,
    pub timestamp: u64,
}

/// Enhanced performance evaluation structure with comprehensive validation
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PerformanceEvaluation {
    pub oracle: ContractAddress,
    pub score: u32,
    pub comments: felt252,
    pub timestamp: u64,
    pub submission_hash: felt252, // For integrity verification
    pub criteria_breakdown: felt252, // JSON-encoded criteria scores
    pub confidence_level: u8, // Oracle confidence 1-100
    pub technical_score: u32, // Technical performance 0-100
    pub artistic_score: u32, // Artistic performance 0-100
    pub stage_presence: u32, // Stage presence 0-100
    pub originality: u32, // Originality 0-100
    pub overall_impression: u32 // Overall impression 0-100
}

/// Session status update with venue management integration
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct SessionStatusUpdate {
    pub oracle: ContractAddress,
    pub status: felt252,
    pub timestamp: u64,
    pub metadata: felt252, // Additional context data
    pub venue_info: felt252, // Venue management system data
    pub participant_count: u32,
    pub location_coordinates: (u64, u64), // GPS coordinates
    pub venue_capacity: u32,
    pub session_type: felt252, // rehearsal, audition, performance
    pub environmental_conditions: felt252 // weather, lighting, etc.
}

/// Credential verification through trusted identity providers
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct CredentialVerification {
    pub oracle: ContractAddress,
    pub provider: felt252,
    pub verified: bool,
    pub timestamp: u64,
    pub verification_level: u8, // 1-5 trust level
    pub credential_hash: felt252, // Hash of credential data
    pub expiry_timestamp: u64, // Credential expiration timestamp
    pub credential_type: felt252, // ID, education, experience, etc.
    pub issuer_signature: felt252, // Digital signature from issuer
    pub verification_method: felt252 // biometric, document, digital
}

/// Oracle metadata for reputation and reliability tracking
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct OracleMetadata {
    pub oracle_address: ContractAddress,
    pub reputation_score: u32, // 0-100 reputation score
    pub total_submissions: u64,
    pub accurate_submissions: u64,
    pub last_active: u64,
    pub stake_amount: u256, // Economic stake for data quality
    pub is_active: bool,
    pub specialization: felt252, // Oracle's area of expertise
    pub registration_timestamp: u64,
    pub slashing_count: u32, // Number of times slashed for bad data
    pub weighted_accuracy: u64 // Weighted accuracy based on submission difficulty
}

/// Data submission metrics for analytics and optimization
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct DataSubmissionMetrics {
    pub total_submissions: u64,
    pub consensus_reached: u64,
    pub conflicts_resolved: u64,
    pub data_expired: u64,
    pub average_consensus_time: u64,
    pub successful_validations: u64,
    pub failed_validations: u64,
    pub total_gas_used: u256,
    pub average_submission_size: u64,
}

/// Consensus mechanism data for conflict resolution
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ConsensusData {
    pub submission_count: u32,
    pub agreement_threshold: u32,
    pub final_value: felt252,
    pub confidence_score: u8,
    pub contributing_oracles: u32,
    pub variance_measure: u32,
    pub timestamp_finalized: u64,
}

/// Data expiration and lifecycle management
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct DataLifecycle {
    pub creation_timestamp: u64,
    pub expiry_timestamp: u64,
    pub access_count: u32,
    pub last_accessed: u64,
    pub data_type: felt252,
    pub priority_level: u8,
    pub auto_renewal: bool,
}

#[starknet::interface]
pub trait ISeasonAndAudition<TContractState> {
    // Core Season and Audition Management
    fn create_season(
        ref self: TContractState,
        season_id: felt252,
        name: felt252,
        start_timestamp: u64,
        end_timestamp: u64,
    );

    fn create_audition(
        ref self: TContractState,
        audition_id: felt252,
        season_id: felt252,
        name: felt252,
        genre: felt252,
        start_timestamp: u64,
        end_timestamp: u64,
    );

    fn submit_vote(
        ref self: TContractState, audition_id: felt252, performer_id: felt252, score: u32,
    );

    // Oracle Management with Enhanced Authorization
    fn authorize_oracle(ref self: TContractState, oracle: ContractAddress);
    fn deauthorize_oracle(ref self: TContractState, oracle: ContractAddress);
    fn update_oracle_reputation(
        ref self: TContractState, oracle: ContractAddress, new_reputation: u64,
    );
    fn slash_oracle(ref self: TContractState, oracle: ContractAddress, reason: felt252);
    fn stake_oracle(ref self: TContractState, amount: u256);
    fn unstake_oracle(ref self: TContractState);

    // Enhanced Oracle Data Submission Functions
    fn submit_performance_evaluation(
        ref self: TContractState,
        audition_id: felt252,
        performer_id: felt252,
        score: u32,
        comments: felt252,
        criteria_breakdown: felt252,
        confidence_level: u8,
    );

    fn submit_session_status_update(
        ref self: TContractState,
        session_id: felt252,
        status: felt252,
        metadata: felt252,
        venue_info: felt252,
        participant_count: u32,
    );

    fn submit_credential_verification(
        ref self: TContractState,
        user: ContractAddress,
        provider: felt252,
        verified: bool,
        verification_level: u8,
        credential_hash: felt252,
        expiry_timestamp: u64,
    );

    // Batch Operations for Gas Efficiency
    fn batch_submit_performance_evaluations(
        ref self: TContractState,
        audition_ids: Array<felt252>,
        performer_ids: Array<felt252>,
        scores: Array<u32>,
        comments: Array<felt252>,
        criteria_breakdowns: Array<felt252>,
        confidence_levels: Array<u8>,
    );

    fn batch_submit_session_updates(
        ref self: TContractState,
        session_ids: Array<felt252>,
        statuses: Array<felt252>,
        metadata: Array<felt252>,
        participant_counts: Array<u32>,
    );

    // Data Retrieval with Validation and Expiry Checks
    fn get_performance_evaluation(
        self: @TContractState, audition_id: felt252, performer_id: felt252,
    ) -> PerformanceEvaluation;

    fn get_session_status_update(self: @TContractState, session_id: felt252) -> SessionStatusUpdate;

    fn get_credential_verification(
        self: @TContractState, user: ContractAddress, provider: felt252,
    ) -> CredentialVerification;

    // Consensus and Conflict Resolution
    fn get_consensus_evaluation(
        self: @TContractState, audition_id: felt252, performer_id: felt252,
    ) -> PerformanceEvaluation;

    fn resolve_data_conflict(
        ref self: TContractState,
        data_type: felt252,
        identifier: felt252,
        resolution_method: felt252,
    );

    // Oracle Reputation and Analytics
    fn is_oracle_authorized(self: @TContractState, oracle: ContractAddress) -> bool;
    fn get_oracle_reputation(self: @TContractState, oracle: ContractAddress) -> u64;
    fn get_oracle_count(self: @TContractState) -> u64;
    fn get_total_submissions(self: @TContractState) -> u64;
    fn get_consensus_success_rate(self: @TContractState) -> (u64, u64);
    fn get_data_metrics(self: @TContractState) -> DataSubmissionMetrics;

    // Data Lifecycle Management
    fn update_consensus_threshold(ref self: TContractState, new_threshold: u32);
    fn update_data_lifetime(ref self: TContractState, new_lifetime_hours: u64);
    fn cleanup_expired_data(ref self: TContractState, data_type: felt252);
    fn extend_data_expiry(
        ref self: TContractState, data_type: felt252, identifier: felt252, extension_hours: u64,
    );

    // Core Data Access (maintaining compatibility)
    fn get_season(self: @TContractState, season_id: felt252) -> Season;
    fn get_audition(self: @TContractState, audition_id: felt252) -> Audition;
    fn get_vote(self: @TContractState, audition_id: felt252, performer_id: felt252) -> Vote;
}
