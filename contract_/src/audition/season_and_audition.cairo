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
    pub weight: u64,
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
        weight: u64,
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

    // Genre-based filtering
    fn get_seasons_by_genre(
        self: @TContractState, genre: felt252, max_results: u32,
    ) -> Array<Season>;
    fn get_auditions_by_genre(
        self: @TContractState, genre: felt252, max_results: u32,
    ) -> Array<Audition>;

    // Time-based queries
    fn get_active_auditions(self: @TContractState, current_timestamp: u64) -> Array<Audition>;
    fn get_auditions_in_time_range(
        self: @TContractState, start_timestamp: u64, end_timestamp: u64,
    ) -> Array<Audition>;

    // Season-based queries
    fn get_auditions_by_season(self: @TContractState, season_id: felt252) -> Array<Audition>;

    // Analytics functions
    fn get_audition_vote_count(self: @TContractState, audition_id: felt252) -> u32;
    fn get_total_vote_weight_for_performer(
        self: @TContractState, audition_id: felt252, performer: felt252,
    ) -> u64;

    // Pagination and listing
    fn get_seasons_by_ids(self: @TContractState, season_ids: Array<felt252>) -> Array<Season>;
    fn get_auditions_by_ids(self: @TContractState, audition_ids: Array<felt252>) -> Array<Audition>;

    // Complex filtering
    fn get_auditions_by_criteria(
        self: @TContractState,
        audition_ids: Array<felt252>,
        genre: Option<felt252>,
        season_id: Option<felt252>,
        start_time: Option<u64>,
        end_time: Option<u64>,
        paused_state: Option<bool>,
    ) -> Array<Audition>;

    // Utility functions
    fn is_audition_active(
        self: @TContractState, audition_id: felt252, current_timestamp: u64,
    ) -> bool;
    fn get_audition_status(
        self: @TContractState, audition_id: felt252,
    ) -> felt252; // 0=not_started, 1=active, 2=ended, 3=paused, 404= Not found
    fn count_votes_for_audition(
        self: @TContractState,
        audition_id: felt252,
        voter_performer_pairs: Array<(felt252, felt252)>,
    ) -> u32;
    fn get_performer_history(self: @TContractState, performer: felt252) -> Array<felt252>;
    fn get_voter_history(self: @TContractState, voter: felt252) -> Array<felt252>;
    fn get_genre_audition_count(self: @TContractState, genre: felt252) -> u32;
}

#[starknet::contract]
pub mod SeasonAndAudition {
    use core::num::traits::Zero;
    use starknet::get_contract_address;
    use starknet::event::EventEmitter;
    use OwnableComponent::HasComponent;
    use OwnableComponent::InternalTrait;
    use contract_::errors::errors;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{Audition, ISeasonAndAudition, Season, Vote};
    use crate::events::{
        SeasonCreated, SeasonUpdated, SeasonDeleted, AuditionCreated, AuditionUpdated,
        AuditionDeleted, ResultsSubmitted, OracleAdded, OracleRemoved, AuditionPaused,
        AuditionResumed, AuditionEnded, VoteRecorded, PausedAll, ResumedAll, PriceDistributed,
        PriceDeposited,
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };

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
        // For efficient querying - maintain lists of IDs
        all_season_ids: Map<u32, felt252>, // index -> season_id
        all_audition_ids: Map<u32, felt252>, // index -> audition_id
        season_count: u32,
        audition_count: u32,
        // Vote counting cache
        audition_vote_counts: Map<felt252, u32>, // audition_id -> vote_count
        performer_total_weights: Map<
            (felt252, felt252), u64,
        >, // (audition_id, performer) -> total_weight
        // Map from (genre, index) to season_id
        seasons_by_genre_items: Map<(felt252, u32), felt252>,
        // Map from genre to length of the list
        seasons_by_genre_length: Map<felt252, u32>,
        // Map from (genre, index) to audition_id
        auditions_by_genre_items: Map<(felt252, u32), felt252>,
        // Map from genre to length of the list
        auditions_by_genre_length: Map<felt252, u32>,
        // Map from (season_id, index) to audition_id
        auditions_by_season_items: Map<(felt252, u32), felt252>,
        // Map from season_id to length of the list
        auditions_by_season_length: Map<felt252, u32>,
        // Map from (performer, index) to audition_id
        performer_audition_history_items: Map<(felt252, u32), felt252>,
        // Map from performer to length of the list
        performer_audition_history_length: Map<felt252, u32>,
        // Map from (voter, index) to audition_id
        voter_audition_history_items: Map<(felt252, u32), felt252>,
        // Map from voter to length of the list
        voter_audition_history_length: Map<felt252, u32>,
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
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.global_paused.write(false);
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
                .write(
                    season_id,
                    Season { season_id, genre, name, start_timestamp, end_timestamp, paused },
                );
            let current_count = self.season_count.read();
            self.all_season_ids.write(current_count, season_id);
            self.season_count.write(current_count + 1);

