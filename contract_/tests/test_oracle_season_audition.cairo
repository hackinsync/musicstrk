#[cfg(test)]
mod tests {
    use starknet::ContractAddress;

    use snforge_std::{
        declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
        stop_cheat_caller_address,
    };

    use contract_::audition::lib::{ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait};

    // Test constants
    fn OWNER() -> ContractAddress {
        starknet::contract_address_const::<0x123>()
    }

    fn ORACLE1() -> ContractAddress {
        starknet::contract_address_const::<0x456>()
    }

    fn ORACLE2() -> ContractAddress {
        starknet::contract_address_const::<0x789>()
    }

    fn ORACLE3() -> ContractAddress {
        starknet::contract_address_const::<0xabc>()
    }

    fn USER() -> ContractAddress {
        starknet::contract_address_const::<0xdef>()
    }

    // Deploy contract helper
    fn deploy_contract() -> ISeasonAndAuditionDispatcher {
        let contract = declare("SeasonAndAudition").unwrap().contract_class();
        let constructor_calldata = array![OWNER().into()];
        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        ISeasonAndAuditionDispatcher { contract_address }
    }

    // Setup helper: Deploy contract and authorize an oracle
    fn setup_with_oracle() -> (ISeasonAndAuditionDispatcher, ContractAddress) {
        let contract = deploy_contract();
        let oracle = ORACLE1();

        start_cheat_caller_address(contract.contract_address, OWNER());
        contract.authorize_oracle(oracle);
        stop_cheat_caller_address(contract.contract_address);

        (contract, oracle)
    }

    #[test]
    fn test_contract_deployment() {
        let contract = deploy_contract();

        // Test basic deployment
        assert!(contract.get_oracle_count() == 0, "Initial oracle count should be 0");
        let (_successful, _total) = contract.get_consensus_success_rate();
        assert!(contract.get_total_submissions() == 0, "Initial submissions should be 0");
    }

