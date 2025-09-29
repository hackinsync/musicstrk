use contract_::audition::types::season_and_audition::{
    Appeal, Audition, Evaluation, Genre, RegistrationConfig, Season, Vote,
};
use starknet::ContractAddress;

// Define the contract interface
#[starknet::interface]
pub trait ISeasonAndAudition<TContractState> {
    fn create_season(ref self: TContractState, name: felt252, start_time: u64, end_time: u64);

    fn read_season(self: @TContractState, season_id: u256) -> Season;

    fn update_season(
        ref self: TContractState, season_id: u256, name: Option<felt252>, end_time: Option<u64>,
    );

    fn get_active_season(self: @TContractState) -> Option<u256>;

    fn create_audition(ref self: TContractState, name: felt252, genre: Genre, end_timestamp: u64);
    fn read_audition(self: @TContractState, audition_id: u256) -> Audition;
    /// Updates the details of an audition. You can update the end time, name, and genre in a single
    /// call.
    fn update_audition_details(
        ref self: TContractState,
        audition_id: u256,
        new_time: Option<u64>,
        name: Option<felt252>,
        genre: Option<Genre>,
    );
    fn update_registration_config(
        ref self: TContractState, audition_id: u256, config: RegistrationConfig,
    );
    fn get_registration_config(
        ref self: TContractState, audition_id: u256,
    ) -> Option<RegistrationConfig>;

    /// @notice Performer submits the result of an audition.
    /// @dev Only the performer can submit the result.
    /// @param audition_id The ID of the audition the user wants to submit the result for.
    /// @param result_uri The URI of the result.
    /// @param performer_id The ID of the performer
    fn submit_result(
        ref self: TContractState, audition_id: u256, result_uri: ByteArray, performer_id: u256,
    );
    /// @notice Gets the result of a performer for an audition.

    fn get_result(self: @TContractState, audition_id: u256, performer_id: u256) -> ByteArray;
    /// @notice Gets the results of an audition.
    fn get_results(self: @TContractState, audition_id: u256) -> Array<ByteArray>;
    /// @notice Gets the results of a performer for an audition.
    fn get_performer_results(self: @TContractState, performer_id: u256) -> Array<ByteArray>;

    fn only_oracle(ref self: TContractState);
    fn add_oracle(ref self: TContractState, oracle_address: ContractAddress);
    fn remove_oracle(ref self: TContractState, oracle_address: ContractAddress);

    // price deposit and distribute functionalities
    fn deposit_prize(
        ref self: TContractState, audition_id: u256, token_address: ContractAddress, amount: u256,
    );

    fn distribute_prize(ref self: TContractState, audition_id: u256, shares: Array<u256>);

    fn get_audition_prices(self: @TContractState, audition_id: u256) -> (ContractAddress, u256);

    /// @notice Returns the winner addresses for a given audition.
    /// @param audition_id The unique identifier of the audition.
    fn get_audition_winner_addresses(
        self: @TContractState, audition_id: u256,
    ) -> Array<ContractAddress>;

    /// @notice Returns the winner prize amounts for a given audition.
    /// @param audition_id The unique identifier of the audition.
    fn get_audition_winner_amounts(self: @TContractState, audition_id: u256) -> Array<u256>;

    /// @notice Returns whether the prize has been distributed for a given audition.
    /// @param audition_id The unique identifier of the audition.
    /// @return bool True if distributed, false otherwise.
    fn is_prize_distributed(self: @TContractState, audition_id: u256) -> bool;

    // Vote recording functionality
    fn record_vote(
        ref self: TContractState,
        audition_id: u256,
        performer: ContractAddress,
        voter: ContractAddress,
        weight: felt252,
    );
    fn get_vote(
        self: @TContractState,
        audition_id: u256,
        performer: ContractAddress,
        voter: ContractAddress,
    ) -> Vote;

