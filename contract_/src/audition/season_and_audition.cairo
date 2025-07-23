use starknet::ContractAddress;

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Season {
    pub season_id: felt252,
    pub genre: felt252,
    pub name: felt252,
    pub start_timestamp: felt252,
    pub end_timestamp: felt252,
    pub paused: bool,
}

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Audition {
    pub audition_id: felt252,
    pub season_id: felt252,
    pub genre: felt252,
    pub name: felt252,
    pub start_timestamp: felt252,
    pub end_timestamp: felt252,
    pub paused: bool,
}

#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Vote {
    pub audition_id: felt252,
    pub performer: felt252,
    pub voter: felt252,
    pub weight: felt252,
}

/// @notice Evaluation struct for storing performer evaluations
/// @param audition_id The ID of the audition being evaluated
/// @param performer The ID of the performer being evaluated
/// @param voter The ID of the voter submitting the evaluation
/// @param weight The weight of each evaluation (e.g. (40%, 30%, 30%))
/// @param criteria A tuple containing technical skills, creativity, and presentation scores
#[derive(Drop, Serde, Default, starknet::Store)]
pub struct Evaluation {
    pub audition_id: felt252,
    pub performer: felt252,
    pub criteria: (u8, u8, u8),
}


// Define the contract interface
#[starknet::interface]
pub trait ISeasonAndAudition<TContractState> {
    fn create_season(
        ref self: TContractState,
        season_id: felt252,
        genre: felt252,
        name: felt252,
        start_timestamp: felt252,
        end_timestamp: felt252,
        paused: bool,
    );
    fn read_season(self: @TContractState, season_id: felt252) -> Season;
    fn update_season(ref self: TContractState, season_id: felt252, season: Season);
    fn delete_season(ref self: TContractState, season_id: felt252);
    fn create_audition(
        ref self: TContractState,
        audition_id: felt252,
        season_id: felt252,
        genre: felt252,
        name: felt252,
        start_timestamp: felt252,
        end_timestamp: felt252,
        paused: bool,
    );
    fn read_audition(self: @TContractState, audition_id: felt252) -> Audition;
    fn update_audition(ref self: TContractState, audition_id: felt252, audition: Audition);
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
        ref self: TContractState, audition_id: felt252, performer: felt252, criteria: (u8, u8, u8),
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
    fn set_evaluation_weight(ref self: TContractState, audition_id: felt252, weight: (u8, u8, u8));

    /// @notice gets the weight of each evaluation for an audition
    /// @param audition_id the id of the audition to get the weight for
    /// @return the weight of each evaluation
    fn get_evaluation_weight(self: @TContractState, audition_id: felt252) -> (u8, u8, u8);
}

#[starknet::contract]
pub mod SeasonAndAudition {
    use OwnableComponent::{HasComponent, InternalTrait};
    use contract_::errors::errors;
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::event::EventEmitter;
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{
        ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
        get_contract_address,
    };
    use crate::events::{
        AuditionCreated, AuditionDeleted, AuditionEnded, AuditionPaused, AuditionResumed,
        AuditionUpdated, EvaluationSubmitted, EvaluationWeightSet, JudgeAdded, JudgeRemoved,
        OracleAdded, OracleRemoved, PausedAll, PriceDeposited, PriceDistributed, ResultsSubmitted,
        ResumedAll, SeasonCreated, SeasonDeleted, SeasonUpdated, VoteRecorded,
    };
    use super::{Audition, Evaluation, ISeasonAndAudition, Season, Vote};

