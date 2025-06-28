use starknet::ContractAddress;
use starknet::{get_caller_address, get_block_timestamp, contract_address_const};
use core::option::OptionTrait;
use super::lib::{
    PerformanceEvaluation, SessionStatusUpdate, CredentialVerification, OracleMetadata,
};
use core::pedersen::pedersen;

/// Helper functions for the Oracle Data Submission System
/// These functions provide validation, consensus checking, and internal operations

pub trait HelperFunctions<TContractState> {
    // Validation Functions
    fn validate_submission_data(
        self: @TContractState,
        score: Option<u32>,
        confidence_level: Option<u8>,
        verification_level: Option<u8>,
    ) -> bool;

    fn assert_oracle_authorized(self: @TContractState, oracle: ContractAddress);

    fn validate_score_range(self: @TContractState, score: u32) -> bool;

    fn validate_confidence_level(self: @TContractState, confidence: u8) -> bool;

    fn validate_verification_level(self: @TContractState, level: u8) -> bool;

    // Performance Evaluation Helpers
    fn _validate_performance_evaluation(self: @TContractState, eval: PerformanceEvaluation) -> bool;

    fn _process_single_performance_evaluation(
        ref self: TContractState, eval: PerformanceEvaluation,
    );

    fn _check_performance_consensus(
        ref self: TContractState, audition_id: felt252, performer_id: felt252,
    );

    // Session Update Helpers
    fn _validate_session_update(self: @TContractState, update: SessionStatusUpdate) -> bool;

    fn _process_single_session_update(ref self: TContractState, update: SessionStatusUpdate);

    fn _check_session_consensus(ref self: TContractState, session_id: felt252);

    // Credential Verification Helpers
    fn _validate_credential_verification(
        self: @TContractState, verification: CredentialVerification,
    ) -> bool;

    fn _process_single_credential_verification(
        ref self: TContractState, verification: CredentialVerification,
    );

    fn _check_credential_consensus(ref self: TContractState, participant_id: felt252);

    // Oracle Management Helpers
    fn update_oracle_reputation_internal(
        ref self: TContractState, oracle: ContractAddress, success: bool,
    );

    fn calculate_consensus_score(self: @TContractState, scores: Array<u32>) -> u32;

    fn calculate_weighted_consensus(
        self: @TContractState, scores: Array<u32>, weights: Array<u32>,
    ) -> u32;

    // Metrics and Analytics Helpers
    fn update_metrics(ref self: TContractState, operation_type: felt252);

    fn increment_submission_count(ref self: TContractState);

    fn increment_consensus_count(ref self: TContractState);

    // Data Integrity Helpers
    fn generate_submission_hash(
        self: @TContractState,
        audition_id: felt252,
        performer_id: felt252,
        score: u32,
        timestamp: u64,
    ) -> felt252;

    fn verify_data_integrity(
        self: @TContractState, data_hash: felt252, expected_hash: felt252,
    ) -> bool;

    // Time and Expiry Helpers
    fn is_data_valid_by_timestamp(self: @TContractState, timestamp: u64) -> bool;

    fn calculate_data_expiry(self: @TContractState, base_timestamp: u64) -> u64;

    // Error Handling Helpers
    fn handle_validation_error(ref self: TContractState, error_type: felt252, details: felt252);

    fn log_oracle_activity(
        ref self: TContractState, oracle: ContractAddress, activity_type: felt252,
    );
}

/// Constants for validation and thresholds
pub mod validation_constants {
    pub const MAX_SCORE: u32 = 100;
    pub const MIN_SCORE: u32 = 0;
    pub const MAX_CONFIDENCE_LEVEL: u8 = 100;
    pub const MIN_CONFIDENCE_LEVEL: u8 = 1;
    pub const MAX_VERIFICATION_LEVEL: u8 = 5;
    pub const MIN_VERIFICATION_LEVEL: u8 = 1;
    pub const ORACLE_DATA_EXPIRY: u64 = 86400; // 24 hours in seconds
    pub const MIN_CONSENSUS_ORACLES: u32 = 2;
    pub const REPUTATION_PENALTY: u32 = 5;
    pub const REPUTATION_REWARD: u32 = 1;
    pub const CONSENSUS_THRESHOLD: u32 = 51; // 51% agreement for consensus
}

