#[starknet::contract]
pub mod StakeToVote {
    use OwnableComponent::InternalTrait;
    use contract_::audition::interfaces::iseason_and_audition::{
        ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait,
    };
    use contract_::audition::interfaces::istake_to_vote::IStakeToVote;
    use contract_::audition::types::season_and_audition::Audition;
    use contract_::audition::types::stake_to_vote::*;
    use contract_::errors::errors;
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::event::EventEmitter;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};

    // Integrates OpenZeppelin ownership component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        /// @notice Maps an audition ID to its staking configuration.
        staking_configs: Map<u256, StakingConfig>,
        /// @notice Maps (audition_id, staker_address) to the staker's information.
        stakers: Map<(u256, ContractAddress), StakerInfo>,
        /// @notice Tracks which wallets are eligible to vote for a specific audition.
        eligible_voters: Map<(u256, ContractAddress), bool>,
        /// @notice Holds the season and audition contract address, to be initialized in the
        /// constructor
        season_and_audition_contract_address: ContractAddress,
        /// @notice Address of the authorized withdrawal contract
        withdrawal_contract: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        StakingConfigSet: StakingConfigSet,
        StakePlaced: StakePlaced,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        season_and_audition_contract_address: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.season_and_audition_contract_address.write(season_and_audition_contract_address);
    }

    #[abi(embed_v0)]
    impl StakeToVoteImpl of IStakeToVote<ContractState> {
        fn set_staking_config(
            ref self: ContractState,
            audition_id: u256,
            required_stake_amount: u256,
            stake_token: ContractAddress,
            withdrawal_delay_after_results: u64,
        ) {
            self.ownable.assert_only_owner();
            let season_and_audition_dispatcher = ISeasonAndAuditionDispatcher {
                contract_address: self.season_and_audition_contract_address.read(),
            };

            assert(
                season_and_audition_dispatcher.audition_exists(audition_id),
                errors::AUDITION_DOES_NOT_EXIST,
            );
            assert(!stake_token.is_zero(), errors::STAKE_TOKEN_CANNOT_BE_ZERO);
            assert(required_stake_amount > 0, errors::STAKE_AMOUNT_MUST_BE_GRAETER_THAN_ZERO);

            let config = StakingConfig {
                required_stake_amount, stake_token, withdrawal_delay_after_results,
            };
            self.staking_configs.write(audition_id, config);
            self
                .emit(
                    Event::StakingConfigSet(
                        StakingConfigSet { audition_id, required_stake_amount, stake_token },
                    ),
                );
        }

        fn stake_to_vote(ref self: ContractState, audition_id: u256) {
            let caller = get_caller_address();
            let config = self.staking_configs.read(audition_id);
            let required_amount = config.required_stake_amount;
            let season_and_audition_dispatcher = ISeasonAndAuditionDispatcher {
                contract_address: self.season_and_audition_contract_address.read(),
            };

            assert(required_amount > 0, errors::STAKING_NOT_ENABLED);
            assert(
                !season_and_audition_dispatcher.is_audition_ended(audition_id),
                errors::AUDITION_HAS_ENDED,
            );
            assert(
                !self.stakers.read((audition_id, caller)).is_eligible_voter, errors::ALREADY_STAKED,
            );

            // This internal function handles the token transfer and checks allowance/balance
            self._process_payment(required_amount, config.stake_token);

            let staker_info = StakerInfo {
                address: caller,
                audition_id,
                staked_amount: required_amount,
                stake_timestamp: get_block_timestamp(),
                is_eligible_voter: true,
                has_voted: false,
            };

            self.stakers.write((audition_id, caller), staker_info);
            self.eligible_voters.write((audition_id, caller), true);

            self
                .emit(
                    Event::StakePlaced(
                        StakePlaced { audition_id, staker: caller, amount: required_amount },
                    ),
                );
        }


        fn is_eligible_voter(
            self: @ContractState, audition_id: u256, voter_address: ContractAddress,
        ) -> bool {
            self.eligible_voters.entry((audition_id, voter_address)).read()
        }

        fn required_stake_amount(self: @ContractState, audition_id: u256) -> u256 {
            let config = self.staking_configs.read(audition_id);

            config.required_stake_amount
        }

        fn get_staker_info(
            self: @ContractState, staker: ContractAddress, audition_id: u256,
        ) -> StakerInfo {
            self.stakers.read((audition_id, staker))
        }

        fn get_staking_config(self: @ContractState, audition_id: u256) -> StakingConfig {
            self.staking_configs.read(audition_id)
        }

        fn clear_staker_data(
            ref self: ContractState, staker: ContractAddress, audition_id: u256,
        ) {
            // Only authorized withdrawal contract can call this
            let caller = get_caller_address();
            let authorized_withdrawal_contract = self.withdrawal_contract.read();
            assert(
                caller == authorized_withdrawal_contract
                    && !authorized_withdrawal_contract.is_zero(),
                'Only withdrawal contract',
            );

            // Clear staker data
            self.stakers.entry((audition_id, staker)).write(Default::default());
            self.eligible_voters.write((audition_id, staker), false);
        }

        fn set_withdrawal_contract(ref self: ContractState, withdrawal_contract: ContractAddress) {
            self.ownable.assert_only_owner();
            self.withdrawal_contract.write(withdrawal_contract);
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
            let transferred = payment_token.transfer_from(caller, contract_address, amount);

            assert(transferred, errors::TRANSFER_FAILED);
        }

        /// @notice Checks if the caller has sufficient token allowance.
        /// @dev Asserts that the caller has enough allowance to transfer the specified amount.
        /// @param self The contract state reference.
        /// @param owner The address of the owner.
        /// @param amount The amount of tokens to check allowance for.
        /// @require The caller must have sufficient token allowance.
        fn _check_token_allowance(
            ref self: ContractState,
            owner: ContractAddress,
            amount: u256,
            token_address: ContractAddress,
        ) {
            let token = IERC20Dispatcher { contract_address: token_address };
            let allowance = token.allowance(owner, starknet::get_contract_address());
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
    }
}
