#[starknet::contract]
pub mod SeasonAndAudition {
    use OwnableComponent::InternalTrait;
    use contract_::audition::interfaces::iseason_and_audition::ISeasonAndAudition;
    use contract_::audition::types::season_and_audition::{
        Appeal, ArtistRegistration, Audition, Evaluation, Genre, RegistrationConfig, Season, Vote,
    };
    use contract_::errors::errors;
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::event::EventEmitter;
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::events::{
        AggregateScoreCalculated, AppealResolved, AppealSubmitted, ArtistRegistered,
        AuditionCalculationCompleted, AuditionCreated, AuditionDeleted, AuditionEnded,
        AuditionPaused, AuditionResumed, AuditionUpdated, DisputeRaised, DisputeResolved,
        EvaluationSubmitted, EvaluationWeightSet, FundsEscrowed, FundsReleased, JudgeAdded,
        JudgeRemoved, OracleAdded, OracleRemoved, PausedAll, PaymentRecorded,
        PaymentSplitDistributed, PlatformFeeCollected, PriceDeposited, PriceDistributed,
        RefundProcessed, RegistrationConfigSet, ResultSubmitted, ResultsSubmitted, ResumedAll,
        SeasonCreated, SeasonDeleted, SeasonEnded, SeasonPaused, SeasonResumed, SeasonUpdated,
        VoteRecorded,
    };

    // Integrates OpenZeppelin ownership component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // @notice the precision for the score
    const PRECISION: u256 = 100;

