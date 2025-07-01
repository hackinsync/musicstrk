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
}

#[starknet::contract]
pub mod SeasonAndAudition {
    use core::num::traits::Zero;
    use starknet::get_contract_address;
    use OwnableComponent::InternalTrait;
    use contract_::errors::errors;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{Audition, ISeasonAndAudition, Season, Vote};
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
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SeasonCreated: SeasonCreated,
        AuditionCreated: AuditionCreated,
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

    #[derive(Drop, starknet::Event)]
    pub struct SeasonCreated {
        pub season_id: felt252,
        pub genre: felt252,
        pub name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuditionCreated {
        pub audition_id: felt252,
        pub season_id: felt252,
        pub genre: felt252,
        pub name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuditionPaused {
        pub audition_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuditionResumed {
        pub audition_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuditionEnded {
        pub audition_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ResultsSubmitted {
        pub audition_id: felt252,
        pub top_performers: felt252,
        pub shares: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OracleAdded {
        pub oracle_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OracleRemoved {
        pub oracle_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VoteRecorded {
        pub audition_id: felt252,
        pub performer: felt252,
        pub voter: felt252,
        pub weight: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PriceDeposited {
        pub audition_id: felt252,
        pub token_address: ContractAddress,
        pub amount: u256,
    }


    #[derive(Drop, starknet::Event)]
    pub struct PriceDistributed {
        pub audition_id: felt252,
        pub winners: [ContractAddress; 3],
        pub shares: [u256; 3],
        pub token_address: ContractAddress,
        pub amounts: Span<u256>,
    }


    #[derive(Drop, starknet::Event)]
    pub struct PausedAll {}

    #[derive(Drop, starknet::Event)]
    pub struct ResumedAll {}

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
                .entry(season_id)
                .write(Season { season_id, genre, name, start_timestamp, end_timestamp, paused });

            self.emit(SeasonCreated { season_id, genre, name });
        }

        fn read_season(self: @ContractState, season_id: felt252) -> Season {
            self.seasons.entry(season_id).read()
        }

        fn update_season(ref self: ContractState, season_id: felt252, season: Season) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');

            self.seasons.entry(season_id).write(season);
        }

        fn delete_season(ref self: ContractState, season_id: felt252) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');

            let default_season: Season = Default::default();

            self.seasons.entry(season_id).write(default_season);
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

            self.emit(AuditionCreated { audition_id, season_id, genre, name });
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
        }

        fn delete_audition(ref self: ContractState, audition_id: felt252) {
            self.ownable.assert_only_owner();
            assert(!self.global_paused.read(), 'Contract is paused');
            assert(!self.is_audition_paused(audition_id), 'Cannot delete paused audition');
            assert(!self.is_audition_ended(audition_id), 'Cannot delete ended audition');

            let default_audition: Audition = Default::default();

            self.auditions.entry(audition_id).write(default_audition);
        }

        fn submit_results(
            ref self: ContractState, audition_id: felt252, top_performers: felt252, shares: felt252,
        ) {
            self.only_oracle();
            assert(!self.global_paused.read(), 'Contract is paused');

            self
                .emit(
                    Event::ResultsSubmitted(
                        ResultsSubmitted { audition_id, top_performers, shares },
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
        /// `assert_distribue`.
        fn distribute_prize(
            ref self: ContractState,
            audition_id: felt252,
            winners: [ContractAddress; 3],
            shares: [u256; 3],
        ) {
            self.assert_distribue(audition_id, winners, shares);
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
            self.emit(Event::PausedAll(PausedAll {}));
        }

        fn resume_all(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.global_paused.write(false);
            self.emit(Event::ResumedAll(ResumedAll {}));
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

            self.emit(Event::AuditionPaused(AuditionPaused { audition_id }));
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

            self.emit(Event::AuditionResumed(AuditionResumed { audition_id }));
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

            self.emit(Event::AuditionEnded(AuditionEnded { audition_id }));
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
        fn assert_distribue(
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

            let winners_span = winners.span();
            let shares_span = shares.span();

            let mut total: u256 = 0;

            for shares in shares_span {
                total = total + *shares;
            };

            for winners in winners_span {
                assert(winners.is_zero(), 'null contract address');
            };

            assert(total == 100, 'total does not add up');
        }
    }
}