    // Integrates OpenZeppelin ownership component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        whitelisted_oracles: Map<ContractAddress, bool>,
        seasons: Map<felt252, Season>,
        auditions: Map<felt252, Audition>,
        votes: Map<(felt252, felt252, felt252), Vote>,
        global_paused: bool,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        // @notice this storage is a mapping of the audition rpices deposited by the audition
        // owners, Map<audition_id, (token contract address  , amount of the token set as the
        // price)>
        audition_prices: Map<felt252, (ContractAddress, u256)>,
        /// @notice Maps each audition ID to the winner addresses for that audition.
        /// @dev The value is a tuple containing the addresses of the first, second, and third place
        /// winners.
        /// @param audition_winner_addresses Mapping from audition ID (felt252) to a tuple of winner
        /// addresses (ContractAddress, ContractAddress, ContractAddress).
        audition_winner_addresses: Map<
            felt252, (ContractAddress, ContractAddress, ContractAddress),
        >,
        /// @notice Maps each audition ID to the prize amounts for the winners.
        /// @dev The value is a tuple containing the prize amounts for the first, second, and third
        /// place winners, respectively.
        /// @param audition_winner_amounts Mapping from audition ID (felt252) to a tuple of prize
        /// amounts (u256, u256, u256).
        audition_winner_amounts: Map<felt252, (u256, u256, u256)>,
        /// price distributed status
        price_distributed: Map<felt252, bool>,
        /// @notice maps each audition id to a list of judges
        /// @dev a vec containing all judges contract addresses
        audition_judge: Map<felt252, Vec<ContractAddress>>,
        /// @notice maps each audition id to a list of evaluation id
        /// @dev a vec containing all evaluation ids
        audition_evaluations: Map<felt252, Vec<u256>>,
        /// @notice maps each audition id and performer id to a list of evaluation id for a specific
        /// performer @dev a vec containing all evaluation ids for a specific performer
        audition_evaluations_for_performer: Map<(felt252, felt252), Vec<u256>>,
        /// @notice maps an evaluation id to an evaluation
        /// @dev a map containing an evaluation
        evaluations: Map<u256, Evaluation>,
        /// @notice stores the number of evaluations
        /// @dev a u256 containing the number of evaluations
        evaluation_count: u256,
        /// @notice global pause state for judging functionality
        /// @dev when true, all judging operations are paused
        judging_paused: bool,
        /// @notice maps the submission status of an evaluation for a given audition, performer, and
        /// judge @dev Map from (audition_id, performer_id, judge_address) to bool indicating if
        /// evaluation was submitted
        evaluation_submission_status: Map<(felt252, felt252, ContractAddress), bool>,
        /// @notice maps each audition to the weight of each evaluation
        /// @dev Map from audition_id to (u8, u8, u8) indicating the weight of each evaluation
        /// @dev NOTE: THE CRITERIA IS A TUPLE OF THE SCORE OF EACH EVALUATION: TECHNICAL SKILLS,
        /// CREATIVITY, AND PRESENTATION This is how it will be passed whenever it is being used in
        /// a tuple
        audition_evaluation_weight: Map<felt252, (u8, u8, u8)>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SeasonCreated: SeasonCreated,
        SeasonUpdated: SeasonUpdated,
        SeasonDeleted: SeasonDeleted,
        AuditionCreated: AuditionCreated,
        AuditionUpdated: AuditionUpdated,
        AuditionDeleted: AuditionDeleted,
        AuditionPaused: AuditionPaused,
        AuditionResumed: AuditionResumed,
        AuditionEnded: AuditionEnded,
        ResultsSubmitted: ResultsSubmitted,
        OracleAdded: OracleAdded,
        OracleRemoved: OracleRemoved,
        VoteRecorded: VoteRecorded,
        PausedAll: PausedAll,
        ResumedAll: ResumedAll,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        PriceDeposited: PriceDeposited,
        PriceDistributed: PriceDistributed,
        JudgeAdded: JudgeAdded,
        JudgeRemoved: JudgeRemoved,
        EvaluationSubmitted: EvaluationSubmitted,
        EvaluationWeightSet: EvaluationWeightSet,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.global_paused.write(false);
        self.judging_paused.write(false);
    }

    #[abi(embed_v0)]
    impl ISeasonAndAuditionImpl of ISeasonAndAudition<ContractState> {
        fn create_season(
            ref self: ContractState,
            season_id: felt252,
            genre: felt252,
            name: felt252,
            start_timestamp: felt252,
            end_timestamp: felt252,
            paused: bool,
        ) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');

            self
                .seasons
                .entry(season_id)
                .write(Season { season_id, genre, name, start_timestamp, end_timestamp, paused });

            self
                .emit(
                    Event::SeasonCreated(
                        SeasonCreated { season_id, genre, name, timestamp: get_block_timestamp() },
                    ),
                );
        }

        fn read_season(self: @ContractState, season_id: felt252) -> Season {
            self.seasons.entry(season_id).read()
        }

        fn update_season(ref self: ContractState, season_id: felt252, season: Season) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');

            self.seasons.entry(season_id).write(season);
            self
                .emit(
                    Event::SeasonUpdated(
                        SeasonUpdated { season_id, timestamp: get_block_timestamp() },
                    ),
                );
        }

        fn delete_season(ref self: ContractState, season_id: felt252) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');

            let default_season: Season = Default::default();

            self.seasons.entry(season_id).write(default_season);
            self
                .emit(
                    Event::SeasonDeleted(
                        SeasonDeleted { season_id, timestamp: get_block_timestamp() },
                    ),
                );
        }

        fn create_audition(
            ref self: ContractState,
            audition_id: felt252,
            season_id: felt252,
            genre: felt252,
            name: felt252,
            start_timestamp: felt252,
            end_timestamp: felt252,
            paused: bool,
        ) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');

            self
                .auditions
                .entry(audition_id)
                .write(
                    Audition {
                        audition_id, season_id, genre, name, start_timestamp, end_timestamp, paused,
                    },
                );

            self
                .emit(
                    Event::AuditionCreated(
                        AuditionCreated {
                            audition_id, season_id, genre, name, timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn read_audition(self: @ContractState, audition_id: felt252) -> Audition {
            self.auditions.entry(audition_id).read()
        }

        fn update_audition(ref self: ContractState, audition_id: felt252, audition: Audition) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(!self.is_audition_paused(audition_id), 'Cannot update paused audition');
            assert(!self.is_audition_ended(audition_id), 'Cannot update ended audition');
            self.auditions.entry(audition_id).write(audition);
            self
                .emit(
                    Event::AuditionUpdated(
                        AuditionUpdated { audition_id, timestamp: get_block_timestamp() },
                    ),
                );
        }

        fn delete_audition(ref self: ContractState, audition_id: felt252) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(!self.is_audition_paused(audition_id), 'Cannot delete paused audition');
            assert(!self.is_audition_ended(audition_id), 'Cannot delete ended audition');

            let default_audition: Audition = Default::default();

            self.auditions.entry(audition_id).write(default_audition);
            self
                .emit(
                    Event::AuditionDeleted(
                        AuditionDeleted { audition_id, timestamp: get_block_timestamp() },
                    ),
                );
        }

        /// @notice sets the weight of each evaluation for an audition
        /// @dev only the owner can set the weight of each evaluation
        /// @param audition_id the id of the audition to set the weight for
        /// @param weight the weight of each evaluation
        fn set_evaluation_weight(
            ref self: ContractState, audition_id: felt252, weight: (u8, u8, u8),
        ) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition has ended');
            assert(!self.is_audition_paused(audition_id), 'Audition is paused');
            self.assert_evaluation_weight_should_be_100(weight);
            self.audition_evaluation_weight.write(audition_id, weight);
            self.emit(Event::EvaluationWeightSet(EvaluationWeightSet { audition_id, weight }));
        }

        /// @notice gets the weight of each evaluation for an audition
        /// @dev returns the weight of each evaluation for an audition
        /// @param audition_id the id of the audition to get the weight for
        /// @return a tupule of the weight of each evaluation
        fn get_evaluation_weight(self: @ContractState, audition_id: felt252) -> (u8, u8, u8) {
            self.audition_evaluation_weight.read(audition_id)
        }

        /// @notice adds a judge to an audition
        /// @dev only the owner can add a judge to an audition
        /// @param audition_id the id of the audition to add the judge to
        /// @param judge_address the address of the judge to add
        fn add_judge(
            ref self: ContractState, audition_id: felt252, judge_address: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition has already ended');

            self.assert_judge_not_added(audition_id, judge_address);
            assert(!judge_address.is_zero(), 'Cannot be zero');

            self.audition_judge.entry(audition_id).push(judge_address);

            self.emit(Event::JudgeAdded(JudgeAdded { audition_id, judge_address }));
        }

        /// @notice removes a judge from an audition
        /// @dev only the owner can remove a judge from an audition
        /// @param audition_id the id of the audition to remove the judge from
        /// @param judge_address the address of the judge to remove
        fn remove_judge(
            ref self: ContractState, audition_id: felt252, judge_address: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition has ended');
            assert(!self.is_audition_paused(audition_id), 'Audition is paused');
            self.assert_judge_found(audition_id, judge_address);

            let judges: Array<ContractAddress> = self.get_judges(audition_id);

            let mut judge_vec = self.audition_judge.entry(audition_id);
            for _ in 0..judge_vec.len() {
                let _ = judge_vec.pop();
            }

            for judge in judges {
                if judge != judge_address {
                    judge_vec.push(judge);
                };
            }

            self.emit(Event::JudgeRemoved(JudgeRemoved { audition_id, judge_address }));
        }

        /// @notice gets all judges for an audition
        /// @dev returns a vec of all judges for an audition
        /// @param audition_id the id of the audition to get the judges for
        fn get_judges(self: @ContractState, audition_id: felt252) -> Array<ContractAddress> {
            let mut judges = ArrayTrait::<ContractAddress>::new();
            for i in 0..self.audition_judge.entry(audition_id).len() {
                let judge: ContractAddress = self.audition_judge.entry(audition_id).at(i).read();
                judges.append(judge);
            }
            judges
        }

        /// @notice submits an evaluation for a performer in an audition
        /// @dev only judges can submit evaluations
        /// @param audition_id the id of the audition to submit the evaluation for
        /// @param performer the id of the performer to submit the evaluation for
        /// @param weight the weight of the evaluation
        /// @param criteria the criteria of the evaluation
        fn submit_evaluation(
            ref self: ContractState,
            audition_id: felt252,
            performer: felt252,
            criteria: (u8, u8, u8),
        ) {
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(!self.judging_paused.read(), 'Judging is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition has ended');
            assert(!self.is_audition_paused(audition_id), 'Audition is paused');
            let judge = get_caller_address();
            self.assert_judge_found(audition_id, judge);
            self.assert_evaluation_not_submitted(audition_id, performer, judge);
            self.evaluation_submission_status.write((audition_id, performer, judge), true);

            let mut new_evaluation_id = self.evaluation_count.read() + 1;
            self.evaluation_count.write(new_evaluation_id);

            self
                .evaluations
                .entry(new_evaluation_id)
                .write(Evaluation { audition_id, performer, criteria });

            self.audition_evaluations.entry(audition_id).push(new_evaluation_id);
            self
                .audition_evaluations_for_performer
                .entry((audition_id, performer))
                .push(new_evaluation_id);
            self
                .emit(
                    Event::EvaluationSubmitted(
                        EvaluationSubmitted { audition_id, performer, criteria },
                    ),
                );
        }

        /// @notice gets an evaluation for a specific performer in an audition
        /// @param audition_id the id of the audition to get the evaluation for
        /// @param performer the id of the performer to get the evaluation for
        /// @return the evaluation for the performer
        fn get_evaluation(
            self: @ContractState, audition_id: felt252, performer: felt252,
        ) -> Array<Evaluation> {
            let evaluation_ids = self
                .audition_evaluations_for_performer
                .entry((audition_id, performer));
            let mut evaluations = ArrayTrait::new();
            for i in 0..evaluation_ids.len() {
                let evaluation_id = evaluation_ids.at(i).read();
                let evaluation = self.evaluations.entry(evaluation_id).read();
                evaluations.append(evaluation);
            }
            evaluations
        }

        /// @notice gets all evaluations for an audition
        /// @param audition_id the id of the audition to get the evaluations for
        /// @return the evaluations for the audition
        fn get_evaluations(self: @ContractState, audition_id: felt252) -> Array<Evaluation> {
            let evaluation_ids = self.audition_evaluations.entry(audition_id);
            let mut evaluations = ArrayTrait::new();
            for i in 0..evaluation_ids.len() {
                let evaluation_id = evaluation_ids.at(i).read();
                let evaluation = self.evaluations.entry(evaluation_id).read();
                evaluations.append(evaluation);
            }
            evaluations
        }


        fn pause_judging(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.judging_paused.write(true);
        }

        fn resume_judging(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.judging_paused.write(false);
        }

        fn is_judging_paused(self: @ContractState) -> bool {
            self.judging_paused.read()
        }


        fn submit_results(
            ref self: ContractState, audition_id: felt252, top_performers: felt252, shares: felt252,
        ) {
            self.only_oracle();
            assert(!self.global_paused.read(), 'Contract is paused');

            self
                .emit(
                    Event::ResultsSubmitted(
                        ResultsSubmitted {
                            audition_id, top_performers, shares, timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn only_oracle(ref self: ContractState) {
            let caller = get_caller_address();
            let is_whitelisted = self.whitelisted_oracles.read(caller);
            assert(is_whitelisted, 'Not Authorized');
        }

        fn add_oracle(ref self: ContractState, oracle_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.whitelisted_oracles.write(oracle_address, true);
            self.emit(Event::OracleAdded(OracleAdded { oracle_address }));
        }

        fn remove_oracle(ref self: ContractState, oracle_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.whitelisted_oracles.write(oracle_address, false);
            self.emit(Event::OracleRemoved(OracleRemoved { oracle_address }));
        }

        /// @notice Deposits the prize for a specific audition.
        /// @dev Only the contract owner can call this function. The contract must not be paused,
        ///      the audition must exist and not be ended, and the amount must be greater than zero.
        ///      The function processes the payment, records the prize, and emits a `PriceDeposited`
        ///      event.
        /// @param audition_id The unique identifier of the audition for which the prize is being
        /// deposited.
        /// @param token_address The address of the token to be used as the prize.
        /// @param amount The amount of tokens to be deposited as the prize.
        fn deposit_prize(
            ref self: ContractState,
            audition_id: felt252,
            token_address: ContractAddress,
            amount: u256,
        ) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition has already ended');
            assert(amount > 0, 'Amount must be more than zero');
            assert(!token_address.is_zero(), 'Token address cannot be zero');
            let (existing_token_address, existing_amount) = self.audition_prices.read(audition_id);
            assert(
                existing_token_address.is_zero() && existing_amount == 0, 'Prize already deposited',
            );
            self._process_payment(amount, token_address);
            self.audition_prices.write(audition_id, (token_address, amount));
            self.emit(Event::PriceDeposited(PriceDeposited { audition_id, token_address, amount }));
        }

        /// @notice Retrieves the prize information for a specific audition.
        /// @dev Returns the token contract address and the amount of tokens deposited as the prize
        /// for the given audition.
        /// @param self The contract state reference.
        /// @param audition_id The unique identifier of the audition whose prize information is
        /// being queried.
        /// @return token_address The address of the token used as the prize.
        /// @return amount The amount of tokens deposited as the prize.
        fn get_audition_prices(
            self: @ContractState, audition_id: felt252,
        ) -> (ContractAddress, u256) {
            self.audition_prices.read(audition_id)
        }


        /// @notice Distributes the prize pool among the specified winners based on their respective
        /// shares.
        /// @dev This function reads the prize pool for the given audition, calculates each winner's
        /// share,
        ///      and sends the corresponding token amount to each winner.
        /// @param self The contract state reference.
        /// @param audition_id The unique identifier of the audition whose prize is to be
        /// distributed.
        /// @param winners An array of 3 contract addresses representing the winners.
        /// @param shares An array of 3 u256 values representing the percentage shares (out of 100)
        /// for each winner.
        /// @custom:reverts If the distribution conditions are not met, as checked by
        /// `assert_distributed`.
        fn distribute_prize(
            ref self: ContractState,
            audition_id: felt252,
            winners: [ContractAddress; 3],
            shares: [u256; 3],
        ) {
            self.assert_distributed(audition_id, winners, shares);
            let (token_contract_address, price_pool): (ContractAddress, u256) = self
                .audition_prices
                .read(audition_id);
            let winners_span = winners.span();
            let shares_span = shares.span();
            let mut distributed_amounts = ArrayTrait::new();
            let mut i = 0;
            for share in shares_span {
                let amount = price_pool * *share / 100;
                distributed_amounts.append(amount);
                i += 1;
            }
            let mut count = 0;
            for elements in winners_span {
                let winner_contract_address = *elements;
                let amount = *distributed_amounts.at(count);
                self._send_tokens(winner_contract_address, amount, token_contract_address);
                count += 1;
            }
            self
                .audition_winner_addresses
                .write(
                    audition_id, (*winners_span.at(0), *winners_span.at(1), *winners_span.at(2)),
                );
            self
                .audition_winner_amounts
                .write(
                    audition_id,
                    (
                        *distributed_amounts.at(0),
                        *distributed_amounts.at(1),
                        *distributed_amounts.at(2),
                    ),
                );
            self.price_distributed.write(audition_id, true);
            self
                .emit(
                    Event::PriceDistributed(
                        PriceDistributed {
                            audition_id,
                            winners,
                            shares,
                            token_address: token_contract_address,
                            amounts: distributed_amounts.span(),
                        },
                    ),
                );
        }

        fn get_audition_winner_addresses(
            self: @ContractState, audition_id: felt252,
        ) -> (ContractAddress, ContractAddress, ContractAddress) {
            self.audition_winner_addresses.read(audition_id)
        }

        fn get_audition_winner_amounts(
            self: @ContractState, audition_id: felt252,
        ) -> (u256, u256, u256) {
            self.audition_winner_amounts.read(audition_id)
        }

        fn is_prize_distributed(self: @ContractState, audition_id: felt252) -> bool {
            self.price_distributed.read(audition_id)
        }


        fn record_vote(
            ref self: ContractState,
            audition_id: felt252,
            performer: felt252,
            voter: felt252,
            weight: felt252,
        ) {
            self.only_oracle();
            assert(!self.global_paused.read(), 'Contract is paused');

            // Check if vote already exists (duplicate vote prevention)
            let vote_key = (audition_id, performer, voter);
            let existing_vote = self.votes.entry(vote_key).read();

            // If the vote has a non-zero audition_id, it means a vote already exists
            assert(existing_vote.audition_id == 0, errors::DUPLICATE_VOTE);

            self.votes.entry(vote_key).write(Vote { audition_id, performer, voter, weight });

            self.emit(Event::VoteRecorded(VoteRecorded { audition_id, performer, voter, weight }));
        }

        fn get_vote(
            self: @ContractState, audition_id: felt252, performer: felt252, voter: felt252,
        ) -> Vote {
            self.ownable.assert_only_owner();

            self.votes.entry((audition_id, performer, voter)).read()
        }

        fn pause_all(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.global_paused.write(true);
            self.emit(Event::PausedAll(PausedAll { timestamp: get_block_timestamp() }));
        }

        fn resume_all(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.global_paused.write(false);
            self.emit(Event::ResumedAll(ResumedAll { timestamp: get_block_timestamp() }));
        }

        fn is_paused(self: @ContractState) -> bool {
            self.global_paused.read()
        }

        fn pause_audition(ref self: ContractState, audition_id: felt252) -> bool {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');

            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition has already ended');
            assert(!self.is_audition_paused(audition_id), 'Audition is already paused');

            let mut audition = self.auditions.entry(audition_id).read();
            audition.paused = true;
            self.auditions.entry(audition_id).write(audition);

            self
                .emit(
                    Event::AuditionPaused(
                        AuditionPaused { audition_id, timestamp: get_block_timestamp() },
                    ),
                );
            true
        }

        fn resume_audition(ref self: ContractState, audition_id: felt252) -> bool {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');

            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition has already ended');
            assert(self.is_audition_paused(audition_id), 'Audition is not paused');

            let mut audition = self.auditions.entry(audition_id).read();
            audition.paused = false;
            self.auditions.entry(audition_id).write(audition);

            self
                .emit(
                    Event::AuditionResumed(
                        AuditionResumed { audition_id, timestamp: get_block_timestamp() },
                    ),
                );
            true
        }

        fn end_audition(ref self: ContractState, audition_id: felt252) -> bool {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');

            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition already ended');

            let mut audition = self.auditions.entry(audition_id).read();
            let current_time = get_block_timestamp();

            // Set end_timestamp to current time to end audition immediately
            audition.end_timestamp = current_time.into();
            self.auditions.entry(audition_id).write(audition);

            self
                .emit(
                    Event::AuditionEnded(
                        AuditionEnded { audition_id, timestamp: get_block_timestamp() },
                    ),
                );
            true
        }


        fn is_audition_paused(self: @ContractState, audition_id: felt252) -> bool {
            let audition = self.auditions.entry(audition_id).read();
            audition.paused
        }

        fn is_audition_ended(self: @ContractState, audition_id: felt252) -> bool {
            let audition = self.auditions.entry(audition_id).read();
            let current_time = get_block_timestamp();

            if audition.end_timestamp != 0 {
                let end_time_u64: u64 = audition.end_timestamp.try_into().unwrap();
                let current_time_u64: u64 = current_time;

                current_time_u64 >= end_time_u64
            } else {
                false
            }
        }

        fn audition_exists(self: @ContractState, audition_id: felt252) -> bool {
            let audition = self.auditions.entry(audition_id).read();
            audition.audition_id != 0
        }
    }

    #[generate_trait]
    impl internal of InternalTraits {
        /// @notice Processes a payment of the audition prices
        /// @dev Checks the token allowance and balance before transferring tokens.
        /// @param self The contract state reference.
        /// @param amount The amount of tokens to transfer.
        /// @require The caller must have sufficient token allowance and balance.
        fn _process_payment(ref self: ContractState, amount: u256, token_address: ContractAddress) {
            let payment_token = IERC20Dispatcher { contract_address: token_address };
            let caller = get_caller_address();
            let contract_address = get_contract_address();
            self._check_token_allowance(caller, amount, token_address);
            self._check_token_balance(caller, amount, token_address);
            payment_token.transfer_from(caller, contract_address, amount);
        }

        /// @notice Checks if the caller has sufficient token allowance.
        /// @dev Asserts that the caller has enough allowance to transfer the specified amount.
        /// @param self The contract state reference.
        /// @param spender The address of the spender (usually the contract itself).
        /// @param amount The amount of tokens to check allowance for.
        /// @require The caller must have sufficient token allowance.
        fn _check_token_allowance(
            ref self: ContractState,
            spender: ContractAddress,
            amount: u256,
            token_address: ContractAddress,
        ) {
            let token = IERC20Dispatcher { contract_address: token_address };
            let allowance = token.allowance(spender, starknet::get_contract_address());
            assert(allowance >= amount, errors::INSUFFICIENT_ALLOWANCE);
        }

        /// @notice Checks if the caller has sufficient token balance.
        /// @dev Asserts that the caller has enough balance to transfer the specified amount.
        /// @param self The contract state reference.
        /// @param caller The address of the caller (usually the user).
        /// @param amount The amount of tokens to check balance for.
        /// @require The caller must have sufficient token balance.
        fn _check_token_balance(
            ref self: ContractState,
            caller: ContractAddress,
            amount: u256,
            token_address: ContractAddress,
        ) {
            let token = IERC20Dispatcher { contract_address: token_address };
            let balance = token.balance_of(caller);
            assert(balance >= amount, errors::INSUFFICIENT_BALANCE);
        }

        fn _send_tokens(
            ref self: ContractState,
            recepient: ContractAddress,
            amount: u256,
            token_address: ContractAddress,
        ) {
            let token = IERC20Dispatcher { contract_address: token_address };
            let contract = get_contract_address();
            self._check_token_balance(contract, amount, token_address);
            token.transfer(recepient, amount);
        }

        /// @notice Asserts the validity of prize distribution for a given audition.
        /// @dev This function checks multiple conditions before allowing prize distribution:
        ///      - Only the contract owner can call this function.
        ///      - The contract must not be globally paused.
        ///      - The specified audition must exist and must have ended.
        ///      - The audition must have a valid prize pool (non-zero token contract address).
        ///      - The `winners` array must not contain any zero addresses (null contract address).
        ///      - The sum of all `shares` must equal 100.
        /// @param self The contract state reference.
        /// @param audition_id The unique identifier of the audition to distribute prizes for.
        /// @param winners An array of 3 contract addresses representing the winners.
        /// @param shares An array of 3 u256 values representing the share percentages for each
        /// winner.
        /// @custom:reverts If called by anyone other than the owner.
        /// @custom:reverts If the contract is paused.
        /// @custom:reverts If the audition does not exist or has not ended.
        /// @custom:reverts If there is no prize for the audition.
        /// @custom:reverts If any winner address is zero.
        /// @custom:reverts If the total shares do not add up to 100.
        fn assert_distributed(
            ref self: ContractState,
            audition_id: felt252,
            winners: [ContractAddress; 3],
            shares: [u256; 3],
        ) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(self.is_audition_ended(audition_id), 'Audition must end first');
            let (token_contract_address, _): (ContractAddress, u256) = self
                .audition_prices
                .read(audition_id);

            assert(!token_contract_address.is_zero(), 'No prize for this audition');
            assert(!self.is_prize_distributed(audition_id), 'Prize already distributed');

            let winners_span = winners.span();
            let shares_span = shares.span();

            let mut total: u256 = 0;

            for shares in shares_span {
                total = total + *shares;
            }

            for winners in winners_span {
                assert(!winners.is_zero(), 'null contract address');
            }

            assert(total == 100, 'total does not add up');
        }

        // asserts that the judge has not been added to the audition already
        fn assert_judge_not_added(
            self: @ContractState, audition_id: felt252, judge_address: ContractAddress,
        ) {
            let judges = self.get_judges(audition_id);
            for judge in judges {
                assert(judge != judge_address, 'Judge already added');
            }
        }

        fn assert_judge_found(
            self: @ContractState, audition_id: felt252, judge_address: ContractAddress,
        ) {
            let judges: Array<ContractAddress> = self.get_judges(audition_id);

            let mut found = false;

            for judge in judges.clone() {
                if judge == judge_address {
                    found = true;
                    break;
                };
            }
            assert(found, 'Judge not found');
        }

        fn assert_only_judge(
            self: @ContractState, audition_id: felt252, judge_address: ContractAddress,
        ) {
            let judges = self.get_judges(audition_id);
            for judge in judges {
                assert(judge == judge_address, 'Judge not found');
            }
        }

        fn assert_evaluation_not_submitted(
            self: @ContractState, audition_id: felt252, performer: felt252, judge: ContractAddress,
        ) {
            let evaluation_submission_status = self
                .evaluation_submission_status
                .entry((audition_id, performer, judge))
                .read();
            assert(!evaluation_submission_status, 'Evaluation already submitted');
        }

        fn assert_evaluation_weight_should_be_100(self: @ContractState, weight: (u8, u8, u8)) {
            let (first_weight, second_weight, third_weight) = weight;
            let total = first_weight + second_weight + third_weight;
            assert(total == 100, 'Total weight should be 100');
        }
    }
}