    const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");
    const SEASON_MAINTAINER_ROLE: felt252 = selector!("SEASON_MAINTAINER_ROLE");
    const AUDITION_MAINTAINER_ROLE: felt252 = selector!("AUDITION_MAINTAINER_ROLE");
    const REVIEWER_ROLE: felt252 = selector!("REVIEWER_ROLE");

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        whitelisted_oracles: Map<ContractAddress, bool>,
        seasons: Map<u256, Season>,
        season_count: u256,
        active_season: Option<u256>,
        auditions: Map<u256, Audition>,
        audition_count: u256,
        votes: Map<(u256, ContractAddress, ContractAddress), Vote>,
        global_paused: bool,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        // @notice this storage is a mapping of the audition rpices deposited by the audition
        // owners, Map<audition_id, (token contract address  , amount of the token set as the
        // price)>
        audition_prices: Map<u256, (ContractAddress, u256)>,
        /// @notice Maps each audition ID to the winner addresses for that audition.
        /// @dev The value is a tuple containing the addresses of the first, second, and third place
        /// winners.
        /// @param audition_winner_addresses Mapping from audition ID (felt252) to a tuple of winner
        /// addresses (ContractAddress, ContractAddress, ContractAddress).
        audition_winner_addresses: Map<u256, Vec<ContractAddress>>,
        /// @notice Maps each audition ID to the prize amounts for the winners.
        /// @dev The value is a tuple containing the prize amounts for the first, second, and third
        /// place winners, respectively.
        /// @param audition_winner_amounts Mapping from audition ID (felt252) to a tuple of prize
        /// amounts (u256, u256, u256).
        audition_winner_amounts: Map<u256, Vec<u256>>,
        /// price distributed status
        price_distributed: Map<u256, bool>,
        /// @notice maps each audition id to a list of judges
        /// @dev a vec containing all judges contract addresses
        audition_judge: Map<u256, Vec<ContractAddress>>,
        /// @notice maps each audition id to a list of evaluation id
        /// @dev a vec containing all evaluation ids
        audition_evaluations: Map<u256, Vec<u256>>,
        /// @notice maps each audition id and performer id to a list of evaluation id for a specific
        /// performer @dev a vec containing all evaluation ids for a specific performer
        audition_evaluations_for_performer: Map<(u256, u256), Vec<u256>>,
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
        evaluation_submission_status: Map<(u256, u256, ContractAddress), bool>,
        /// @notice maps each audition to the weight of each evaluation
        /// @dev Map from audition_id to (u256, u256, u256) indicating the weight of each evaluation
        /// @dev NOTE: THE CRITERIA IS A TUPLE OF THE SCORE OF EACH EVALUATION: TECHNICAL SKILLS,
        /// CREATIVITY, AND PRESENTATION This is how it will be passed whenever it is being used in
        /// a tuple
        audition_evaluation_weight: Map<u256, (u256, u256, u256)>,
        /// @notice aggregate score for each performer
        /// @dev Map audition and performer to u256 indicating the aggregate score for each
        /// performer
        performer_aggregate_score: Map<(u256, u256), u256>,
        /// @notice maps each audition to a list of aggregate scores
        /// @dev Map from audition_id to Vec<(felt252, u256)> containing performer id and aggregate
        /// scores
        audition_aggregate_scores: Map<u256, Vec<(u256, u256)>>,
        // @notice function fro audition calculation completed
        audition_calculation_completed: Map<u256, bool>,
        /// @notice implementing this to register people to an audition
        /// so that the aggregate score calculation can be tested
        enrolled_performers: Map<u256, Vec<u256>>,
        performer_enrollment_status: Map<(u256, u256), bool>,
        registration_config: Map<u256, Option<RegistrationConfig>>,
        /// @notice a Map of audition id to a bool of whether the registration has started or not.
        /// once started, updating a config of this audition fails.
        registration_started: Map<u256, bool>,
        /// @notice a Map of a (Performer's address, audition_id) to the performer id, use for ease
        /// of reading the id. Thus if the id is zero, the performer has not registered.
        performer_has_registered: Map<(ContractAddress, u256), u256>,
        /// @notice a map of the audition id, performer id and caller address
        performer_audition_address: Map<(u256, u256), ContractAddress>,
        /// @notice performer count per audition id.
        performer_count: Map<u256, u256>,
        registered_artists: Map<(ContractAddress, u256), ArtistRegistration>,
        appeals: Map<u256, Appeal>,
        /// @notice maps each audition and performer to a bool indicating if the performer has
        /// submitted the result @dev Map from (audition_id, performer_id) to bool indicating if the
        /// performer has submitted the result
        performer_result_submission_status: Map<(u256, u256), bool>,
        /// @notice maps each audition and performer to a result uri
        /// @dev Map from (audition_id, performer_id) to result uri
        performer_result: Map<(u256, u256), ByteArray>,
        /// @notice list of submitted results for an audition
        /// @dev List of (audition_id, result_uri)
        submitted_results: Map<u256, Vec<ByteArray>>,
        /// @notice list of all results for a perfomer
        /// @dev List of (performer_id, result_uri)
        performer_results: Map<u256, Vec<ByteArray>>,
        /// @notice maps a (auditon_id, performer_id) to performer address
        /// @dev (u256, u256) -> ContractAddress
        performer_registry: Map<(u256, u256), ContractAddress>,
        /// @notice a count of performer
        performers_count: u256,
        /// @notice mapping to know weather price has been deposited for an audition
        audition_price_deposited: Map<u256, bool>,
        // Payment infrastructure storage
        /// @notice escrow balances for auditions: (audition_id, token_address) -> amount
        escrow_balance: Map<(u256, ContractAddress), u256>,
        /// @notice platform fee percentage (e.g., 500 = 5%)
        platform_fee_percentage: u256,
        /// @notice payment history: list of (audition_id, token, amount, timestamp, action_type)
        payment_history: List<(u256, ContractAddress, u256, u64, felt252)>,
        /// @notice dispute status for auditions
        dispute_status: Map<u256, bool>,
        /// @notice participant shares for payment splitting: audition_id -> vec of (participant, share_percentage)
        participant_shares: Map<u256, Vec<(ContractAddress, u256)>>,
        /// @notice collected platform fees: token_address -> amount
        platform_fees_collected: Map<ContractAddress, u256>,
        /// @notice refund requests: (audition_id, user) -> amount_requested
        refund_requests: Map<(u256, ContractAddress), u256>,
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
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
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
        ArtistRegistered: ArtistRegistered,
        ResultSubmitted: ResultSubmitted,
        // Payment infrastructure events
        FundsEscrowed: FundsEscrowed,
        FundsReleased: FundsReleased,
        RefundProcessed: RefundProcessed,
        PlatformFeeCollected: PlatformFeeCollected,
        PaymentSplitDistributed: PaymentSplitDistributed,
        DisputeRaised: DisputeRaised,
        DisputeResolved: DisputeResolved,
        PaymentRecorded: PaymentRecorded,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.global_paused.write(false);
        self.judging_paused.write(false);
        self.platform_fee_percentage.write(500); // Default 5% platform fee
        self.accesscontrol.initializer();
        self.accesscontrol.set_role_admin(SEASON_MAINTAINER_ROLE, ADMIN_ROLE);
        self.accesscontrol.set_role_admin(AUDITION_MAINTAINER_ROLE, ADMIN_ROLE);
        self.accesscontrol.set_role_admin(REVIEWER_ROLE, ADMIN_ROLE);
        self.accesscontrol._grant_role(ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(SEASON_MAINTAINER_ROLE, owner);
        self.accesscontrol._grant_role(AUDITION_MAINTAINER_ROLE, owner);
        self.accesscontrol._grant_role(REVIEWER_ROLE, owner);
    }

