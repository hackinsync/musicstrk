#[starknet::contract]
pub mod SeasonAndAudition {
    use OwnableComponent::{HasComponent, InternalTrait};
    use contract_::audition::season_and_audition_interface::ISeasonAndAudition;
    use contract_::audition::season_and_audition_types::{
        Appeal, ArtistRegistration, Audition, Evaluation, Genre, RegistrationConfig, Season, Vote,
    };
    use contract_::errors::errors;
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::event::EventEmitter;
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::events::{
        AggregateScoreCalculated, AppealResolved, AppealSubmitted, AuditionCalculationCompleted,
        AuditionCreated, AuditionDeleted, AuditionEnded, AuditionPaused, AuditionResumed,
        AuditionUpdated, EvaluationSubmitted, EvaluationWeightSet, JudgeAdded, JudgeRemoved,
        OracleAdded, OracleRemoved, PausedAll, PriceDeposited, PriceDistributed,
        RegistrationConfigSet, ResultsSubmitted, ResumedAll, SeasonCreated, SeasonDeleted,
        SeasonEnded, SeasonPaused, SeasonResumed, SeasonUpdated, VoteRecorded,
    };

    // Integrates OpenZeppelin ownership component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // @notice the precision for the score
    const PRECISION: u256 = 100;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        whitelisted_oracles: Map<ContractAddress, bool>,
        seasons: Map<u256, Season>,
        season_count: u256,
        active_season: Option<u256>,
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
        /// @dev Map from audition_id to (u256, u256, u256) indicating the weight of each evaluation
        /// @dev NOTE: THE CRITERIA IS A TUPLE OF THE SCORE OF EACH EVALUATION: TECHNICAL SKILLS,
        /// CREATIVITY, AND PRESENTATION This is how it will be passed whenever it is being used in
        /// a tuple
        audition_evaluation_weight: Map<felt252, (u256, u256, u256)>,
        /// @notice aggregate score for each performer
        /// @dev Map audition and performer to u256 indicating the aggregate score for each
        /// performer
        performer_aggregate_score: Map<(felt252, felt252), u256>,
        /// @notice maps each audition to a list of aggregate scores
        /// @dev Map from audition_id to Vec<(felt252, u256)> containing performer id and aggregate
        /// scores
        audition_aggregate_scores: Map<felt252, Vec<(felt252, u256)>>,
        // @notice function fro audition calculation completed
        audition_calculation_completed: Map<felt252, bool>,
        /// @notice implementing this to register people to an audition
        /// so that the aggregate score calculation can be tested
        enrolled_performers: Map<felt252, Vec<felt252>>,
        performer_enrollment_status: Map<(felt252, felt252), bool>,
        registration_config: Map<felt252, Option<RegistrationConfig>>,
        appeals: Map<u256, Appeal>,
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
        AuditionCalculationCompleted: AuditionCalculationCompleted,
        AggregateScoreCalculated: AggregateScoreCalculated,
        AppealSubmitted: AppealSubmitted,
        AppealResolved: AppealResolved,
        SeasonPaused: SeasonPaused,
        SeasonResumed: SeasonResumed,
        SeasonEnded: SeasonEnded,
        RegistrationConfigSet: RegistrationConfigSet,
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
            ref self: ContractState, genre: Genre, name: felt252, start_time: u64, end_time: u64,
        ) {
            self.ownable.assert_only_owner();
            self.assert_all_seasons_closed();
            self.assert_valid_time(start_time, end_time);
            assert(!self.global_paused.read(), 'Contract is paused');
            let mut season_id: u256 = self.season_count.read() + 1;
            let new_season = Season {
                season_id,
                genre,
                name,
                start_timestamp: start_time,
                end_timestamp: end_time,
                last_updated_timestamp: get_block_timestamp(),
                paused: false,
                ended: false,
            };
            self.seasons.entry(season_id).write(new_season);
            self.season_count.write(season_id);
            self.active_season.write(Some(season_id));
            self
                .emit(
                    Event::SeasonCreated(
                        SeasonCreated {
                            season_id,
                            genre,
                            name,
                            start_timestamp: start_time,
                            end_timestamp: end_time,
                            last_updated_timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn read_season(self: @ContractState, season_id: u256) -> Season {
            self.seasons.entry(season_id).read()
        }

        fn update_season(
            ref self: ContractState,
            season_id: u256,
            genre: Option<Genre>,
            name: Option<felt252>,
            end_time: Option<u64>,
        ) {
            self.ownable.assert_only_owner();
            self.assert_valid_season(season_id);
            assert(!self.global_paused.read(), 'Contract is paused');

            let mut season = self.seasons.entry(season_id).read();
            if let Some(genre) = genre {
                season.genre = genre;
            }
            if let Some(name) = name {
                season.name = name;
            }
            if let Some(end_time) = end_time {
                season.end_timestamp = end_time;
            }
            season.last_updated_timestamp = get_block_timestamp();
            self.seasons.entry(season_id).write(season);
            self
                .emit(
                    Event::SeasonUpdated(
                        SeasonUpdated { season_id, last_updated_timestamp: get_block_timestamp() },
                    ),
                );
        }

        fn get_active_season(self: @ContractState) -> Option<u256> {
            self.active_season.read()
        }

        fn create_audition(
            ref self: ContractState,
            audition_id: felt252,
            season_id: u256,
            genre: Genre,
            name: felt252,
            start_timestamp: felt252,
            end_timestamp: felt252,
            paused: bool,
        ) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            self.assert_valid_season(season_id);
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
            self.assert_valid_season(audition.season_id);
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

        fn update_registration_config(
            ref self: ContractState, audition_id: felt252, config: RegistrationConfig,
        ) {
            self.ownable.assert_only_owner();
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition already ended');

            self.registration_config.entry(audition_id).write(Option::Some(config));
            let event = RegistrationConfigSet {
                audition_id,
                fee_amount: config.fee_amount,
                fee_token: config.fee_token,
                registration_open: config.registration_open,
                max_participants: config.max_participants,
            };

            self.emit(event);
        }

        fn get_registration_config(
            ref self: ContractState, audition_id: felt252,
        ) -> Option<RegistrationConfig> {
            let config = self.registration_config.entry(audition_id).read();
            if self.audition_exists(audition_id) {
                return if config.is_some() {
                    config
                } else {
                    let config: Option<RegistrationConfig> = Option::Some(Default::default());
                    self.registration_config.entry(audition_id).write(config);
                    config
                };
            }
            Option::None
        }

        fn delete_audition(ref self: ContractState, audition_id: felt252) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(!self.is_audition_paused(audition_id), 'Cannot delete paused audition');
            assert(!self.is_audition_ended(audition_id), 'Cannot delete ended audition');

            let default_audition: Audition = Default::default();
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);

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
            ref self: ContractState, audition_id: felt252, weight: (u256, u256, u256),
        ) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition has ended');
            assert(!self.is_audition_paused(audition_id), 'Audition is paused');
            self.assert_evaluation_weight_should_be_100(weight);
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);

            self.audition_evaluation_weight.write(audition_id, weight);
            self.emit(Event::EvaluationWeightSet(EvaluationWeightSet { audition_id, weight }));
        }

        /// @notice gets the weight of each evaluation for an audition
        /// @dev returns the weight of each evaluation for an audition
        /// @param audition_id the id of the audition to get the weight for
        /// @return a tupule of the weight of each evaluation
        fn get_evaluation_weight(self: @ContractState, audition_id: felt252) -> (u256, u256, u256) {
            let (technical_weight, creativity_weight, presentation_weight) = self
                .audition_evaluation_weight
                .read(audition_id);
            if technical_weight == 0 && creativity_weight == 0 && presentation_weight == 0 {
                (40, 30, 30)
            } else {
                (technical_weight, creativity_weight, presentation_weight)
            }
        }

        fn perform_aggregate_score_calculation(ref self: ContractState, audition_id: felt252) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(self.is_audition_ended(audition_id), 'Audition has not ended');
            assert(!self.is_audition_paused(audition_id), 'Audition is paused');
            self.assert_all_players_have_been_evaluated(audition_id);
            assert(
                !self.audition_calculation_completed.read(audition_id), 'Audition calculation done',
            );
            let audition = self.auditions.entry(audition_id).read();
            assert(self.season_exists(audition.season_id), 'Season does not exist');
            assert(!self.is_season_paused(audition.season_id), 'Season is paused');
            let (technical_weight, creativity_weight, presentation_weight) = self
                .get_evaluation_weight(audition_id);

            let all_performers: Array<felt252> = self.get_enrolled_performers(audition_id);
            let mut aggregate_scores: Array<(felt252, u256)> = ArrayTrait::<(felt252, u256)>::new();
            for performer in all_performers {
                let all_evaluations_for_performer: Array<Evaluation> = self
                    .get_evaluation(audition_id, performer);

                let mut total_score: u256 = 0;
                let num_judges: u256 = all_evaluations_for_performer.len().try_into().unwrap();

                for evaluation in all_evaluations_for_performer {
                    let (technical_score, creativity_score, presentation_score) = evaluation
                        .criteria;
                    let weighted_score: u256 = ((technical_score * technical_weight
                        + creativity_score * creativity_weight
                        + presentation_score * presentation_weight)
                        / PRECISION)
                        .try_into()
                        .unwrap();
                    total_score += weighted_score;
                }

                let average_final_score: u256 = total_score / num_judges;

                self
                    .audition_aggregate_scores
                    .entry(audition_id)
                    .push((performer, average_final_score));
                self.performer_aggregate_score.write((audition_id, performer), average_final_score);
                aggregate_scores.append((performer, average_final_score));
            }
            self.audition_calculation_completed.write(audition_id, true);
            self
                .emit(
                    Event::AuditionCalculationCompleted(
                        AuditionCalculationCompleted { audition_id },
                    ),
                );
            self
                .emit(
                    Event::AggregateScoreCalculated(
                        AggregateScoreCalculated {
                            audition_id, aggregate_scores, timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn get_aggregate_score(
            self: @ContractState, audition_id: felt252,
        ) -> Array<(felt252, u256)> {
            let mut aggregate_score_array = ArrayTrait::<(felt252, u256)>::new();
            let storage_vec = self.audition_aggregate_scores.entry(audition_id);
            for i in 0..storage_vec.len() {
                let (performer_id, aggregate_score) = storage_vec.at(i).read();
                aggregate_score_array.append((performer_id, aggregate_score));
            }
            aggregate_score_array
        }

        fn get_aggregate_score_for_performer(
            self: @ContractState, audition_id: felt252, performer_id: felt252,
        ) -> u256 {
            self.performer_aggregate_score.read((audition_id, performer_id))
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
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);

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
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);

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
            criteria: (u256, u256, u256),
        ) {
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(!self.judging_paused.read(), 'Judging is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition has ended');
            assert(!self.is_audition_paused(audition_id), 'Audition is paused');
            let judge = get_caller_address();
            self.assert_judge_found(audition_id, judge);
            self.assert_evaluation_not_submitted(audition_id, performer, judge);
            self.assert_judge_point_is_not_more_than_10(criteria);
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);

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
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);

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
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);
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
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);

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
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);
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


        fn pause_season(ref self: ContractState, season_id: u256) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            self.assert_valid_season(season_id);
            let mut season = self.seasons.entry(season_id).read();
            season.paused = true;
            season.last_updated_timestamp = get_block_timestamp();
            self.seasons.entry(season_id).write(season);
            self
                .emit(
                    Event::SeasonPaused(
                        SeasonPaused { season_id, last_updated_timestamp: get_block_timestamp() },
                    ),
                );
        }
        fn resume_season(ref self: ContractState, season_id: u256) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.season_exists(season_id), 'Season does not exist');
            let mut season = self.seasons.entry(season_id).read();
            assert(season.paused, 'Season is not paused');
            season.paused = false;
            season.last_updated_timestamp = get_block_timestamp();
            self.seasons.entry(season_id).write(season);
            self
                .emit(
                    Event::SeasonResumed(
                        SeasonResumed { season_id, last_updated_timestamp: get_block_timestamp() },
                    ),
                );
        }

        fn is_season_paused(self: @ContractState, season_id: u256) -> bool {
            let mut season = self.seasons.entry(season_id).read();
            season.paused
        }

        fn is_season_ended(self: @ContractState, season_id: u256) -> bool {
            let mut season = self.seasons.entry(season_id).read();
            let current_time = get_block_timestamp();
            if season.end_timestamp != 0 {
                let end_time_u64: u64 = season.end_timestamp;
                let current_time_u64: u64 = current_time;

                current_time_u64 >= end_time_u64
            } else {
                false
            }
        }

        fn season_exists(self: @ContractState, season_id: u256) -> bool {
            let season = self.seasons.entry(season_id).read();
            season.season_id != 0
        }

        fn end_season(ref self: ContractState, season_id: u256) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.season_exists(season_id), 'Season does not exist');
            assert(self.is_season_ended(season_id), 'Season has not ended');
            let mut season = self.seasons.entry(season_id).read();
            season.ended = true;
            season.paused = false;
            season.last_updated_timestamp = get_block_timestamp();
            self.active_season.write(None);
            self.seasons.entry(season_id).write(season);
            self
                .emit(
                    Event::SeasonEnded(
                        SeasonEnded { season_id, last_updated_timestamp: get_block_timestamp() },
                    ),
                );
        }


        // dummy implementation to register a performer to an audition
        fn register_performer(
            ref self: ContractState, audition_id: felt252, performer_id: felt252,
        ) {
            let has_registered = self
                .performer_enrollment_status
                .entry((audition_id, performer_id))
                .read();
            assert(!has_registered, 'Performer has registered');

            self.enrolled_performers.entry(audition_id).push(performer_id);
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);
            self.performer_enrollment_status.entry((audition_id, performer_id)).write(true);
        }

        // dummy implementation to get the enrolled performers for an audition
        fn get_enrolled_performers(self: @ContractState, audition_id: felt252) -> Array<felt252> {
            let mut performers_array = ArrayTrait::<felt252>::new();
            let enrolled_performers = self.enrolled_performers.entry(audition_id);
            for i in 0..enrolled_performers.len() {
                let performer = enrolled_performers.at(i).read();
                performers_array.append(performer);
            }
            performers_array
        }

        fn submit_appeal(ref self: ContractState, evaluation_id: u256, reason: felt252) {
            let appellant = get_caller_address();
            let _ = self.evaluations.entry(evaluation_id).read();
            let existing_appeal = self.appeals.entry(evaluation_id).read();
            assert(existing_appeal.evaluation_id == 0, 'Appeal already exists');
            let evaulation: Evaluation = self.evaluations.entry(evaluation_id).read();
            let audition = self.auditions.entry(evaulation.audition_id).read();
            self.assert_valid_season(audition.season_id);
            let appeal = Appeal {
                evaluation_id, appellant, reason, resolved: false, resolution_comment: 0,
            };
            self.appeals.write(evaluation_id, appeal);
            self.emit(Event::AppealSubmitted(AppealSubmitted { evaluation_id, appellant, reason }));
        }
        fn resolve_appeal(
            ref self: ContractState, evaluation_id: u256, resolution_comment: felt252,
        ) {
            let resolver = starknet::get_caller_address();
            // Only owner or judge can resolve
            let evaluation = self.evaluations.entry(evaluation_id).read();
            let audition_id = evaluation.audition_id;
            self.ownable.assert_only_owner();
            let mut is_judge = false;
            let judges = self.get_judges(audition_id);
            for judge in judges {
                if judge == resolver {
                    is_judge = true;
                    break;
                }
            }
            let mut appeal = self.appeals.entry(evaluation_id).read();
            assert(appeal.evaluation_id != 0, 'Appeal does not exist');
            assert(!appeal.resolved, 'Appeal already resolved');
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);
            appeal.resolved = true;
            appeal.resolution_comment = resolution_comment;
            self.appeals.write(evaluation_id, appeal);
            self
                .emit(
                    Event::AppealResolved(
                        AppealResolved { evaluation_id, resolver, resolution_comment },
                    ),
                );
        }
        fn get_appeal(self: @ContractState, evaluation_id: u256) -> Appeal {
            self.appeals.entry(evaluation_id).read()
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

        fn assert_evaluation_weight_should_be_100(
            self: @ContractState, weight: (u256, u256, u256),
        ) {
            let (first_weight, second_weight, third_weight) = weight;
            let total = first_weight + second_weight + third_weight;
            assert(total == 100, 'Total weight should be 100');
        }

        fn assert_judge_point_is_not_more_than_10(self: @ContractState, point: (u256, u256, u256)) {
            let (first_point, second_point, third_point) = point;
            assert(first_point <= 10, 'Should be less than 10');
            assert(second_point <= 10, 'Should be less than 10');
            assert(third_point <= 10, 'Should be less than 10');
        }

        fn assert_all_players_have_been_evaluated(self: @ContractState, audition_id: felt252) {
            let enrolled_performers: Array<felt252> = self.get_enrolled_performers(audition_id);
            let judges_len: u32 = self.get_judges(audition_id).len();
            for performer in enrolled_performers {
                let performers_evaluations_len: u32 = self
                    .get_evaluation(audition_id, performer)
                    .len();
                assert(performers_evaluations_len == judges_len, 'All players should be evaluated');
            }
        }

        /// @dev Asserts that the season exists, is not paused, and has not ended.
        /// @param season_id The ID of the season to check.
        /// @custom:reverts If the season does not exist.
        /// @custom:reverts If the season is paused.
        /// @custom:reverts If the season has already ended.
        /// @custom:reverts If the contract is paused.
        fn assert_valid_season(self: @ContractState, season_id: u256) {
            assert(self.season_exists(season_id), 'Season does not exist');
            assert(!self.is_season_paused(season_id), 'Season is paused');
            assert(!self.is_season_ended(season_id), 'Season has already ended');
        }

        fn assert_all_seasons_closed(self: @ContractState) {
            let active_season = self.active_season.read();
            assert(active_season.is_none(), 'A Season is active');
        }

        fn assert_valid_time(self: @ContractState, start_time: u64, end_time: u64) {
            assert(start_time < end_time, 'invalid start time');
        }
    }
}
