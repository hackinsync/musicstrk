use starknet::ContractAddress;
use super::season_and_audition_types::{
    Appeal, Audition, Evaluation, Genre, RegistrationConfig, Season, Vote,
};

// Define the contract interface
#[starknet::interface]
pub trait ISeasonAndAudition<TContractState> {
    fn create_season(
        ref self: TContractState, genre: Genre, name: felt252, start_time: u64, end_time: u64,
    );

    fn read_season(self: @TContractState, season_id: u256) -> Season;

    fn update_season(
        ref self: TContractState,
        season_id: u256,
        genre: Option<Genre>,
        name: Option<felt252>,
        end_time: Option<u64>,
    );

    fn get_active_season(self: @TContractState) -> Option<u256>;

    fn create_audition(
        ref self: TContractState,
        audition_id: felt252,
        season_id: u256,
        genre: Genre,
        name: felt252,
        start_timestamp: felt252,
        end_timestamp: felt252,
        paused: bool,
    );
    fn read_audition(self: @TContractState, audition_id: felt252) -> Audition;
    fn update_audition(ref self: TContractState, audition_id: felt252, audition: Audition);
    fn update_registration_config(
        ref self: TContractState, audition_id: felt252, config: RegistrationConfig,
    );
    fn get_registration_config(
        ref self: TContractState, audition_id: felt252,
    ) -> Option<RegistrationConfig>;
    fn delete_audition(ref self: TContractState, audition_id: felt252);
    fn submit_results(
        ref self: TContractState, audition_id: felt252, top_performers: felt252, shares: felt252,
    );
    fn only_oracle(ref self: TContractState);
    fn add_oracle(ref self: TContractState, oracle_address: ContractAddress);
    fn remove_oracle(ref self: TContractState, oracle_address: ContractAddress);

    // price deposit and distribute functionalities
    fn deposit_prize(
        ref self: TContractState,
        audition_id: felt252,
        token_address: ContractAddress,
        amount: u256,
    );

    fn distribute_prize(
        ref self: TContractState,
        audition_id: felt252,
        winners: [ContractAddress; 3],
        shares: [u256; 3],
    );

    fn get_audition_prices(self: @TContractState, audition_id: felt252) -> (ContractAddress, u256);

    /// @notice Returns the winner addresses for a given audition.
    /// @param audition_id The unique identifier of the audition.
    /// @return (ContractAddress, ContractAddress, ContractAddress) Tuple of winner addresses.
    fn get_audition_winner_addresses(
        self: @TContractState, audition_id: felt252,
    ) -> (ContractAddress, ContractAddress, ContractAddress);

    /// @notice Returns the winner prize amounts for a given audition.
    /// @param audition_id The unique identifier of the audition.
    /// @return (u256, u256, u256) Tuple of winner prize amounts.
    fn get_audition_winner_amounts(
        self: @TContractState, audition_id: felt252,
    ) -> (u256, u256, u256);

    /// @notice Returns whether the prize has been distributed for a given audition.
    /// @param audition_id The unique identifier of the audition.
    /// @return bool True if distributed, false otherwise.
    fn is_prize_distributed(self: @TContractState, audition_id: felt252) -> bool;

    // Vote recording functionality
    fn record_vote(
        ref self: TContractState,
        audition_id: felt252,
        performer: felt252,
        voter: felt252,
        weight: felt252,
    );
    fn get_vote(
        self: @TContractState, audition_id: felt252, performer: felt252, voter: felt252,
    ) -> Vote;

    // Pause/Resume functionality
    fn pause_all(ref self: TContractState);
    fn resume_all(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
    fn pause_audition(ref self: TContractState, audition_id: felt252) -> bool;
    fn resume_audition(ref self: TContractState, audition_id: felt252) -> bool;
    fn end_audition(ref self: TContractState, audition_id: felt252) -> bool;
    fn is_audition_paused(self: @TContractState, audition_id: felt252) -> bool;
    fn is_audition_ended(self: @TContractState, audition_id: felt252) -> bool;
    fn audition_exists(self: @TContractState, audition_id: felt252) -> bool;

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
    fn add_judge(ref self: TContractState, audition_id: felt252, judge_address: ContractAddress);

    /// @notice removes a judge from an audition
    /// @dev only the owner can remove a judge from an audition
    /// @param audition_id the id of the audition to remove the judge from
    /// @param judge_address the address of the judge to remove
    fn remove_judge(ref self: TContractState, audition_id: felt252, judge_address: ContractAddress);

    /// @notice gets all judges for an audition
    /// @dev returns a vec of all judges for an audition
    /// @param audition_id the id of the audition to get the judges for
    fn get_judges(self: @TContractState, audition_id: felt252) -> Array<ContractAddress>;


    /// @notice Submits an evaluation for a performer in an audition.
    /// @dev Only authorized judges can submit evaluations.
    /// @param audition_id The ID of the audition being evaluated.
    /// @param performer The ID of the performer being evaluated.
    /// @param weight The weight of the evaluation (e.g., 1 for first place, 2 for second, etc.)
    /// @param criteria A tuple containing technical skills, creativity, and presentation scores.
    fn submit_evaluation(
        ref self: TContractState,
        audition_id: felt252,
        performer: felt252,
        criteria: (u256, u256, u256),
    );

    /// @notice Retrieves an evaluation for a specific performer in an audition.
    /// @param audition_id The ID of the audition being evaluated.
    /// @param performer The ID of the performer being evaluated.
    /// @return Evaluation The evaluation for the performer.
    fn get_evaluation(
        self: @TContractState, audition_id: felt252, performer: felt252,
    ) -> Array<Evaluation>;

    /// @notice Retrieves all evaluations for a specific audition.
    /// @param audition_id The ID of the audition being evaluated.
    /// @return [Evaluation; 3] An array of evaluations for the audition.
    fn get_evaluations(self: @TContractState, audition_id: felt252) -> Array<Evaluation>;

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
        ref self: TContractState, audition_id: felt252, weight: (u256, u256, u256),
    );

    /// @notice gets the weight of each evaluation for an audition
    /// @param audition_id the id of the audition to get the weight for
    /// @return the weight of each evaluation
    fn get_evaluation_weight(self: @TContractState, audition_id: felt252) -> (u256, u256, u256);

    /// @notice performs aggregate score calculation for a given audition
    /// @dev only the owner can perform aggregate score calculation
    /// @param audition_id the id of the audition to perform aggregate score calculation for
    fn perform_aggregate_score_calculation(ref self: TContractState, audition_id: felt252);

    /// @notice gets the aggregate score for a given audition and performer
    /// @param audition_id the id of the audition to get the aggregate score for
    /// @param performer_id the id of the performer to get the aggregate score for
    fn get_aggregate_score_for_performer(
        self: @TContractState, audition_id: felt252, performer_id: felt252,
    ) -> u256;

    /// @notice dummy function to register a performer to an audition
    fn register_performer(
        ref self: TContractState,
        audition_id: felt252,
        tiktok_id: felt252,
        tiktok_username: felt252,
        email_hash: felt252,
    ) -> felt252;
    fn get_enrolled_performers(self: @TContractState, audition_id: felt252) -> Array<felt252>;

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
    fn get_aggregate_score(self: @TContractState, audition_id: felt252) -> Array<(felt252, u256)>;
}