/// Error handling constants
pub mod helper_errors {
    pub const INVALID_SCORE_RANGE: felt252 = 'Score must be 0-100';
    pub const INVALID_CONFIDENCE: felt252 = 'Confidence must be 1-100';
    pub const INVALID_VERIFICATION_LEVEL: felt252 = 'Verification level 1-5';
    pub const ORACLE_NOT_AUTHORIZED: felt252 = 'Oracle not authorized';
    pub const DATA_INTEGRITY_FAILED: felt252 = 'Data integrity check failed';
    pub const INSUFFICIENT_CONSENSUS: felt252 = 'Insufficient consensus data';
    pub const TIMESTAMP_TOO_OLD: felt252 = 'Data timestamp too old';
    pub const HASH_VERIFICATION_FAILED: felt252 = 'Hash verification failed';
}

/// Utility functions for common operations
pub mod helper_utils {
    use core::array::ArrayTrait;
    use core::option::OptionTrait;

    /// Calculate the median of an array of scores
    pub fn calculate_median(mut scores: Array<u32>) -> u32 {
        let len = scores.len();
        if len == 0 {
            return 0;
        }

        // Simple bubble sort for small arrays
        let mut i = 0;
        while i < len - 1 {
            let mut j = 0;
            while j < len - 1 - i {
                if *scores.at(j) > *scores.at(j + 1) { // Swap elements (simplified representation)
                // In real implementation, would need proper swap
                }
                j += 1;
            };
            i += 1;
        };

        if len % 2 == 0 {
            (*scores.at(len / 2 - 1) + *scores.at(len / 2)) / 2
        } else {
            *scores.at(len / 2)
        }
    }

    /// Calculate weighted average
    pub fn calculate_weighted_average(scores: Array<u32>, weights: Array<u32>) -> u32 {
        if scores.len() != weights.len() || scores.len() == 0 {
            return 0;
        }

        let mut weighted_sum: u32 = 0;
        let mut total_weight: u32 = 0;
        let mut i = 0;

        while i < scores.len() {
            weighted_sum += *scores.at(i) * *weights.at(i);
            total_weight += *weights.at(i);
            i += 1;
        };

        if total_weight == 0 {
            return 0;
        }

        weighted_sum / total_weight
    }

    /// Check if majority consensus is reached
    pub fn is_majority_consensus(agreements: u32, total: u32, threshold_percent: u32) -> bool {
        if total == 0 {
            return false;
        }

        let agreement_percent = (agreements * 100) / total;
        agreement_percent >= threshold_percent
    }

    /// Generate a simple hash for data integrity
    pub fn generate_simple_hash(data1: felt252, data2: felt252, data3: u64) -> felt252 {
        // Simplified hash - in production would use proper cryptographic hash
        data1 + data2 + data3.into()
    }

    /// Validate timestamp is within acceptable range
    pub fn is_timestamp_valid(timestamp: u64, current_time: u64, max_age: u64) -> bool {
        if timestamp > current_time {
            return false; // Future timestamp not allowed
        }

        (current_time - timestamp) <= max_age
    }
}

/// Event emission helpers
pub mod event_helpers {
    use starknet::ContractAddress;

    pub struct ValidationFailure {
        pub oracle: ContractAddress,
        pub reason: felt252,
        pub data_type: felt252,
        pub timestamp: u64,
    }

    pub struct ConsensusUpdate {
        pub data_type: felt252,
        pub identifier: felt252,
        pub previous_consensus: felt252,
        pub new_consensus: felt252,
        pub participating_oracles: u32,
        pub timestamp: u64,
    }

    pub struct ReputationChange {
        pub oracle: ContractAddress,
        pub old_score: u32,
        pub new_score: u32,
        pub reason: felt252,
        pub timestamp: u64,
    }
}

/// Helper functions for oracle data validation and consensus mechanisms
pub mod oracle_helpers {
    use super::{ContractAddress, get_caller_address, get_block_timestamp};
    use super::{PerformanceEvaluation, SessionStatusUpdate, CredentialVerification, OracleMetadata};

    /// Validates a performance evaluation submission
    pub fn validate_performance_evaluation(evaluation: @PerformanceEvaluation) -> bool {
        let timestamp = get_block_timestamp();
        let oracle = *evaluation.oracle;

        // Basic validation checks
        if oracle.is_zero() {
            return false;
        }
        if *evaluation.score > 100 {
            return false;
        }
        if *evaluation.confidence_level > 100 {
            return false;
        }
        if *evaluation.timestamp > timestamp {
            return false;
        }

        true
    }