    #[abi(embed_v0)]
    impl ISeasonAndAuditionImpl of ISeasonAndAudition<ContractState> {
        fn create_season(ref self: ContractState, name: felt252, start_time: u64, end_time: u64) {
            self.accesscontrol.assert_only_role(SEASON_MAINTAINER_ROLE);
            self.assert_all_seasons_closed();
            self.assert_valid_time(start_time, end_time);
            assert(!self.global_paused.read(), 'Contract is paused');
            let mut season_id: u256 = self.season_count.read() + 1;
            let new_season = Season {
                season_id,
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
            ref self: ContractState, season_id: u256, name: Option<felt252>, end_time: Option<u64>,
        ) {
            self.accesscontrol.assert_only_role(SEASON_MAINTAINER_ROLE);
            self.assert_valid_season(season_id);
            assert(!self.global_paused.read(), 'Contract is paused');

            let mut season = self.seasons.entry(season_id).read();
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
            ref self: ContractState, name: felt252, genre: Genre, end_timestamp: u64,
        ) {
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
            assert(!self.global_paused.read(), 'Contract is paused');
            let season_id = self.active_season.read().expect('No active season');
            self.assert_valid_season(season_id);
            let audition_id = self.audition_count.read() + 1;
            self.audition_count.write(audition_id);
            self
                .auditions
                .entry(audition_id)
                .write(
                    Audition {
                        audition_id,
                        season_id,
                        name,
                        genre,
                        start_timestamp: get_block_timestamp(),
                        end_timestamp,
                        paused: false,
                    },
                );

            self
                .emit(
                    Event::AuditionCreated(
                        AuditionCreated { audition_id, season_id, name, genre, end_timestamp },
                    ),
                );
        }

        fn read_audition(self: @ContractState, audition_id: u256) -> Audition {
            self.auditions.entry(audition_id).read()
        }

        fn update_audition_details(
            ref self: ContractState,
            audition_id: u256,
            new_time: Option<u64>,
            name: Option<felt252>,
            genre: Option<Genre>,
        ) {
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
            assert(!self.global_paused.read(), 'Contract is paused');
            self.assert_valid_audition(audition_id);
            let mut audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);
            if let Some(new_time) = new_time {
                self.assert_valid_update_time(audition_id, new_time);
                audition.end_timestamp = new_time;
            }
            if let Some(name) = name {
                self.assert_audition_hasnt_gone_halfway(audition_id);
                audition.name = name;
            }
            if let Some(genre) = genre {
                self.assert_audition_hasnt_gone_halfway(audition_id);
                audition.genre = genre;
            }
            self.auditions.entry(audition_id).write(audition);
            self
                .emit(
                    Event::AuditionUpdated(
                        AuditionUpdated {
                            audition_id,
                            end_timestamp: audition.end_timestamp,
                            name: audition.name,
                            genre: audition.genre,
                        },
                    ),
                );
        }

        fn update_registration_config(
            ref self: ContractState, audition_id: u256, config: RegistrationConfig,
        ) {
            self.accesscontrol.assert_only_role(SEASON_MAINTAINER_ROLE);
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition already ended');
            assert(!self.registration_started.entry(audition_id).read(), 'Registration Started');
            let prev = self.registration_config.entry(audition_id).read();
            let mut new = prev.unwrap_or_default();

            let RegistrationConfig {
                fee_amount, fee_token, registration_open, max_participants,
            } = config;
            if fee_token.is_non_zero() {
                new.fee_token = fee_token;
                if fee_amount.is_non_zero() {
                    new.fee_amount = fee_amount;
                } else {
                    new.fee_amount = 0;
                }
            }
            new.registration_open = registration_open;
            new.max_participants = max_participants;

            self.registration_config.entry(audition_id).write(Option::Some(new));
            let event = RegistrationConfigSet {
                audition_id,
                fee_amount,
                fee_token: new.fee_token,
                registration_open,
                max_participants,
            };
            self.emit(event);
        }