            let genre_length = self.seasons_by_genre_length.read(genre);
            self.seasons_by_genre_items.write((genre, genre_length), season_id);
            self.seasons_by_genre_length.write(genre, genre_length + 1);

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
            let current_count = self.audition_count.read();
            self.all_audition_ids.write(current_count, audition_id);
            self.audition_count.write(current_count + 1);

            // Append to auditions_by_genre_items using simulated list
            let genre_length = self.auditions_by_genre_length.read(genre);
            self.auditions_by_genre_items.write((genre, genre_length), audition_id);
            self.auditions_by_genre_length.write(genre, genre_length + 1);

            let season_length = self.auditions_by_season_length.read(season_id);
            self.auditions_by_season_items.write((season_id, season_length), audition_id);
            self.auditions_by_season_length.write(season_id, season_length + 1);

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
            };
            let mut count = 0;
            for elements in winners_span {
                let winner_contract_address = *elements;
                let amount = *distributed_amounts.at(count);
                self._send_tokens(winner_contract_address, amount, token_contract_address);
                count += 1;
            };
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
            weight: u64,
        ) {
            self.only_oracle();
            assert(!self.global_paused.read(), 'Contract is paused');

            // Check if vote already exists (duplicate vote prevention)
            let vote_key = (audition_id, performer, voter);
            let existing_vote = self.votes.entry(vote_key).read();

            // If the vote has a non-zero audition_id, it means a vote already exists
            assert(existing_vote.audition_id == 0, errors::DUPLICATE_VOTE);

            self.votes.entry(vote_key).write(Vote { audition_id, performer, voter, weight });

            let current_count = self.audition_vote_counts.read(audition_id);
            self.audition_vote_counts.write(audition_id, current_count + 1);

            let performer_key = (audition_id, performer);
            let current_weight = self.performer_total_weights.read(performer_key);
            self.performer_total_weights.write(performer_key, current_weight + weight);

            let performer_length = self.performer_audition_history_length.read(performer);

            if performer_length == 0
                || self
                    .performer_audition_history_items
                    .read((performer, performer_length - 1)) != audition_id {
                self
                    .performer_audition_history_items
                    .write((performer, performer_length), audition_id);
                self.performer_audition_history_length.write(performer, performer_length + 1);
            }

            let voter_length = self.voter_audition_history_length.read(voter);
            if voter_length == 0
                || self
                    .voter_audition_history_items
                    .read((voter, voter_length - 1)) != audition_id {
                self.voter_audition_history_items.write((voter, voter_length), audition_id);
                self.voter_audition_history_length.write(voter, voter_length + 1);
            }

            self.emit(Event::VoteRecorded(VoteRecorded { audition_id, performer, voter, weight: weight.into() }));
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

        // Genre-based filtering
        fn get_seasons_by_genre(
            self: @ContractState, genre: felt252, max_results: u32,
        ) -> Array<Season> {
            let mut result = ArrayTrait::new();
            let length = self
                .seasons_by_genre_length
                .read(genre); // Get the list length for this genre

            let mut i = 0;
            while i < length && i < max_results {
                let season_id = self
                    .seasons_by_genre_items
                    .read((genre, i)); // Read item at index i
                if season_id != 0 {
                    let season = self.seasons.read(season_id);
                    result.append(season);
                }
                i += 1;
            };

            result
        }


        fn get_auditions_by_genre(
            self: @ContractState, genre: felt252, max_results: u32,
        ) -> Array<Audition> {
            let mut result = ArrayTrait::new();
            let length = self
                .auditions_by_genre_length
                .read(genre); // Get the list length for this genre

            let mut i = 0;
            while i < length && i < max_results {
                let audition_id = self
                    .auditions_by_genre_items
                    .read((genre, i)); // Read item at index i
                if audition_id != 0 {
                    let audition = self.auditions.read(audition_id);
                    result.append(audition);
                }
                i += 1;
            };

            result
        }


        // Time-based queries
        fn get_active_auditions(self: @ContractState, current_timestamp: u64) -> Array<Audition> {
            let mut result = ArrayTrait::new();
            let total_auditions = self.audition_count.read();

            let mut i = 0;
            while i < total_auditions {
                let audition_id = self.all_audition_ids.read(i);
                if audition_id != 0 {
                    let audition = self.auditions.read(audition_id);
                    if self.is_audition_active(audition_id, current_timestamp.into()) {
                        result.append(audition);
                    }
                }
                i += 1;
            };

            result
        }

        fn get_auditions_in_time_range(
            self: @ContractState, start_timestamp: u64, end_timestamp: u64,
        ) -> Array<Audition> {
            assert(end_timestamp > start_timestamp, 'Start time > end time');
            let mut result = ArrayTrait::new();
            let total_auditions: u32 = self.audition_count.read().try_into().unwrap();

            let mut i = 0_u32;
            while i < total_auditions {
                let audition_id = self.all_audition_ids.read(i);
                if audition_id != 0 {
                    let audition = self.auditions.read(audition_id);
                    if audition.start_timestamp.try_into().unwrap() >= start_timestamp
                        && audition.end_timestamp.try_into().unwrap() <= end_timestamp {
                        result.append(audition);
                    }
                }
                i += 1;
            };

            result
        }

        // Season-based queries
        fn get_auditions_by_season(self: @ContractState, season_id: felt252) -> Array<Audition> {
            let mut result = ArrayTrait::new();
            let length = self
                .auditions_by_season_length
                .read(season_id); // Get the list length for this season

            let mut i = 0;
            while i < length {
                let audition_id = self
                    .auditions_by_season_items
                    .read((season_id, i)); // Read item at index i
                if audition_id != 0 {
                    let audition = self.auditions.read(audition_id);
                    result.append(audition);
                }
                i += 1;
            };

            result
        }

        // Analytics functions
        fn get_audition_vote_count(self: @ContractState, audition_id: felt252) -> u32 {
            self.audition_vote_counts.read(audition_id)
        }

        fn get_total_vote_weight_for_performer(
            self: @ContractState, audition_id: felt252, performer: felt252,
        ) -> u64 {
            self.performer_total_weights.read((audition_id, performer))
        }

        // Pagination and listing
        fn get_seasons_by_ids(self: @ContractState, season_ids: Array<felt252>) -> Array<Season> {
            let mut result = ArrayTrait::new();
            let season_ids_span = season_ids.span();

            for season_id in season_ids_span {
                let season = self.seasons.read(*season_id);
                if season.season_id != 0 {
                    result.append(season);
                }
            };

            result
        }

        fn get_auditions_by_ids(
            self: @ContractState, audition_ids: Array<felt252>,
        ) -> Array<Audition> {
            let mut result = ArrayTrait::new();
            let audition_ids_span = audition_ids.span();

            for audition_id in audition_ids_span {
                let audition = self.auditions.read(*audition_id);
                if audition.audition_id != 0 {
                    result.append(audition);
                }
            };

            result
        }

        // Complex filtering
        fn get_auditions_by_criteria(
            self: @ContractState,
            audition_ids: Array<felt252>,
            genre: Option<felt252>,
            season_id: Option<felt252>,
            start_time: Option<u64>,
            end_time: Option<u64>,
            paused_state: Option<bool>,
        ) -> Array<Audition> {
            let mut result = ArrayTrait::new();
            let audition_ids_span = audition_ids.span();

            for audition_id in audition_ids_span {
                let audition = self.auditions.read(*audition_id);
                if audition.audition_id == 0 {
                    continue;
                }

                // Apply filters
                if let Option::Some(filter_genre) = genre {
                    if audition.genre != filter_genre {
                        continue;
                    }
                }

                if let Option::Some(filter_season_id) = season_id {
                    if audition.season_id != filter_season_id {
                        continue;
                    }
                }

                if let Option::Some(filter_start_time) = start_time {
                    if audition
                        .start_timestamp
                        .try_into()
                        .expect('start_timestamp conversion') < filter_start_time {
                        continue;
                    }
                }

                if let Option::Some(filter_end_time) = end_time {
                    if audition
                        .end_timestamp
                        .try_into()
                        .expect('end_timestamp conversion') > filter_end_time {
                        continue;
                    }
                }

                if let Option::Some(filter_paused) = paused_state {
                    if audition.paused != filter_paused {
                        continue;
                    }
                }

                result.append(audition);
            };

            result
        }

        // Utility functions
        fn is_audition_active(
            self: @ContractState, audition_id: felt252, current_timestamp: u64,
        ) -> bool {
            let audition = self.auditions.read(audition_id);
            if audition.audition_id == 0 || audition.paused {
                return false;
            }

            audition
                .start_timestamp
                .try_into()
                .expect('start_timestamp conversion') <= current_timestamp
                && (audition.end_timestamp == 0
                    || audition
                        .end_timestamp
                        .try_into()
                        .expect('end_timestamp conversion') > current_timestamp)
        }

        /// returns 404 if not found
        /// 0 = Not started
        /// 1 = Active
        /// 2 = Ended
        /// 3 = Paused
        fn get_audition_status(self: @ContractState, audition_id: felt252) -> felt252 {
            let audition = self.auditions.read(audition_id);
            if audition.audition_id == 0 {
                return 404; // Not found
            }

            if audition.paused {
                return 3; // Paused
            }

            let current_time = get_block_timestamp();

            if audition
                .start_timestamp
                .try_into()
                .expect('start_timestamp conversion') > current_time {
                return 0; // Not started
            }

            if audition.end_timestamp != 0
                && audition
                    .end_timestamp
                    .try_into()
                    .expect('end_timestamp conversion') <= current_time {
                return 2; // Ended
            }

            1 // Active
        }

        fn count_votes_for_audition(
            self: @ContractState,
            audition_id: felt252,
            voter_performer_pairs: Array<(felt252, felt252)>,
        ) -> u32 {
            let mut count = 0;
            let pairs_span = voter_performer_pairs.span();

            for pair in pairs_span {
                let (performer, voter) = *pair;
                let vote_key = (audition_id, performer, voter);
                let vote = self.votes.read(vote_key);
                if vote.audition_id != 0 {
                    count += 1;
                }
            };

            count
        }

        fn get_performer_history(self: @ContractState, performer: felt252) -> Array<felt252> {
            let length = self.performer_audition_history_length.read(performer);
            let mut result = ArrayTrait::new();
            let mut i = 0;
            while i < length {
                let audition_id = self.performer_audition_history_items.read((performer, i));
                result.append(audition_id);
                i += 1;
            };
            result
        }

        fn get_voter_history(self: @ContractState, voter: felt252) -> Array<felt252> {
            let length = self.voter_audition_history_length.read(voter);
            let mut result = ArrayTrait::new();
            let mut i = 0;
            while i < length {
                let audition_id = self.voter_audition_history_items.read((voter, i));
                result.append(audition_id);
                i += 1;
            };
            result
        }

        fn get_genre_audition_count(self: @ContractState, genre: felt252) -> u32 {
            self.auditions_by_genre_length.read(genre)
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
            };

            for winners in winners_span {
                assert(!winners.is_zero(), 'null contract address');
            };

            assert(total == 100, 'total does not add up');
        }
    }
}