    /// Validates a session status update submission
    pub fn validate_session_status_update(update: @SessionStatusUpdate) -> bool {
        let timestamp = get_block_timestamp();
        let oracle = *update.oracle;

        // Basic validation checks
        if oracle.is_zero() {
            return false;
        }
        if *update.timestamp > timestamp {
            return false;
        }
        if *update.participant_count > 10000 {
            return false;
        } // reasonable max

        true
    }

    /// Validates a credential verification submission
    pub fn validate_credential_verification(verification: @CredentialVerification) -> bool {
        let timestamp = get_block_timestamp();
        let oracle = *verification.oracle;

        // Basic validation checks
        if oracle.is_zero() {
            return false;
        }
        if *verification.timestamp > timestamp {
            return false;
        }
        if *verification.verification_level > 5 {
            return false;
        }
        if *verification.expiry_timestamp <= timestamp {
            return false;
        }

        true
    }

    /// Calculates consensus from multiple performance evaluations
    pub fn calculate_performance_consensus(evaluations: Array<PerformanceEvaluation>) -> (u32, u8) {
        if evaluations.len() == 0 {
            return (0, 0);
        }

        let mut total_score: u32 = 0;
        let mut total_confidence: u64 = 0;
        let mut count: u32 = 0;

        let mut i = 0;
        loop {
            if i >= evaluations.len() {
                break;
            }
            let evaluation = evaluations.at(i);
            total_score += *evaluation.score;
            total_confidence += (*evaluation.confidence_level).into();
            count += 1;
            i += 1;
        };

        let consensus_score = total_score / count;
        let consensus_confidence = (total_confidence / count.into()).try_into().unwrap_or(0);

        (consensus_score, consensus_confidence)
    }

    /// Checks if there's significant variance between oracle submissions
    pub fn check_variance(evaluations: Array<PerformanceEvaluation>, threshold: u32) -> bool {
        if evaluations.len() < 2 {
            return false;
        }

        let mut min_score: u32 = 100;
        let mut max_score: u32 = 0;

        let mut i = 0;
        loop {
            if i >= evaluations.len() {
                break;
            }
            let evaluation = evaluations.at(i);
            let score = *evaluation.score;

            if score < min_score {
                min_score = score;
            }
            if score > max_score {
                max_score = score;
            }
            i += 1;
        };

        (max_score - min_score) > threshold
    }

    /// Updates oracle reputation based on consensus participation
    pub fn calculate_reputation_update(
        current_reputation: u64, contributed_to_consensus: bool, was_outlier: bool,
    ) -> u64 {
        let mut new_reputation = current_reputation;

        if contributed_to_consensus && !was_outlier {
            // Increase reputation for good submissions
            new_reputation += 1;
            if new_reputation > 100 {
                new_reputation = 100;
            }
        } else if was_outlier {
            // Decrease reputation for outlier submissions
            if new_reputation > 2 {
                new_reputation -= 2;
            } else {
                new_reputation = 0;
            }
        }

        new_reputation
    }

    /// Generates a submission hash for integrity verification
    pub fn generate_submission_hash(
        oracle: ContractAddress, timestamp: u64, data_hash: felt252,
    ) -> felt252 {
        let mut hash_input = array![oracle.into(), timestamp.into(), data_hash];
        let hash = core::poseidon::poseidon_hash_span(hash_input.span());
        hash
    }

    /// Validates timestamp within tolerance
    pub fn validate_timestamp(submitted_timestamp: u64, tolerance: u64) -> bool {
        let current_timestamp = get_block_timestamp();
        let min_time = current_timestamp - tolerance;
        let max_time = current_timestamp + tolerance;

        submitted_timestamp >= min_time && submitted_timestamp <= max_time
    }

    /// Checks if oracle is within cooldown period
    pub fn check_oracle_cooldown(last_submission: u64, cooldown_period: u64) -> bool {
        let current_timestamp = get_block_timestamp();
        (current_timestamp - last_submission) >= cooldown_period
    }

    /// Validates batch submission limits
    pub fn validate_batch_size(batch_size: u32, max_batch_size: u32) -> bool {
        batch_size > 0 && batch_size <= max_batch_size
    }

    /// Estimates gas cost for operations
    pub fn estimate_gas_cost(operation_type: felt252, data_size: u32) -> u256 {
        // Basic gas estimation - would be more sophisticated in production
        match operation_type {
            'performance_eval' => 50000_u256 + (data_size.into() * 100_u256),
            'session_update' => 30000_u256 + (data_size.into() * 80_u256),
            'credential_verify' => 40000_u256 + (data_size.into() * 90_u256),
            _ => 25000_u256,
        }
    }
}