        fn get_registration_config(
            ref self: ContractState, audition_id: u256,
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

        /// seems this function is no longer available in the upstream, so I'm just commenting it
        /// out
        // fn delete_audition(ref self: ContractState, audition_id: u256) {
        //     self.ownable.assert_only_owner();
        //     assert(!self.global_paused.read(), 'Contract is paused');
        //     assert(!self.is_audition_paused(audition_id), 'Cannot delete paused audition');
        //     assert(!self.is_audition_ended(audition_id), 'Cannot delete ended audition');

        //     let default_audition: Audition = Default::default();
        //     let audition = self.auditions.entry(audition_id).read();
        //     self.assert_valid_season(audition.season_id);

        //     self.auditions.entry(audition_id).write(default_audition);
        //     self
        //         .emit(
        //             Event::AuditionDeleted(
        //                 AuditionDeleted { audition_id, end_timestamp: get_block_timestamp() },
        //             ),
        //         );
        // }

        /// @notice sets the weight of each evaluation for an audition
        /// @dev only the owner can set the weight of each evaluation
        /// @param audition_id the id of the audition to set the weight for
        /// @param weight the weight of each evaluation
        fn set_evaluation_weight(
            ref self: ContractState, audition_id: u256, weight: (u256, u256, u256),
        ) {
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
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
        fn get_evaluation_weight(self: @ContractState, audition_id: u256) -> (u256, u256, u256) {
            let (technical_weight, creativity_weight, presentation_weight) = self
                .audition_evaluation_weight
                .read(audition_id);
            if technical_weight == 0 && creativity_weight == 0 && presentation_weight == 0 {
                (40, 30, 30)
            } else {
                (technical_weight, creativity_weight, presentation_weight)
            }
        }

        fn perform_aggregate_score_calculation(ref self: ContractState, audition_id: u256) {
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
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

            let all_performers: Array<u256> = self.get_enrolled_performers(audition_id);
            let mut aggregate_scores: Array<(u256, u256)> = ArrayTrait::<(u256, u256)>::new();
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

        fn get_aggregate_score(self: @ContractState, audition_id: u256) -> Array<(u256, u256)> {
            let mut aggregate_score_array = ArrayTrait::<(u256, u256)>::new();
            let storage_vec = self.audition_aggregate_scores.entry(audition_id);
            for i in 0..storage_vec.len() {
                let (performer_id, aggregate_score) = storage_vec.at(i).read();
                aggregate_score_array.append((performer_id, aggregate_score));
            }
            aggregate_score_array
        }

        fn get_aggregate_score_for_performer(
            self: @ContractState, audition_id: u256, performer_id: u256,
        ) -> u256 {
            self.performer_aggregate_score.read((audition_id, performer_id))
        }


        /// @notice adds a judge to an audition
        /// @dev only the owner can add a judge to an audition
        /// @param audition_id the id of the audition to add the judge to
        /// @param judge_address the address of the judge to add
        fn add_judge(ref self: ContractState, audition_id: u256, judge_address: ContractAddress) {
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
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
            ref self: ContractState, audition_id: u256, judge_address: ContractAddress,
        ) {
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
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
        fn get_judges(self: @ContractState, audition_id: u256) -> Array<ContractAddress> {
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
        /// @param performer_id the id of the performer to submit the evaluation for
        /// @param weight the weight of the evaluation
        /// @param criteria the criteria of the evaluation
        fn submit_evaluation(
            ref self: ContractState,
            audition_id: u256,
            performer_id: u256,
            criteria: (u256, u256, u256),
        ) {
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(!self.judging_paused.read(), 'Judging is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition has ended');
            assert(!self.is_audition_paused(audition_id), 'Audition is paused');
            let judge = get_caller_address();
            self.assert_judge_found(audition_id, judge);
            self.assert_evaluation_not_submitted(audition_id, performer_id, judge);
            self.assert_judge_point_is_not_more_than_10(criteria);
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);

            self.evaluation_submission_status.write((audition_id, performer_id, judge), true);
            let mut new_evaluation_id = self.evaluation_count.read() + 1;
            self.evaluation_count.write(new_evaluation_id);

            let performer = self.performer_registry.entry((audition_id, performer_id)).read();

            self
                .evaluations
                .entry(new_evaluation_id)
                .write(Evaluation { audition_id, performer, criteria });

            self.audition_evaluations.entry(audition_id).push(new_evaluation_id);
            self
                .audition_evaluations_for_performer
                .entry((audition_id, performer_id))
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
        /// @param performer_id the id of the performer to get the evaluation for
        /// @return the evaluation for the performer
        fn get_evaluation(
            self: @ContractState, audition_id: u256, performer_id: u256,
        ) -> Array<Evaluation> {
            let evaluation_ids = self
                .audition_evaluations_for_performer
                .entry((audition_id, performer_id));
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
        fn get_evaluations(self: @ContractState, audition_id: u256) -> Array<Evaluation> {
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
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
            self.judging_paused.write(true);
        }

        fn resume_judging(ref self: ContractState) {
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
            self.judging_paused.write(false);
        }

        fn is_judging_paused(self: @ContractState) -> bool {
            self.judging_paused.read()
        }


        fn submit_result(
            ref self: ContractState, audition_id: u256, result_uri: ByteArray, performer_id: u256,
        ) {
            self.accesscontrol.assert_only_role(REVIEWER_ROLE);
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);
            assert(!self.global_paused.read(), 'Contract is paused');
            let is_performer_enrolled = self
                .performer_enrollment_status
                .entry((audition_id, performer_id))
                .read();
            assert(is_performer_enrolled, 'Performer is not enrolled');
            let is_performer_result_submitted = self
                .performer_result_submission_status
                .entry((audition_id, performer_id))
                .read();
            assert(!is_performer_result_submitted, 'Performer already submitted');
            self.performer_result_submission_status.write((audition_id, performer_id), true);
            self.performer_result.write((audition_id, performer_id), result_uri.clone());
            self.submitted_results.entry(audition_id).push(result_uri.clone());
            self.performer_results.entry(performer_id).push(result_uri.clone());
            let performer = self.performer_registry.entry((audition_id, performer_id)).read();
            self
                .emit(
                    Event::ResultSubmitted(ResultSubmitted { audition_id, result_uri, performer }),
                );
        }

        fn get_result(self: @ContractState, audition_id: u256, performer_id: u256) -> ByteArray {
            self.performer_result.read((audition_id, performer_id))
        }
        /// @notice Gets the results of an audition.
        fn get_results(self: @ContractState, audition_id: u256) -> Array<ByteArray> {
            let mut results = ArrayTrait::new();
            for i in 0..self.submitted_results.entry(audition_id).len() {
                let result = self.submitted_results.entry(audition_id).at(i).read();
                results.append(result);
            }
            results
        }
        /// @notice Gets the results of a performer for an audition.
        fn get_performer_results(self: @ContractState, performer_id: u256) -> Array<ByteArray> {
            let mut results = ArrayTrait::new();
            for i in 0..self.performer_results.entry(performer_id).len() {
                let result = self.performer_results.entry(performer_id).at(i).read();
                results.append(result);
            }
            results
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
            audition_id: u256,
            token_address: ContractAddress,
            amount: u256,
        ) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition has already ended');
            assert(amount > 0, 'Amount must be more than zero');
            assert(!token_address.is_zero(), 'Token address cannot be zero');
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);

            assert!(
                !self.audition_price_deposited.entry(audition_id).read(), "Prize already deposited",
            );
            self._process_payment(amount, token_address);
            self.audition_prices.write(audition_id, (token_address, amount));
            self.audition_price_deposited.entry(audition_id).write(true);
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
        fn get_audition_prices(self: @ContractState, audition_id: u256) -> (ContractAddress, u256) {
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
        /// for each winner.
        /// @custom:reverts If the distribution conditions are not met, as checked by
        /// `assert_distributed`.
        fn distribute_prize(ref self: ContractState, audition_id: u256, shares: Array<u256>) {
            let winners: Array<ContractAddress> = self.get_top_winners(audition_id, shares.len());
            self.assert_distributed(audition_id, winners.clone(), shares.clone());
            let audition = self.auditions.entry(audition_id).read();
            assert(self.season_exists(audition.season_id), 'Season does not exist');
            assert(!self.is_season_paused(audition.season_id), 'Season is paused');
            let (token_contract_address, price_pool): (ContractAddress, u256) = self
                .audition_prices
                .read(audition_id);
            assert(
                self.audition_price_deposited.entry(audition_id).read(),
                'No prize for this audition',
            );
            let winners_span: Span<ContractAddress> = winners.into();
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
                self.audition_winner_amounts.entry(audition_id).push(amount);
                self.audition_winner_addresses.entry(audition_id).push(winner_contract_address)
            }
            self.price_distributed.write(audition_id, true);
            self
                .emit(
                    Event::PriceDistributed(
                        PriceDistributed {
                            audition_id,
                            winners: winners_span,
                            shares: shares_span,
                            token_address: token_contract_address,
                            amounts: distributed_amounts.span(),
                        },
                    ),
                );
        }

        fn get_audition_winner_addresses(
            self: @ContractState, audition_id: u256,
        ) -> Array<ContractAddress> {
            let mut array_audition_winner_addresses: Array<ContractAddress> = array![];
            for i in 0..self.audition_winner_addresses.entry(audition_id).len() {
                array_audition_winner_addresses
                    .append(self.audition_winner_addresses.entry(audition_id).at(i).read());
            }
            array_audition_winner_addresses
        }


        fn get_audition_winner_amounts(self: @ContractState, audition_id: u256) -> Array<u256> {
            let mut array_audition_winner_amounts: Array<u256> = array![];
            for i in 0..self.audition_winner_amounts.entry(audition_id).len() {
                array_audition_winner_amounts
                    .append(self.audition_winner_amounts.entry(audition_id).at(i).read());
            }
            array_audition_winner_amounts
        }

        fn is_prize_distributed(self: @ContractState, audition_id: u256) -> bool {
            self.price_distributed.read(audition_id)
        }

        // Payment infrastructure functions
        fn deposit_to_escrow(
            ref self: ContractState,
            audition_id: u256,
            token: ContractAddress,
            amount: u256,
        ) {
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(amount > 0, 'Amount must be greater than zero');
            let caller = get_caller_address();
            let dispatcher = IERC20Dispatcher { contract_address: token };
            assert(dispatcher.balance_of(caller) >= amount, 'Insufficient balance');
            assert(dispatcher.allowance(caller, get_contract_address()) >= amount, 'Insufficient allowance');

            // Transfer tokens to contract
            dispatcher.transfer_from(caller, get_contract_address(), amount);

            // Update escrow balance
            let current_balance = self.escrow_balance.read((audition_id, token));
            self.escrow_balance.write((audition_id, token), current_balance + amount);

            // Record payment history
            self.payment_history.append((audition_id, token, amount, get_block_timestamp(), 'escrow_deposit'));

            self.emit(Event::FundsEscrowed(FundsEscrowed {
                audition_id,
                user: caller,
                token,
                amount,
                timestamp: get_block_timestamp(),
            }));
        }

        fn release_escrow_funds(
            ref self: ContractState,
            audition_id: u256,
            recipients: Array<ContractAddress>,
            amounts: Array<u256>,
            token: ContractAddress,
        ) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.dispute_status.read(audition_id), 'Audition in dispute');
            assert(recipients.len() == amounts.len(), 'Recipients and amounts length mismatch');

            let mut total_release = 0;
            let mut i = 0;
            while i < amounts.len() {
                total_release += *amounts.at(i);
                i += 1;
            };

            let escrow_balance = self.escrow_balance.read((audition_id, token));
            assert(escrow_balance >= total_release, 'Insufficient escrow balance');

            // Deduct platform fee
            let platform_fee = (total_release * self.platform_fee_percentage.read()) / 10000; // Assuming percentage is in basis points
            let net_release = total_release - platform_fee;

            // Update platform fees collected
            let current_fees = self.platform_fees_collected.read(token);
            self.platform_fees_collected.write(token, current_fees + platform_fee);

            // Release funds proportionally
            let mut remaining = net_release;
            i = 0;
            while i < recipients.len() {
                let recipient = *recipients.at(i);
                let amount = *amounts.at(i);
                self._send_tokens(recipient, amount, token);
                self.payment_history.append((audition_id, token, amount, get_block_timestamp(), 'escrow_release'));
                self.emit(Event::FundsReleased(FundsReleased {
                    audition_id,
                    recipient,
                    token,
                    amount,
                    timestamp: get_block_timestamp(),
                }));
                i += 1;
            };

            // Update escrow balance
            self.escrow_balance.write((audition_id, token), escrow_balance - total_release);

            self.emit(Event::PlatformFeeCollected(PlatformFeeCollected {
                token,
                amount: platform_fee,
                timestamp: get_block_timestamp(),
            }));
        }

        fn process_refund(
            ref self: ContractState,
            audition_id: u256,
            user: ContractAddress,
            token: ContractAddress,
        ) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            // Assume refund is allowed if audition is cancelled or failed

            let escrow_balance = self.escrow_balance.read((audition_id, token));
            assert(escrow_balance > 0, 'No funds to refund');

            // For simplicity, refund full escrow balance to user
            self._send_tokens(user, escrow_balance, token);
            self.escrow_balance.write((audition_id, token), 0);

            self.payment_history.append((audition_id, token, escrow_balance, get_block_timestamp(), 'refund'));

            self.emit(Event::RefundProcessed(RefundProcessed {
                audition_id,
                user,
                token,
                amount: escrow_balance,
                timestamp: get_block_timestamp(),
            }));
        }

        fn set_platform_fee(ref self: ContractState, percentage: u256) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(percentage <= 10000, 'Fee percentage too high'); // Max 100%
            self.platform_fee_percentage.write(percentage);
        }

