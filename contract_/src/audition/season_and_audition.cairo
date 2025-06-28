use starknet::ContractAddress;
use openzeppelin::access::ownable::OwnableComponent;
use starknet::{get_caller_address, get_block_timestamp};
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use super::lib::{
    Season, Audition, Vote, PerformanceEvaluation, SessionStatusUpdate, CredentialVerification,
    ISeasonAndAudition, OracleMetadata, DataSubmissionMetrics,
};

#[starknet::contract]
mod SeasonAndAudition {
    use super::{
        ContractAddress, OwnableComponent, get_caller_address, get_block_timestamp, Map, Season,
        Audition, Vote, PerformanceEvaluation, SessionStatusUpdate, CredentialVerification,
        ISeasonAndAudition, OracleMetadata, DataSubmissionMetrics, StorageMapReadAccess,
        StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::errors::errors;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        seasons: Map<felt252, Season>,
        auditions: Map<felt252, Audition>,
        votes: Map<(felt252, felt252), Vote>,
        authorized_oracles: Map<ContractAddress, bool>,
        oracle_metadata: Map<ContractAddress, OracleMetadata>,
        oracle_count: u64,
        performance_evaluations: Map<(felt252, felt252), PerformanceEvaluation>,
        session_status_updates: Map<felt252, SessionStatusUpdate>,
        credential_verifications: Map<(ContractAddress, felt252), CredentialVerification>,
        total_submissions: u64,
        consensus_threshold: u32,
        data_lifetime_hours: u64,
        consensus_success_count: u64,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        SeasonCreated: SeasonCreated,
        AuditionCreated: AuditionCreated,
        VoteSubmitted: VoteSubmitted,
        OracleAuthorized: OracleAuthorized,
        OracleDeauthorized: OracleDeauthorized,
        PerformanceEvaluationSubmitted: PerformanceEvaluationSubmitted,
        SessionStatusUpdated: SessionStatusUpdated,
        CredentialVerified: CredentialVerified,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct SeasonCreated {
        #[key]
        pub season_id: felt252,
        pub name: felt252,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct AuditionCreated {
        #[key]
        pub audition_id: felt252,
        pub season_id: felt252,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct VoteSubmitted {
        #[key]
        pub audition_id: felt252,
        #[key]
        pub performer_id: felt252,
        pub voter: ContractAddress,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct OracleAuthorized {
        #[key]
        pub oracle: ContractAddress,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct OracleDeauthorized {
        #[key]
        pub oracle: ContractAddress,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct PerformanceEvaluationSubmitted {
        #[key]
        pub audition_id: felt252,
        #[key]
        pub performer_id: felt252,
        pub oracle: ContractAddress,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct SessionStatusUpdated {
        #[key]
        pub session_id: felt252,
        pub oracle: ContractAddress,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct CredentialVerified {
        #[key]
        pub user: ContractAddress,
        pub oracle: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.consensus_threshold.write(3);
        self.oracle_count.write(0);
        self.total_submissions.write(0);
        self.data_lifetime_hours.write(168);
        self.consensus_success_count.write(0);
    }

    #[abi(embed_v0)]
    impl SeasonAndAuditionImpl of ISeasonAndAudition<ContractState> {
        fn create_season(
            ref self: ContractState,
            season_id: felt252,
            name: felt252,
            start_timestamp: u64,
            end_timestamp: u64,
        ) {
            self.ownable.assert_only_owner();
            let season = Season { name, start_timestamp, end_timestamp, paused: false };
            self.seasons.write(season_id, season);
            self.emit(Event::SeasonCreated(SeasonCreated { season_id, name }));
        }

        fn create_audition(
            ref self: ContractState,
            audition_id: felt252,
            season_id: felt252,
            name: felt252,
            genre: felt252,
            start_timestamp: u64,
            end_timestamp: u64,
        ) {
            self.ownable.assert_only_owner();
            let audition = Audition {
                season_id, genre, name, start_timestamp, end_timestamp, paused: false,
            };
            self.auditions.write(audition_id, audition);
            self.emit(Event::AuditionCreated(AuditionCreated { audition_id, season_id }));
        }

        fn submit_vote(
            ref self: ContractState, audition_id: felt252, performer_id: felt252, score: u32,
        ) {
            let caller = get_caller_address();
            assert(self.authorized_oracles.read(caller), errors::ORACLE_NOT_AUTHORIZED);
            assert(score <= 100, errors::INVALID_SCORE);
            let vote = Vote {
                audition_id,
                performer_id,
                voter_id: caller,
                score,
                timestamp: get_block_timestamp(),
            };
            self.votes.write((audition_id, performer_id), vote);
            self
                .emit(
                    Event::VoteSubmitted(
                        VoteSubmitted { audition_id, performer_id, voter: caller },
                    ),
                );
        }

        fn authorize_oracle(ref self: ContractState, oracle: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(!self.authorized_oracles.read(oracle), errors::ORACLE_ALREADY_AUTHORIZED);
            self.authorized_oracles.write(oracle, true);
            let count = self.oracle_count.read();
            self.oracle_count.write(count + 1);
            let metadata = OracleMetadata {
                oracle_address: oracle,
                reputation_score: 100,
                total_submissions: 0,
                accurate_submissions: 0,
                last_active: get_block_timestamp(),
                stake_amount: 0,
                is_active: true,
                specialization: 'general',
                registration_timestamp: get_block_timestamp(),
                slashing_count: 0,
                weighted_accuracy: 100,
            };
            self.oracle_metadata.write(oracle, metadata);
            self.emit(Event::OracleAuthorized(OracleAuthorized { oracle }));
        }

        fn deauthorize_oracle(ref self: ContractState, oracle: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(self.authorized_oracles.read(oracle), errors::ORACLE_NOT_AUTHORIZED);
            self.authorized_oracles.write(oracle, false);
            let count = self.oracle_count.read();
            if count > 0 {
                self.oracle_count.write(count - 1);
            }
            self.emit(Event::OracleDeauthorized(OracleDeauthorized { oracle }));
        }

        fn update_oracle_reputation(
            ref self: ContractState, oracle: ContractAddress, new_reputation: u64,
        ) {
            self.ownable.assert_only_owner();
            let mut metadata = self.oracle_metadata.read(oracle);
            metadata.reputation_score = new_reputation.try_into().unwrap_or(100);
            self.oracle_metadata.write(oracle, metadata);
        }

        fn slash_oracle(ref self: ContractState, oracle: ContractAddress, reason: felt252) {
            self.ownable.assert_only_owner();
            let mut metadata = self.oracle_metadata.read(oracle);
            metadata.slashing_count += 1;
            if metadata.reputation_score > 10 {
                metadata.reputation_score -= 10;
            } else {
                metadata.reputation_score = 0;
            }
            self.oracle_metadata.write(oracle, metadata);
        }

        fn stake_oracle(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            assert(self.authorized_oracles.read(caller), errors::ORACLE_NOT_AUTHORIZED);
            let mut metadata = self.oracle_metadata.read(caller);
            metadata.stake_amount += amount;
            self.oracle_metadata.write(caller, metadata);
        }

        fn unstake_oracle(ref self: ContractState) {
            let caller = get_caller_address();
            assert(self.authorized_oracles.read(caller), errors::ORACLE_NOT_AUTHORIZED);
            let mut metadata = self.oracle_metadata.read(caller);
            metadata.stake_amount = 0;
            self.oracle_metadata.write(caller, metadata);
        }

        fn submit_performance_evaluation(
            ref self: ContractState,
            audition_id: felt252,
            performer_id: felt252,
            score: u32,
            comments: felt252,
            criteria_breakdown: felt252,
            confidence_level: u8,
        ) {
            let caller = get_caller_address();
            assert(self.authorized_oracles.read(caller), errors::ORACLE_NOT_AUTHORIZED);
            assert(score <= 100, errors::INVALID_SCORE);
            assert(confidence_level <= 100, errors::INVALID_CONFIDENCE);
            let evaluation = PerformanceEvaluation {
                oracle: caller,
                score,
                comments,
                timestamp: get_block_timestamp(),
                submission_hash: 0,
                criteria_breakdown,
                confidence_level,
                technical_score: score,
                artistic_score: score,
                stage_presence: score,
                originality: score,
                overall_impression: score,
            };
            self.performance_evaluations.write((audition_id, performer_id), evaluation);
            let total = self.total_submissions.read();
            self.total_submissions.write(total + 1);
            self
                .emit(
                    Event::PerformanceEvaluationSubmitted(
                        PerformanceEvaluationSubmitted {
                            audition_id, performer_id, oracle: caller,
                        },
                    ),
                );
        }

        fn submit_session_status_update(
            ref self: ContractState,
            session_id: felt252,
            status: felt252,
            metadata: felt252,
            venue_info: felt252,
            participant_count: u32,
        ) {
            let caller = get_caller_address();
            assert(self.authorized_oracles.read(caller), errors::ORACLE_NOT_AUTHORIZED);
            let status_update = SessionStatusUpdate {
                oracle: caller,
                status,
                timestamp: get_block_timestamp(),
                metadata,
                venue_info,
                participant_count,
                location_coordinates: (0, 0),
                venue_capacity: 1000,
                session_type: 'audition',
                environmental_conditions: 'normal',
            };
            self.session_status_updates.write(session_id, status_update);
            self
                .emit(
                    Event::SessionStatusUpdated(
                        SessionStatusUpdated { session_id, oracle: caller },
                    ),
                );
        }

        fn submit_credential_verification(
            ref self: ContractState,
            user: ContractAddress,
            provider: felt252,
            verified: bool,
            verification_level: u8,
            credential_hash: felt252,
            expiry_timestamp: u64,
        ) {
            let caller = get_caller_address();
            assert(self.authorized_oracles.read(caller), errors::ORACLE_NOT_AUTHORIZED);
            assert(verification_level <= 5, errors::INVALID_VERIFICATION_LEVEL);
            let verification = CredentialVerification {
                oracle: caller,
                provider,
                verified,
                timestamp: get_block_timestamp(),
                verification_level,
                credential_hash,
                expiry_timestamp,
                credential_type: 'identity',
                issuer_signature: 0,
                verification_method: 'digital',
            };
            self.credential_verifications.write((user, provider), verification);
            self.emit(Event::CredentialVerified(CredentialVerified { user, oracle: caller }));
        }

        fn batch_submit_performance_evaluations(
            ref self: ContractState,
            audition_ids: Array<felt252>,
            performer_ids: Array<felt252>,
            scores: Array<u32>,
            comments: Array<felt252>,
            criteria_breakdowns: Array<felt252>,
            confidence_levels: Array<u8>,
        ) {
            let caller = get_caller_address();
            assert(self.authorized_oracles.read(caller), errors::ORACLE_NOT_AUTHORIZED);
            assert(audition_ids.len() == performer_ids.len(), errors::ARRAYS_LENGTH_MISMATCH);
            let mut i = 0;
            loop {
                if i >= audition_ids.len() {
                    break;
                }
                let evaluation = PerformanceEvaluation {
                    oracle: caller,
                    score: *scores.at(i),
                    comments: *comments.at(i),
                    timestamp: get_block_timestamp(),
                    submission_hash: 0,
                    criteria_breakdown: *criteria_breakdowns.at(i),
                    confidence_level: *confidence_levels.at(i),
                    technical_score: *scores.at(i),
                    artistic_score: *scores.at(i),
                    stage_presence: *scores.at(i),
                    originality: *scores.at(i),
                    overall_impression: *scores.at(i),
                };
                self
                    .performance_evaluations
                    .write((*audition_ids.at(i), *performer_ids.at(i)), evaluation);
                i += 1;
            };
        }

        fn batch_submit_session_updates(
            ref self: ContractState,
            session_ids: Array<felt252>,
            statuses: Array<felt252>,
            metadata: Array<felt252>,
            participant_counts: Array<u32>,
        ) {
            let caller = get_caller_address();
            assert(self.authorized_oracles.read(caller), errors::ORACLE_NOT_AUTHORIZED);
            assert(session_ids.len() == statuses.len(), errors::ARRAYS_LENGTH_MISMATCH);
            let mut i = 0;
            loop {
                if i >= session_ids.len() {
                    break;
                }
                let status_update = SessionStatusUpdate {
                    oracle: caller,
                    status: *statuses.at(i),
                    timestamp: get_block_timestamp(),
                    metadata: *metadata.at(i),
                    venue_info: 0,
                    participant_count: *participant_counts.at(i),
                    location_coordinates: (0, 0),
                    venue_capacity: 1000,
                    session_type: 'audition',
                    environmental_conditions: 'normal',
                };
                self.session_status_updates.write(*session_ids.at(i), status_update);
                i += 1;
            };
        }

        fn get_performance_evaluation(
            self: @ContractState, audition_id: felt252, performer_id: felt252,
        ) -> PerformanceEvaluation {
            self.performance_evaluations.read((audition_id, performer_id))
        }

        fn get_session_status_update(
            self: @ContractState, session_id: felt252,
        ) -> SessionStatusUpdate {
            self.session_status_updates.read(session_id)
        }

        fn get_credential_verification(
            self: @ContractState, user: ContractAddress, provider: felt252,
        ) -> CredentialVerification {
            self.credential_verifications.read((user, provider))
        }

        fn get_consensus_evaluation(
            self: @ContractState, audition_id: felt252, performer_id: felt252,
        ) -> PerformanceEvaluation {
            self.performance_evaluations.read((audition_id, performer_id))
        }

        fn resolve_data_conflict(
            ref self: ContractState,
            data_type: felt252,
            identifier: felt252,
            resolution_method: felt252,
        ) {
            self.ownable.assert_only_owner();
            let success = self.consensus_success_count.read();
            self.consensus_success_count.write(success + 1);
        }

        fn is_oracle_authorized(self: @ContractState, oracle: ContractAddress) -> bool {
            self.authorized_oracles.read(oracle)
        }

        fn get_oracle_reputation(self: @ContractState, oracle: ContractAddress) -> u64 {
            let metadata = self.oracle_metadata.read(oracle);
            metadata.reputation_score.into()
        }

        fn get_oracle_count(self: @ContractState) -> u64 {
            self.oracle_count.read()
        }

        fn get_total_submissions(self: @ContractState) -> u64 {
            self.total_submissions.read()
        }

        fn get_consensus_success_rate(self: @ContractState) -> (u64, u64) {
            let total = self.total_submissions.read();
            let success = self.consensus_success_count.read();
            (success, total)
        }

        fn get_data_metrics(self: @ContractState) -> DataSubmissionMetrics {
            DataSubmissionMetrics {
                total_submissions: self.total_submissions.read(),
                consensus_reached: self.consensus_success_count.read(),
                conflicts_resolved: 0,
                data_expired: 0,
                average_consensus_time: 0,
                successful_validations: self.consensus_success_count.read(),
                failed_validations: 0,
                total_gas_used: 0,
                average_submission_size: 0,
            }
        }

        fn update_consensus_threshold(ref self: ContractState, new_threshold: u32) {
            self.ownable.assert_only_owner();
            self.consensus_threshold.write(new_threshold);
        }

        fn update_data_lifetime(ref self: ContractState, new_lifetime_hours: u64) {
            self.ownable.assert_only_owner();
            self.data_lifetime_hours.write(new_lifetime_hours);
        }

        fn cleanup_expired_data(ref self: ContractState, data_type: felt252) {
            self.ownable.assert_only_owner();
        }

        fn extend_data_expiry(
            ref self: ContractState, data_type: felt252, identifier: felt252, extension_hours: u64,
        ) {
            self.ownable.assert_only_owner();
        }

        fn get_season(self: @ContractState, season_id: felt252) -> Season {
            self.seasons.read(season_id)
        }

        fn get_audition(self: @ContractState, audition_id: felt252) -> Audition {
            self.auditions.read(audition_id)
        }

        fn get_vote(self: @ContractState, audition_id: felt252, performer_id: felt252) -> Vote {
            self.votes.read((audition_id, performer_id))
        }
    }
}
