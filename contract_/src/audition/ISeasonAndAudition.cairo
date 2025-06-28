use starknet::ContractAddress;

#[starknet::interface]
trait ISeasonAndAudition<TContractState> {
    // Season management
    fn create_season(
        ref self: TContractState,
        season_id: felt252,
        name: felt252,
        start_timestamp: u64,
        end_timestamp: u64,
        paused: bool,
    );
    fn read_season(self: @TContractState, season_id: felt252) -> Season;
    fn update_season(ref self: TContractState, season_id: felt252, season: Season);
    fn delete_season(ref self: TContractState, season_id: felt252);

    // Audition management
    fn create_audition(
        ref self: TContractState,
        audition_id: felt252,
        season_id: felt252,
        genre: felt252,
        name: felt252,
        start_timestamp: u64,
        end_timestamp: u64,
        paused: bool,
    );
    fn read_audition(self: @TContractState, audition_id: felt252) -> Audition;
    fn update_audition(ref self: TContractState, audition_id: felt252, audition: Audition);
    fn delete_audition(ref self: TContractState, audition_id: felt252);

    // Results submission
    fn submit_results(
        ref self: TContractState,
        audition_id: felt252,
        performer_id: felt252,
        score: u32,
        rank: u32,
    );

    // Oracle management
    fn only_oracle(ref self: TContractState);
    fn add_oracle(ref self: TContractState, oracle_address: ContractAddress);
    fn remove_oracle(ref self: TContractState, oracle_address: ContractAddress);

    // Vote management
    fn record_vote(
        ref self: TContractState,
        audition_id: felt252,
        performer_id: felt252,
        voter_id: felt252,
        score: u32,
    );
    fn get_vote(
        self: @TContractState, audition_id: felt252, performer_id: felt252, voter_id: felt252,
    ) -> Vote;

    // Pause management
    fn pause_all(ref self: TContractState);
    fn resume_all(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
    fn pause_audition(ref self: TContractState, audition_id: felt252) -> bool;
    fn resume_audition(ref self: TContractState, audition_id: felt252) -> bool;
    fn end_audition(ref self: TContractState, audition_id: felt252) -> bool;
    fn is_audition_paused(self: @TContractState, audition_id: felt252) -> bool;
    fn is_audition_ended(self: @TContractState, audition_id: felt252) -> bool;
    fn audition_exists(self: @TContractState, audition_id: felt252) -> bool;

    // Oracle data submission
    fn submit_performance_evaluation(
        ref self: TContractState,
        audition_id: felt252,
        performer_id: felt252,
        score: u32,
        comments: felt252,
    );
    fn submit_session_status_update(ref self: TContractState, session_id: felt252, status: felt252);
    fn submit_credential_verification(
        ref self: TContractState, participant_id: felt252, provider: felt252, verified: bool,
    );

    // Oracle data retrieval
    fn get_latest_performance_evaluation(
        self: @TContractState, audition_id: felt252, performer_id: felt252,
    ) -> PerformanceEvaluation;
    fn get_latest_session_status_update(
        self: @TContractState, session_id: felt252,
    ) -> SessionStatusUpdate;
    fn get_latest_credential_verification(
        self: @TContractState, participant_id: felt252,
    ) -> CredentialVerification;

    // Oracle data validation
    fn get_latest_valid_performance_evaluation(
        self: @TContractState, audition_id: felt252, performer_id: felt252,
    ) -> PerformanceEvaluation;
    fn get_latest_valid_session_status_update(
        self: @TContractState, session_id: felt252,
    ) -> SessionStatusUpdate;
    fn get_latest_valid_credential_verification(
        self: @TContractState, participant_id: felt252,
    ) -> CredentialVerification;

    // Batch operations
    fn batch_submit_performance_evaluations(
        ref self: TContractState,
        audition_ids: Array<felt252>,
        performer_ids: Array<felt252>,
        scores: Array<u32>,
        comments: Array<felt252>,
    );
    fn batch_submit_session_status_updates(
        ref self: TContractState, session_ids: Array<felt252>, statuses: Array<felt252>,
    );
    fn batch_submit_credential_verifications(
        ref self: TContractState,
        participant_ids: Array<felt252>,
        providers: Array<felt252>,
        verifieds: Array<bool>,
    );

    // Bulk data retrieval
    fn get_all_valid_performance_evaluations(
        self: @TContractState, audition_id: felt252, performer_id: felt252,
    ) -> Array<PerformanceEvaluation>;
    fn get_all_valid_session_status_updates(
        self: @TContractState, session_id: felt252,
    ) -> Array<SessionStatusUpdate>;
    fn get_all_valid_credential_verifications(
        self: @TContractState, participant_id: felt252,
    ) -> Array<CredentialVerification>;

    // Consensus getters
    fn get_majority_performance_score(
        self: @TContractState, audition_id: felt252, performer_id: felt252,
    ) -> u32;
    fn get_majority_session_status(self: @TContractState, session_id: felt252) -> felt252;
    fn get_majority_credential_verification(self: @TContractState, participant_id: felt252) -> bool;
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Season {
    name: felt252,
    start_timestamp: u64,
    end_timestamp: u64,
    paused: bool,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Audition {
    season_id: felt252,
    genre: felt252,
    name: felt252,
    start_timestamp: u64,
    end_timestamp: u64,
    paused: bool,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Vote {
    audition_id: felt252,
    performer_id: felt252,
    voter_id: felt252,
    score: u32,
    timestamp: u64,
}