        fn get_platform_fee(self: @ContractState) -> u256 {
            self.platform_fee_percentage.read()
        }

        fn set_participant_shares(
            ref self: ContractState,
            audition_id: u256,
            participants: Array<ContractAddress>,
            shares: Array<u256>,
        ) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(participants.len() == shares.len(), 'Participants and shares length mismatch');

            let mut total_shares = 0;
            let mut i = 0;
            while i < shares.len() {
                total_shares += *shares.at(i);
                i += 1;
            };
            assert(total_shares == 10000, 'Shares must total 100%'); // Assuming basis points

            // Clear existing shares
            let mut vec = self.participant_shares.entry(audition_id);
            vec.clear();

            // Set new shares
            i = 0;
            while i < participants.len() {
                vec.push((*participants.at(i), *shares.at(i)));
                i += 1;
            };
        }

        fn distribute_with_fee(
            ref self: ContractState,
            audition_id: u256,
            token: ContractAddress,
            total_amount: u256,
        ) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');

            let shares_vec = self.participant_shares.entry(audition_id);
            assert(shares_vec.len() > 0, 'No participant shares set');

            let platform_fee = (total_amount * self.platform_fee_percentage.read()) / 10000;
            let distributable_amount = total_amount - platform_fee;

            // Update platform fees
            let current_fees = self.platform_fees_collected.read(token);
            self.platform_fees_collected.write(token, current_fees + platform_fee);