    #[test]
    fn test_oracle_authorization() {
        let contract = deploy_contract();
        let oracle = ORACLE1();

        // Initially oracle should not be authorized
        assert!(
            !contract.is_oracle_authorized(oracle), "Oracle should not be initially authorized",
        );

        // Authorize oracle as owner
        start_cheat_caller_address(contract.contract_address, OWNER());
        contract.authorize_oracle(oracle);

        // Verify oracle is authorized
        assert!(contract.is_oracle_authorized(oracle), "Oracle should be authorized");
        assert!(contract.get_oracle_count() == 1, "Oracle count should be 1");

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_oracle_deauthorization() {
        let (contract, oracle) = setup_with_oracle();

        // Deauthorize oracle as owner
        start_cheat_caller_address(contract.contract_address, OWNER());
        contract.deauthorize_oracle(oracle);

        // Verify oracle is deauthorized
        assert!(!contract.is_oracle_authorized(oracle), "Oracle should be deauthorized");
        assert!(contract.get_oracle_count() == 0, "Oracle count should be 0");

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Oracle not authorized')]
    fn test_unauthorized_oracle_submission() {
        let contract = deploy_contract();
        let unauthorized_oracle = ORACLE1();

        // Try to submit performance evaluation without authorization
        start_cheat_caller_address(contract.contract_address, unauthorized_oracle);
        contract
            .submit_performance_evaluation(
                1, // audition_id
                1, // performer_id
                85, // score
                'Great performance', // comments
                'criteria_breakdown', // criteria_breakdown
                90 // confidence_level
            );
    }

    #[test]
    fn test_season_creation() {
        let contract = deploy_contract();

        let season_id = 1;
        let season_name = 'Summer_Season';
        let start_time = 1672531200;
        let end_time = 1675123200;

        // Create season as owner
        start_cheat_caller_address(contract.contract_address, OWNER());
        contract.create_season(season_id, season_name, start_time, end_time);

        // Verify season was created
        let season = contract.get_season(season_id);
        assert!(season.name == season_name, "Season name should match");
        assert!(season.start_timestamp == start_time, "Start timestamp should match");
        assert!(season.end_timestamp == end_time, "End timestamp should match");
        assert!(!season.paused, "Season should not be paused");

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_audition_creation() {
        let contract = deploy_contract();

        let season_id = 1;
        let audition_id = 1;
        let audition_name = 'Live_Audition';
        let genre = 'Pop';
        let start_time = 1672531200;
        let end_time = 1675123200;

        // Create audition as owner
        start_cheat_caller_address(contract.contract_address, OWNER());
        contract
            .create_audition(audition_id, season_id, audition_name, genre, start_time, end_time);

        // Verify audition was created
        let audition = contract.get_audition(audition_id);
        assert!(audition.name == audition_name, "Audition name should match");
        assert!(audition.season_id == season_id, "Season ID should match");
        assert!(audition.genre == genre, "Genre should match");
        assert!(audition.start_timestamp == start_time, "Start timestamp should match");
        assert!(audition.end_timestamp == end_time, "End timestamp should match");
        assert!(!audition.paused, "Audition should not be paused");

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_vote_submission() {
        let (contract, oracle) = setup_with_oracle();

        let audition_id = 1;
        let performer_id = 1;
        let score = 85;

        // Submit vote as authorized oracle
        start_cheat_caller_address(contract.contract_address, oracle);
        contract.submit_vote(audition_id, performer_id, score);

        // Verify vote was submitted
        let vote = contract.get_vote(audition_id, performer_id);
        assert!(vote.audition_id == audition_id, "Audition ID should match");
        assert!(vote.performer_id == performer_id, "Performer ID should match");
        assert!(vote.voter_id == oracle, "Voter ID should match oracle");
        assert!(vote.score == score, "Score should match");

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_performance_evaluation_submission() {
        let (contract, oracle) = setup_with_oracle();

        let audition_id = 1;
        let performer_id = 1;
        let score = 88;
        let comments = 'excellent';
        let criteria = 'vocals_good';
        let confidence = 95;

        // Submit performance evaluation as authorized oracle
        start_cheat_caller_address(contract.contract_address, oracle);
        contract
            .submit_performance_evaluation(
                audition_id, performer_id, score, comments, criteria, confidence,
            );

        // Verify evaluation was stored
        let evaluation = contract.get_performance_evaluation(audition_id, performer_id);
        assert!(evaluation.oracle == oracle, "Oracle address should match");
        assert!(evaluation.score == score, "Score should match");
        assert!(evaluation.comments == comments, "Comments should match");
        assert!(evaluation.confidence_level == confidence, "Confidence level should match");

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_session_status_update() {
        let (contract, oracle) = setup_with_oracle();

        let session_id = 1;
        let status = 'ACTIVE';
        let metadata = 'session_data';
        let venue_info = 'venue_details';
        let participant_count = 42;

        // Submit session status update as authorized oracle
        start_cheat_caller_address(contract.contract_address, oracle);
        contract
            .submit_session_status_update(
                session_id, status, metadata, venue_info, participant_count,
            );

        // Verify session update was stored
        let session_update = contract.get_session_status_update(session_id);
        assert!(session_update.oracle == oracle, "Oracle address should match");
        assert!(session_update.status == status, "Status should match");
        assert!(session_update.metadata == metadata, "Metadata should match");
        assert!(
            session_update.participant_count == participant_count, "Participant count should match",
        );

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_credential_verification() {
        let (contract, oracle) = setup_with_oracle();

        let user = USER();
        let provider = 'ID_PROVIDER';
        let verified = true;
        let verification_level = 4;
        let credential_hash = 'hash_123';
        let expiry_timestamp = 1700000000;

        // Submit credential verification as authorized oracle
        start_cheat_caller_address(contract.contract_address, oracle);
        contract
            .submit_credential_verification(
                user, provider, verified, verification_level, credential_hash, expiry_timestamp,
            );

        // Verify credential verification was stored
        let verification = contract.get_credential_verification(user, provider);
        assert!(verification.oracle == oracle, "Oracle address should match");
        assert!(verification.provider == provider, "Provider should match");
        assert!(verification.verified == verified, "Verified status should match");
        assert!(
            verification.verification_level == verification_level,
            "Verification level should match",
        );

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_batch_performance_evaluations() {
        let (contract, oracle) = setup_with_oracle();

        let audition_ids = array![1, 2, 3];
        let performer_ids = array![1, 2, 3];
        let scores = array![85, 90, 88];
        let comments = array!['good', 'excellent', 'very_good'];
        let criteria_breakdowns = array!['criteria1', 'criteria2', 'criteria3'];
        let confidence_levels = array![90, 95, 88];

        // Submit batch performance evaluations as authorized oracle
        start_cheat_caller_address(contract.contract_address, oracle);
        contract
            .batch_submit_performance_evaluations(
                audition_ids,
                performer_ids,
                scores,
                comments,
                criteria_breakdowns,
                confidence_levels,
            );

        // Verify first evaluation was stored
        let evaluation = contract.get_performance_evaluation(1, 1);
        assert!(evaluation.oracle == oracle, "Oracle address should match");
        assert!(evaluation.score == 85, "Score should match");

        // Verify second evaluation was stored
        let evaluation2 = contract.get_performance_evaluation(2, 2);
        assert!(evaluation2.score == 90, "Second score should match");

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_batch_session_updates() {
        let (contract, oracle) = setup_with_oracle();

        let session_ids = array![1, 2, 3];
        let statuses = array!['ACTIVE', 'PAUSED', 'ENDED'];
        let metadata = array!['meta1', 'meta2', 'meta3'];
        let participant_counts = array![10, 20, 30];

        // Submit batch session updates as authorized oracle
        start_cheat_caller_address(contract.contract_address, oracle);
        contract.batch_submit_session_updates(session_ids, statuses, metadata, participant_counts);

        // Verify first session update was stored
        let session1 = contract.get_session_status_update(1);
        assert!(session1.oracle == oracle, "Oracle address should match");
        assert!(session1.status == 'ACTIVE', "First status should match");

        // Verify second session update was stored
        let session2 = contract.get_session_status_update(2);
        assert!(session2.status == 'PAUSED', "Second status should match");

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_oracle_reputation_management() {
        let (contract, oracle) = setup_with_oracle();

        // Check initial reputation (should be 100)
        let initial_reputation = contract.get_oracle_reputation(oracle);
        assert!(initial_reputation == 100, "Initial reputation should be 100");

        // Update reputation as owner
        start_cheat_caller_address(contract.contract_address, OWNER());
        let new_reputation = 95;
        contract.update_oracle_reputation(oracle, new_reputation);

        // Verify reputation was updated
        let updated_reputation = contract.get_oracle_reputation(oracle);
        assert!(updated_reputation == new_reputation, "Reputation should be updated");

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_oracle_slashing() {
        let (contract, oracle) = setup_with_oracle();

        let reason = 'bad_data_submitted';

        // Get initial reputation
        let initial_reputation = contract.get_oracle_reputation(oracle);

        // Slash oracle as owner
        start_cheat_caller_address(contract.contract_address, OWNER());
        contract.slash_oracle(oracle, reason);

        // Verify reputation was reduced after slashing
        let new_reputation = contract.get_oracle_reputation(oracle);
        assert!(new_reputation < initial_reputation, "Reputation should be reduced after slashing");

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_oracle_staking() {
        let (contract, oracle) = setup_with_oracle();

        let stake_amount = 1000_u256;

        // Stake as oracle
        start_cheat_caller_address(contract.contract_address, oracle);
        contract.stake_oracle(stake_amount);

        // Unstake
        contract.unstake_oracle();

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_multiple_oracle_system() {
        let contract = deploy_contract();
        let oracle1 = ORACLE1();
        let oracle2 = ORACLE2();
        let oracle3 = ORACLE3();

        // Authorize multiple oracles as owner
        start_cheat_caller_address(contract.contract_address, OWNER());
        contract.authorize_oracle(oracle1);
        contract.authorize_oracle(oracle2);
        contract.authorize_oracle(oracle3);
        stop_cheat_caller_address(contract.contract_address);

        // Verify oracle count
        assert!(contract.get_oracle_count() == 3, "Should have 3 authorized oracles");

        let audition_id = 1;
        let performer_id = 1;

        // Submit evaluations from different oracles
        start_cheat_caller_address(contract.contract_address, oracle1);
        contract
            .submit_performance_evaluation(audition_id, performer_id, 85, 'good', 'criteria1', 90);
        stop_cheat_caller_address(contract.contract_address);

        start_cheat_caller_address(contract.contract_address, oracle2);
        contract
            .submit_performance_evaluation(audition_id, performer_id, 87, 'good', 'criteria2', 85);
        stop_cheat_caller_address(contract.contract_address);

        start_cheat_caller_address(contract.contract_address, oracle3);
        contract
            .submit_performance_evaluation(audition_id, performer_id, 86, 'good', 'criteria3', 88);
        stop_cheat_caller_address(contract.contract_address);

        // Get consensus evaluation (last submission overwrites)
        let consensus = contract.get_consensus_evaluation(audition_id, performer_id);
        assert!(consensus.score == 86, "Consensus should have the last score");
    }

    #[test]
    fn test_data_metrics_and_analytics() {
        let (contract, oracle) = setup_with_oracle();

        // Submit some data to generate metrics
        start_cheat_caller_address(contract.contract_address, oracle);
        contract.submit_performance_evaluation(1, 1, 85, 'good', 'criteria', 90);
        contract.submit_session_status_update(1, 'ACTIVE', 'metadata', 'venue', 50);
        stop_cheat_caller_address(contract.contract_address);

        // Check metrics
        let metrics = contract.get_data_metrics();
        assert!(metrics.total_submissions > 0, "Should have submissions");

        // Check consensus success rate
        let (successful, total) = contract.get_consensus_success_rate();
        assert!(total > 0, "Should have total submissions");
    }

    #[test]
    fn test_data_lifecycle_management() {
        let contract = deploy_contract();

        // Test data lifecycle management as owner
        start_cheat_caller_address(contract.contract_address, OWNER());

        contract.update_consensus_threshold(5);
        contract.update_data_lifetime(72);
        contract.cleanup_expired_data('PERFORMANCE_EVAL');
        contract.extend_data_expiry('SESSION_STATUS', 'session_1', 48);
        contract.resolve_data_conflict('CREDENTIAL_VERIFY', 'conflict_1', 'MAJORITY');

        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: 'Invalid confidence level')]
    fn test_invalid_confidence_rejection() {
        let (contract, oracle) = setup_with_oracle();

        start_cheat_caller_address(contract.contract_address, oracle);
        contract
            .submit_performance_evaluation(
                1,
                1,
                85,
                'Great performance',
                'criteria_breakdown',
                101 // Invalid confidence level > 100
            );
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: 'Arrays length mismatch')]
    fn test_batch_arrays_length_mismatch() {
        let (contract, oracle) = setup_with_oracle();

        let audition_ids = array![1, 2];
        let performer_ids = array![1]; // Mismatched length
        let scores = array![85];
        let comments = array!['good'];
        let criteria = array!['criteria'];
        let confidence = array![90];

        start_cheat_caller_address(contract.contract_address, oracle);
        contract
            .batch_submit_performance_evaluations(
                audition_ids, performer_ids, scores, comments, criteria, confidence,
            );
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: 'Invalid verification level')]
    fn test_invalid_verification_level_rejection() {
        let (contract, oracle) = setup_with_oracle();

        start_cheat_caller_address(contract.contract_address, oracle);
        contract
            .submit_credential_verification(
                USER(),
                'PROVIDER',
                true,
                6, // Invalid verification level (assuming valid range is 1-5)
                'hash',
                1700000000,
            );
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: 'Invalid score')]
    fn test_invalid_score_rejection() {
        let (contract, oracle) = setup_with_oracle();

        start_cheat_caller_address(contract.contract_address, oracle);
        contract.submit_vote(1, 1, 255); // Invalid score > 100 but within u32 range
    }

    #[test]
    #[available_gas(2000000)]
    fn test_comprehensive_oracle_workflow() {
        let contract = deploy_contract();
        let oracle = ORACLE1();

        // Step 1: Set up season and audition
        start_cheat_caller_address(contract.contract_address, OWNER());
        contract.authorize_oracle(oracle);
        contract.create_season(1, 'Summer_2024', 1672531200, 1675123200);
        contract.create_audition(1, 1, 'Live_Pop_Audition', 'Pop', 1672531200, 1675123200);
        stop_cheat_caller_address(contract.contract_address);

        // Step 2: Oracle submits comprehensive data
        start_cheat_caller_address(contract.contract_address, oracle);

        // Submit vote
        contract.submit_vote(1, 1, 88);

        // Submit performance evaluation
        contract
            .submit_performance_evaluation(1, 1, 88, 'excellent_vocals', 'strong_performance', 95);

        // Submit session status
        contract
            .submit_session_status_update(
                1, 'ACTIVE', 'session_running_smoothly', 'main_venue', 45,
            );

        // Submit credential verification
        contract
            .submit_credential_verification(
                USER(), 'ID_VERIFY', true, 3, 'verified_hash', 1700000000,
            );

        stop_cheat_caller_address(contract.contract_address);

        // Step 3: Verify all data was recorded correctly
        let season = contract.get_season(1);
        assert!(season.name == 'Summer_2024', "Season should be created");

        let audition = contract.get_audition(1);
        assert!(audition.name == 'Live_Pop_Audition', "Audition should be created");

        let vote = contract.get_vote(1, 1);
        assert!(vote.score == 88, "Vote should be recorded");

        let evaluation = contract.get_performance_evaluation(1, 1);
        assert!(evaluation.score == 88, "Evaluation should be recorded");

        let session = contract.get_session_status_update(1);
        assert!(session.status == 'ACTIVE', "Session should be recorded");

        let verification = contract.get_credential_verification(USER(), 'ID_VERIFY');
        assert!(verification.verified == true, "Verification should be recorded");

        // Step 4: Check system metrics
        assert!(contract.get_oracle_count() == 1, "Should have 1 oracle");
        assert!(contract.get_total_submissions() > 0, "Should have submissions");
    }
}