    // Pause/Resume functionality
    fn pause_all(ref self: TContractState);
    fn resume_all(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;

    fn pause_audition(ref self: TContractState, audition_id: u256) -> bool;
    fn resume_audition(ref self: TContractState, audition_id: u256) -> bool;
    fn end_audition(ref self: TContractState, audition_id: u256) -> bool;
    fn is_audition_paused(self: @TContractState, audition_id: u256) -> bool;
    fn is_audition_ended(self: @TContractState, audition_id: u256) -> bool;
    fn audition_exists(self: @TContractState, audition_id: u256) -> bool;

    fn pause_season(ref self: TContractState, season_id: u256);
    fn resume_season(ref self: TContractState, season_id: u256);
    fn is_season_paused(self: @TContractState, season_id: u256) -> bool;
    fn is_season_ended(self: @TContractState, season_id: u256) -> bool;
    fn season_exists(self: @TContractState, season_id: u256) -> bool;
    fn end_season(ref self: TContractState, season_id: u256);

    /// @notice adds a judge to an audition
    /// @dev only the owner can add a judge to an audition
    /// @param audition_id the id of the audition to add the judge to
    /// @param judge_address the address of the judge to add
    fn add_judge(ref self: TContractState, audition_id: u256, judge_address: ContractAddress);

    /// @notice removes a judge from an audition
    /// @dev only the owner can remove a judge from an audition
    /// @param audition_id the id of the audition to remove the judge from
    /// @param judge_address the address of the judge to remove
    fn remove_judge(ref self: TContractState, audition_id: u256, judge_address: ContractAddress);

    /// @notice gets all judges for an audition
    /// @dev returns a vec of all judges for an audition
    /// @param audition_id the id of the audition to get the judges for
    fn get_judges(self: @TContractState, audition_id: u256) -> Array<ContractAddress>;


    /// @notice Submits an evaluation for a performer in an audition.
    /// @dev Only authorized judges can submit evaluations.
    /// @param audition_id The ID of the audition being evaluated.
    /// @param performer_id The ID of the performer being evaluated.
    /// @param weight The weight of the evaluation (e.g., 1 for first place, 2 for second, etc.)
    /// @param criteria A tuple containing technical skills, creativity, and presentation scores.
    fn submit_evaluation(
        ref self: TContractState,
        audition_id: u256,
        performer_id: u256,
        criteria: (u256, u256, u256),
    );

    /// @notice Retrieves an evaluation for a specific performer in an audition.
    /// @param audition_id The ID of the audition being evaluated.
    /// @param performer_id The ID of the performer being evaluated.
    /// @return Evaluation The evaluation for the performer.
    fn get_evaluation(
        self: @TContractState, audition_id: u256, performer_id: u256,
    ) -> Array<Evaluation>;

    /// @notice Retrieves all evaluations for a specific audition.
    /// @param audition_id The ID of the audition being evaluated.
    /// @return [Evaluation; 3] An array of evaluations for the audition.
    fn get_evaluations(self: @TContractState, audition_id: u256) -> Array<Evaluation>;

    // Judging pause functionality
    /// @notice Pauses judging for all auditions
    /// @dev Only the owner can pause judging
    fn pause_judging(ref self: TContractState);

    /// @notice Resumes judging for all auditions
    /// @dev Only the owner can resume judging
    fn resume_judging(ref self: TContractState);

    /// @notice Returns whether judging is currently paused
    /// @return bool True if judging is paused, false otherwise
    fn is_judging_paused(self: @TContractState) -> bool;

    /// @notice sets the weight of each evaluation for an audition
    /// @dev only the owner can set the weight of each evaluation
    /// @param audition_id the id of the audition to set the weight for
    /// @param weight the weight of each evaluation
    fn set_evaluation_weight(
        ref self: TContractState, audition_id: u256, weight: (u256, u256, u256),
    );

    /// @notice gets the weight of each evaluation for an audition
    /// @param audition_id the id of the audition to get the weight for
    /// @return the weight of each evaluation
    fn get_evaluation_weight(self: @TContractState, audition_id: u256) -> (u256, u256, u256);

    /// @notice performs aggregate score calculation for a given audition
    /// @dev only the owner can perform aggregate score calculation
    /// @param audition_id the id of the audition to perform aggregate score calculation for
    fn perform_aggregate_score_calculation(ref self: TContractState, audition_id: u256);

    /// @notice gets the aggregate score for a given audition and performer
    /// @param audition_id the id of the audition to get the aggregate score for
    /// @param performer_id the id of the performer to get the aggregate score for
    fn get_aggregate_score_for_performer(
        self: @TContractState, audition_id: u256, performer_id: u256,
    ) -> u256;

    /// @notice Registers a performer for an audition successfully
    fn register_performer(
        ref self: TContractState,
        audition_id: u256,
        tiktok_id: felt252,
        tiktok_username: felt252,
        email_hash: felt252,
    ) -> u256;
    fn get_enrolled_performers(self: @TContractState, audition_id: u256) -> Array<u256>;

    /// @notice Submits an appeal for a specific evaluation.
    /// @param evaluation_id The ID of the evaluation being appealed.
    /// @param reason The reason/comment for the appeal.
    fn submit_appeal(ref self: TContractState, evaluation_id: u256, reason: felt252);
    /// @notice Resolves an appeal for a specific evaluation.
    /// @param evaluation_id The ID of the evaluation being appealed.
    /// @param resolution_comment The comment/reason for resolution.
    fn resolve_appeal(ref self: TContractState, evaluation_id: u256, resolution_comment: felt252);
    /// @notice Gets the appeal for a specific evaluation.
    fn get_appeal(self: @TContractState, evaluation_id: u256) -> Appeal;

    /// @notice gets the aggregate score for a given audition
    /// @param audition_id the id of the audition to get the aggregate score for
    /// @return a array of (performer_id, aggregate_score)
    fn get_aggregate_score(self: @TContractState, audition_id: u256) -> Array<(u256, u256)>;

    /// @notice Gets the total number of performers registered across all auditions.
    /// @dev This function returns a count of all unique performers in the system.
    /// @return u256 The total number of performers.
    fn get_performers_count(self: @TContractState) -> u256;

    /// @notice Gets the wallet address of a performer by their ID.
    /// @dev Retrieves the contract address associated with a given performer ID.
    /// @param performer_id The unique identifier of the performer.
    /// @return ContractAddress The wallet address of the performer.
    fn get_performer_address(
        self: @TContractState, audition_id: u256, performer_id: u256,
    ) -> ContractAddress;

    // Payment infrastructure functions
    /// @notice Deposits funds into escrow for an audition
    fn deposit_to_escrow(
        ref self: TContractState, audition_id: u256, token: ContractAddress, amount: u256,
    );

    /// @notice Releases escrowed funds to recipients
    fn release_escrow_funds(
        ref self: TContractState, audition_id: u256, recipients: Array<ContractAddress>, amounts: Array<u256>, token: ContractAddress,
    );

    /// @notice Processes refund for cancelled audition
    fn process_refund(ref self: TContractState, audition_id: u256, user: ContractAddress, token: ContractAddress);

    /// @notice Sets platform fee percentage
    fn set_platform_fee(ref self: TContractState, percentage: u256);

    /// @notice Gets platform fee percentage
    fn get_platform_fee(self: @TContractState) -> u256;

    /// @notice Sets participant shares for payment splitting
    fn set_participant_shares(ref self: TContractState, audition_id: u256, participants: Array<ContractAddress>, shares: Array<u256>);

    /// @notice Distributes payments with platform fee deduction
    fn distribute_with_fee(ref self: TContractState, audition_id: u256, token: ContractAddress, total_amount: u256);

    /// @notice Raises a payment dispute
    fn raise_dispute(ref self: TContractState, audition_id: u256, reason: felt252);

    /// @notice Resolves a payment dispute
    fn resolve_dispute(ref self: TContractState, audition_id: u256, decision: felt252);

    /// @notice Gets payment history for an audition
    fn get_payment_history(self: @TContractState, audition_id: u256) -> Array<(ContractAddress, u256, u64, felt252)>;

    /// @notice Gets escrow balance for an audition and token
    fn get_escrow_balance(self: @TContractState, audition_id: u256, token: ContractAddress) -> u256;

    /// @notice Gets total platform fees collected for a token
    fn get_platform_fees(self: @TContractState, token: ContractAddress) -> u256;

    /// @notice Withdraws collected platform fees
    fn withdraw_platform_fees(ref self: TContractState, token: ContractAddress, amount: u256);
}