            // Distribute to participants
            let mut recipients = ArrayTrait::new();
            let mut amounts = ArrayTrait::new();

            let mut i = 0;
            while i < shares_vec.len() {
                let (participant, share) = shares_vec.at(i).read();
                let amount = (distributable_amount * share) / 10000;
                recipients.append(participant);
                amounts.append(amount);
                self._send_tokens(participant, amount, token);
                self.payment_history.append((audition_id, token, amount, get_block_timestamp(), 'distribution'));
                i += 1;
            };

            self.emit(Event::PaymentSplitDistributed(PaymentSplitDistributed {
                audition_id,
                recipients: recipients.span(),
                amounts: amounts.span(),
                token,
                timestamp: get_block_timestamp(),
            }));

            self.emit(Event::PlatformFeeCollected(PlatformFeeCollected {
                token,
                amount: platform_fee,
                timestamp: get_block_timestamp(),
            }));
        }

        fn raise_dispute(ref self: ContractState, audition_id: u256, reason: felt252) {
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.dispute_status.read(audition_id), 'Dispute already raised');

            let caller = get_caller_address();
            self.dispute_status.write(audition_id, true);

            self.emit(Event::DisputeRaised(DisputeRaised {
                audition_id,
                raiser: caller,
                reason,
                timestamp: get_block_timestamp(),
            }));
        }

        fn resolve_dispute(ref self: ContractState, audition_id: u256, decision: felt252) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(self.dispute_status.read(audition_id), 'No active dispute');

            self.dispute_status.write(audition_id, false);

            self.emit(Event::DisputeResolved(DisputeResolved {
                audition_id,
                resolver: get_caller_address(),
                decision,
                timestamp: get_block_timestamp(),
            }));
        }

        fn get_payment_history(
            self: @ContractState, audition_id: u256,
        ) -> Array<(ContractAddress, u256, u64, felt252)> {
            let mut history = ArrayTrait::new();
            let history_len = self.payment_history.len();
            let mut i = 0;
            while i < history_len {
                let (hist_audition_id, token, amount, timestamp, action) = self.payment_history.at(i).read();
                if hist_audition_id == audition_id {
                    history.append((token, amount, timestamp, action));
                }
                i += 1;
            };
            history
        }

        fn get_escrow_balance(self: @ContractState, audition_id: u256, token: ContractAddress) -> u256 {
            self.escrow_balance.read((audition_id, token))
        }

        fn get_platform_fees(self: @ContractState, token: ContractAddress) -> u256 {
            self.platform_fees_collected.read(token)
        }

        fn withdraw_platform_fees(ref self: ContractState, token: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            let collected = self.platform_fees_collected.read(token);
            assert(collected >= amount, 'Insufficient fees collected');

            let owner = self.ownable.owner();
            self._send_tokens(owner, amount, token);
            self.platform_fees_collected.write(token, collected - amount);
        }


        fn record_vote(
            ref self: ContractState,
            audition_id: u256,
            performer: ContractAddress,
            voter: ContractAddress,
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
            self: @ContractState,
            audition_id: u256,
            performer: ContractAddress,
            voter: ContractAddress,
        ) -> Vote {
            self.ownable.assert_only_owner();

            self.votes.entry((audition_id, performer, voter)).read()
        }

        fn pause_all(ref self: ContractState) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.global_paused.write(true);
            self.emit(Event::PausedAll(PausedAll { timestamp: get_block_timestamp() }));
        }

        fn resume_all(ref self: ContractState) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.global_paused.write(false);
            self.emit(Event::ResumedAll(ResumedAll { timestamp: get_block_timestamp() }));
        }

        fn is_paused(self: @ContractState) -> bool {
            self.global_paused.read()
        }

        fn pause_audition(ref self: ContractState, audition_id: u256) -> bool {
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
            assert(!self.global_paused.read(), 'Contract is paused');
            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);
            self.assert_valid_audition(audition_id);

            let mut audition = self.auditions.entry(audition_id).read();
            audition.paused = true;
            self.auditions.entry(audition_id).write(audition);

            self
                .emit(
                    Event::AuditionPaused(
                        AuditionPaused { audition_id, end_timestamp: audition.end_timestamp },
                    ),
                );
            true
        }

        fn resume_audition(ref self: ContractState, audition_id: u256) -> bool {
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(self.is_audition_paused(audition_id), 'Audition is not paused');
            let mut audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);
            audition.paused = false;
            self.auditions.entry(audition_id).write(audition);

            self
                .emit(
                    Event::AuditionResumed(
                        AuditionResumed { audition_id, end_timestamp: audition.end_timestamp },
                    ),
                );
            true
        }

        fn end_audition(ref self: ContractState, audition_id: u256) -> bool {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(!self.global_paused.read(), 'Contract is paused');

            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_ended(audition_id), 'Audition already ended');

            let mut audition = self.auditions.entry(audition_id).read();
            let current_time = get_block_timestamp();

            audition.end_timestamp = current_time.into();
            self.auditions.entry(audition_id).write(audition);

            self
                .emit(
                    Event::AuditionEnded(
                        AuditionEnded { audition_id, end_timestamp: audition.end_timestamp },
                    ),
                );
            true
        }


        fn is_audition_paused(self: @ContractState, audition_id: u256) -> bool {
            let audition = self.auditions.entry(audition_id).read();
            audition.paused
        }

        fn is_audition_ended(self: @ContractState, audition_id: u256) -> bool {
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

        fn audition_exists(self: @ContractState, audition_id: u256) -> bool {
            let audition = self.auditions.entry(audition_id).read();
            audition.audition_id != 0
        }


        fn pause_season(ref self: ContractState, season_id: u256) {
            self.accesscontrol.assert_only_role(SEASON_MAINTAINER_ROLE);
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
            self.accesscontrol.assert_only_role(SEASON_MAINTAINER_ROLE);
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
            self.accesscontrol.assert_only_role(SEASON_MAINTAINER_ROLE);
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


        /// @notice Registers a performer only if the registration is open and the caller
        /// is not yet registered
        fn register_performer(
            ref self: ContractState,
            audition_id: u256,
            tiktok_id: felt252,
            tiktok_username: felt252,
            email_hash: felt252,
        ) -> u256 {
            let caller = get_caller_address();

            let audition = self.auditions.entry(audition_id).read();
            self.assert_valid_season(audition.season_id);

            let not_registered = self
                .performer_has_registered
                .entry((caller, audition_id))
                .read() == 0;
            assert(not_registered, 'Performer already registered');

            let config_opt = self.registration_config.entry(audition_id).read();
            let config = match config_opt {
                Option::Some(val) => val,
                _ => Default::default(),
            };

            assert(config.registration_open, 'Registration not open');
            let count: u256 = self.performer_count.entry(audition_id).read();
            assert(count.try_into().unwrap() < config.max_participants, 'Max participants reached');
            // test this...
            let amount = config.fee_amount;
            let (_, prize_pool) = self.audition_prices.entry(audition_id).read();
            if amount > 0 {
                self._process_payment(amount, config.fee_token);
                self
                    .audition_prices
                    .entry(audition_id)
                    .write((config.fee_token, prize_pool + amount));
            }

            let registration_timestamp = get_block_timestamp();

            let artist = ArtistRegistration {
                wallet_address: caller,
                audition_id,
                tiktok_id,
                tiktok_username,
                email_hash,
                registration_fee_paid: amount,
                registration_timestamp,
                is_active: true,
            };

            self.registered_artists.entry((caller, audition_id)).write(artist);
            let performer_id: u256 = count + 1;
            self.performer_count.entry(audition_id).write(performer_id);
            self.performer_has_registered.entry((caller, audition_id)).write(performer_id);
            self.registration_started.entry(audition_id).write(true);
            self.performer_audition_address.entry((audition_id, performer_id)).write(caller);
            self.performer_enrollment_status.entry((audition_id, performer_id)).write(true);
            self.enrolled_performers.entry(audition_id).push(performer_id);
            self.performer_registry.entry((audition_id, performer_id)).write(caller);

            let performers_count = self.performers_count.read() + 1;
            self.performers_count.write(performers_count);

            let pool_size = prize_pool + amount;

            let event = ArtistRegistered {
                artist_address: caller,
                audition_id,
                registration_timestamp,
                fee: amount,
                fee_token: config.fee_token,
                pool_size,
            };
            self.emit(event);

            performer_id
        }

        fn get_enrolled_performers(self: @ContractState, audition_id: u256) -> Array<u256> {
            let mut performers_array = ArrayTrait::<u256>::new();
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
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
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

        fn get_performers_count(self: @ContractState) -> u256 {
            self.performers_count.read()
        }

        fn get_performer_address(
            self: @ContractState, audition_id: u256, performer_id: u256,
        ) -> ContractAddress {
            self.performer_registry.entry((audition_id, performer_id)).read()
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
        fn assert_distributed(
            ref self: ContractState,
            audition_id: u256,
            winners: Array<ContractAddress>,
            shares: Array<u256>,
        ) {
            self.accesscontrol.assert_only_role(AUDITION_MAINTAINER_ROLE);
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(self.is_audition_ended(audition_id), 'Audition must end first');

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
            self: @ContractState, audition_id: u256, judge_address: ContractAddress,
        ) {
            let judges = self.get_judges(audition_id);
            for judge in judges {
                assert(judge != judge_address, 'Judge already added');
            }
        }

        fn assert_judge_found(
            self: @ContractState, audition_id: u256, judge_address: ContractAddress,
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
            self: @ContractState, audition_id: u256, judge_address: ContractAddress,
        ) {
            let judges = self.get_judges(audition_id);
            for judge in judges {
                assert(judge == judge_address, 'Judge not found');
            }
        }

        fn assert_evaluation_not_submitted(
            self: @ContractState, audition_id: u256, performer_id: u256, judge: ContractAddress,
        ) {
            let evaluation_submission_status = self
                .evaluation_submission_status
                .entry((audition_id, performer_id, judge))
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

        fn assert_all_players_have_been_evaluated(self: @ContractState, audition_id: u256) {
            let enrolled_performers: Array<u256> = self.get_enrolled_performers(audition_id);
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

        fn assert_valid_audition(self: @ContractState, audition_id: u256) {
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(!self.is_audition_paused(audition_id), 'Audition is paused');
            assert(!self.is_audition_ended(audition_id), 'Audition has ended');
        }

        fn assert_valid_update_time(self: @ContractState, audition_id: u256, new_time: u64) {
            // get the start time and make sure its still greater than the start time
            let audition = self.auditions.entry(audition_id).read();
            assert(new_time > audition.start_timestamp, 'Invalid update time');
            assert(new_time > get_block_timestamp(), 'Invalid update time');
        }

        // assert that the time that the user is updating this, the audition hasnt gone halfway
        // already
        fn assert_audition_hasnt_gone_halfway(self: @ContractState, audition_id: u256) {
            let audition = self.auditions.entry(audition_id).read();
            let halfway_time = audition.start_timestamp
                + (audition.end_timestamp - audition.start_timestamp) / 2;
            assert(get_block_timestamp() < halfway_time, 'Audition has gone halfway');
        }

        fn get_top_winners(
            self: @ContractState, audition_id: u256, limit: u32,
        ) -> Array<ContractAddress> {
            // get the list of all participants and thier scores
            assert(self.audition_exists(audition_id), 'Audition does not exist');
            assert(self.is_audition_ended(audition_id), 'Audition must end first');
            let mut all_aggrgate_scores: Array<(u256, u256)> = array![];
            let storage_vec = self.audition_aggregate_scores.entry(audition_id);
            for i in 0..storage_vec.len() {
                let (performer_id, aggregate_score) = storage_vec.at(i).read();
                all_aggrgate_scores.append((performer_id, aggregate_score));
            }
            // assert the number of winners they are getting is equal or greater than the lenght
            assert(limit.into() <= all_aggrgate_scores.len(), 'INSUFFICIENT NUM OF WINNERS');

            let mut idx1 = 0;
            let mut idx2 = 1;
            let mut sorted_iteration = true;
            // A SORTED ARRRAY OF PERFORMER AND SCORE, FROM HIGHEST TO LOWEST
            let mut sorted_array: Array<(u256, u256)> = array![];

            loop {
                if idx2 == all_aggrgate_scores.len() {
                    sorted_array.append(*all_aggrgate_scores.at(idx1));
                    if sorted_iteration {
                        break;
                    }
                    all_aggrgate_scores = sorted_array.span().try_into().unwrap();
                    sorted_array = array![];
                    idx1 = 0;
                    idx2 = 1;
                    sorted_iteration = true;
                } else {
                    let (id1, score1) = *all_aggrgate_scores.at(idx1);
                    let (id2, score2) = *all_aggrgate_scores.at(idx2);
                    if score1 >= score2 {
                        sorted_array.append((id1, score1));
                        idx1 = idx2;
                        idx2 += 1;
                    } else {
                        sorted_array.append((id2, score2));
                        idx2 += 1;
                        sorted_iteration = false;
                    }
                }
            }
            // get the addresses of the winners based on limit
            let mut array_of_winners_address: Array<ContractAddress> = array![];

            for i in 0..limit {
                // get the id and use the id to get the address
                let (performer_id, _) = *sorted_array.at(i);
                let performer_address: ContractAddress = self
                    .performer_audition_address
                    .read((audition_id, performer_id));
                array_of_winners_address.append(performer_address);
            }

            array_of_winners_address
        }
    }
}
