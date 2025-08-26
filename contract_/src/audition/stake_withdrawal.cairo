use contract_::audition::types::{StakerInfo, StakingConfig};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IStakeWithdrawal<TContractState> {
    // Core withdrawal functions
    fn withdraw_stake(ref self: TContractState, audition_id: felt252) -> u256;
    fn batch_withdraw_stakes(ref self: TContractState, audition_ids: Array<felt252>) -> Array<u256>;

    // Emergency and admin functions
    fn emergency_withdraw_stake(
        ref self: TContractState, staker: ContractAddress, audition_id: felt252,
    );
    fn force_withdraw_all_stakes(ref self: TContractState, audition_id: felt252);

    // View functions
    fn get_staker_info(
        self: @TContractState, staker: ContractAddress, audition_id: felt252,
    ) -> StakerInfo;
    fn get_withdrawal_eligible_stakers(
        self: @TContractState, audition_id: felt252,
    ) -> Array<ContractAddress>;
    fn get_withdrawn_stakers(self: @TContractState, audition_id: felt252) -> Array<ContractAddress>;
    fn can_withdraw_stake(
        self: @TContractState, staker: ContractAddress, audition_id: felt252,
    ) -> bool;
    fn get_total_stakes_for_audition(self: @TContractState, audition_id: felt252) -> (u256, u32);
    fn get_pending_withdrawals_count(self: @TContractState, audition_id: felt252) -> u32;

    // Admin configuration
    fn set_staking_config(ref self: TContractState, audition_id: felt252, config: StakingConfig);
    fn get_staking_config(self: @TContractState, audition_id: felt252) -> StakingConfig;

    // Integration with staking and audition contracts
    fn are_results_finalized(self: @TContractState, audition_id: felt252) -> bool;
    fn set_audition_contract(ref self: TContractState, audition_contract: ContractAddress);
    fn set_staking_contract(ref self: TContractState, staking_contract: ContractAddress);
}

#[starknet::contract]
pub mod StakeWithdrawal {
    use OwnableComponent::InternalTrait as OwnableInternalTrait;
    use contract_::audition::interfaces::istake_to_vote::{
        IStakeToVoteDispatcher, IStakeToVoteDispatcherTrait,
    };
    use contract_::audition::season_and_audition::{
        Audition, ISeasonAndAuditionDispatcher, ISeasonAndAuditionDispatcherTrait,
    };
    use contract_::audition::types::{StakerInfo, StakingConfig};
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::event::EventEmitter;
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::IStakeWithdrawal;

    // Integrates OpenZeppelin ownership component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        // List of withdrawn stakers per audition: audition_id -> Vec<ContractAddress>
        withdrawn_stakers: Map<felt252, Vec<ContractAddress>>,
        // Withdrawal status: (staker, audition_id) -> bool
        withdrawal_status: Map<(ContractAddress, felt252), bool>,
        // Integration with contracts
        audition_contract: ContractAddress,
        staking_contract: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        StakeWithdrawn: StakeWithdrawn,
        BatchStakeWithdrawn: BatchStakeWithdrawn,
        EmergencyStakeWithdrawn: EmergencyStakeWithdrawn,
        WithdrawalFailed: WithdrawalFailed,
        ResultsFinalized: ResultsFinalized,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StakeWithdrawn {
        #[key]
        pub staker: ContractAddress,
        #[key]
        pub audition_id: felt252,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BatchStakeWithdrawn {
        #[key]
        pub staker: ContractAddress,
        pub audition_ids: Array<felt252>,
        pub total_amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EmergencyStakeWithdrawn {
        #[key]
        pub staker: ContractAddress,
        #[key]
        pub audition_id: felt252,
        pub amount: u256,
        pub admin: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalFailed {
        #[key]
        pub staker: ContractAddress,
        #[key]
        pub audition_id: felt252,
        pub reason: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ResultsFinalized {
        #[key]
        pub audition_id: felt252,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        audition_contract: ContractAddress,
        staking_contract: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.audition_contract.write(audition_contract);
        self.staking_contract.write(staking_contract);
    }

    #[abi(embed_v0)]
    impl StakeWithdrawalImpl of IStakeWithdrawal<ContractState> {
        fn withdraw_stake(ref self: ContractState, audition_id: felt252) -> u256 {
            let caller = get_caller_address();

            let staking_contract = IStakeToVoteDispatcher {
                contract_address: self.staking_contract.read(),
            };

            // Check if caller is a staker FIRST
            let staker_info = staking_contract.get_staker_info(caller, audition_id);
            assert(staker_info.staked_amount > 0, 'Caller not a staker');

            // Then verify results are finalized and caller can withdraw
            assert(self.are_results_finalized(audition_id), 'Results not finalized');
            assert(self.can_withdraw_stake(caller, audition_id), 'Cannot withdraw stake');

            // Verify withdrawal delay has passed
            let config = staking_contract.get_staking_config(audition_id);
            self._verify_withdrawal_delay(audition_id, config.withdrawal_delay_after_results);

            // Clear staker data in staking contract
            staking_contract.clear_staker_data(caller, audition_id);

            // Transfer stake back to caller directly
            self._send_tokens(caller, staker_info.staked_amount, config.stake_token);

            // Record withdrawal in our contract
            self.withdrawn_stakers.entry(audition_id).push(caller);
            self.withdrawal_status.write((caller, audition_id), true);

            // Emit withdrawal event
            self
                .emit(
                    StakeWithdrawn {
                        staker: caller,
                        audition_id,
                        amount: staker_info.staked_amount,
                        timestamp: get_block_timestamp(),
                    },
                );

            staker_info.staked_amount
        }

        fn batch_withdraw_stakes(
            ref self: ContractState, audition_ids: Array<felt252>,
        ) -> Array<u256> {
            let caller = get_caller_address();
            let mut withdrawn_amounts = ArrayTrait::new();
            let mut total_amount = 0_u256;

            let staking_contract = IStakeToVoteDispatcher {
                contract_address: self.staking_contract.read(),
            };

            for audition_id in audition_ids.clone() {
                // Check if withdrawal is possible
                if self.can_withdraw_stake(caller, audition_id) {
                    let staker_info = staking_contract.get_staker_info(caller, audition_id);

                    if staker_info.staked_amount > 0 {
                        // Get staking config for this audition
                        let config = staking_contract.get_staking_config(audition_id);

                        // Verify withdrawal delay (skip verification in batch if any fails)
                        let delay_passed = self
                            ._check_withdrawal_delay(
                                audition_id, config.withdrawal_delay_after_results,
                            );

                        if delay_passed {
                            // Clear staker data in staking contract
                            staking_contract.clear_staker_data(caller, audition_id);

                            // Transfer stake back to caller
                            self
                                ._send_tokens(
                                    caller, staker_info.staked_amount, config.stake_token,
                                );

                            // Record withdrawal in our contract
                            self.withdrawn_stakers.entry(audition_id).push(caller);
                            self.withdrawal_status.write((caller, audition_id), true);

                            withdrawn_amounts.append(staker_info.staked_amount);
                            total_amount += staker_info.staked_amount;
                        } else {
                            withdrawn_amounts.append(0);
                        }
                    } else {
                        withdrawn_amounts.append(0);
                    }
                } else {
                    withdrawn_amounts.append(0);
                }
            }

            // Emit batch withdrawal event
            self
                .emit(
                    BatchStakeWithdrawn {
                        staker: caller,
                        audition_ids: audition_ids.clone(),
                        total_amount,
                        timestamp: get_block_timestamp(),
                    },
                );

            withdrawn_amounts
        }

        fn emergency_withdraw_stake(
            ref self: ContractState, staker: ContractAddress, audition_id: felt252,
        ) {
            self.ownable.assert_only_owner();

            let staking_contract = IStakeToVoteDispatcher {
                contract_address: self.staking_contract.read(),
            };

            let staker_info = staking_contract.get_staker_info(staker, audition_id);
            assert(staker_info.staked_amount > 0, 'No stake to withdraw');
            assert(staker_info.is_eligible_voter, 'No active stake');

            // Get staking config for token transfer
            let config = staking_contract.get_staking_config(audition_id);
            assert(config.required_stake_amount > 0, 'No staking config');

            // For emergency withdrawal, we bypass withdrawal delay restrictions
            // Clear staker data in staking contract
            staking_contract.clear_staker_data(staker, audition_id);

            // Transfer stake back to staker directly
            self._send_tokens(staker, staker_info.staked_amount, config.stake_token);

            // Record withdrawal
            self.withdrawn_stakers.entry(audition_id).push(staker);
            self.withdrawal_status.write((staker, audition_id), true);

            // Emit emergency withdrawal event
            self
                .emit(
                    EmergencyStakeWithdrawn {
                        staker,
                        audition_id,
                        amount: staker_info.staked_amount,
                        admin: get_caller_address(),
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn force_withdraw_all_stakes(ref self: ContractState, audition_id: felt252) {
            self.ownable.assert_only_owner();

            // This is a mass emergency withdrawal - would need to be implemented
            // with special admin privileges in the staking contract
            // For now, we'll emit an event that this was requested
            self.emit(ResultsFinalized { audition_id, timestamp: get_block_timestamp() });
        }

        fn get_staker_info(
            self: @ContractState, staker: ContractAddress, audition_id: felt252,
        ) -> StakerInfo {
            let staking_contract = IStakeToVoteDispatcher {
                contract_address: self.staking_contract.read(),
            };
            staking_contract.get_staker_info(staker, audition_id)
        }

        fn get_withdrawal_eligible_stakers(
            self: @ContractState, audition_id: felt252,
        ) -> Array<ContractAddress> {
            // This would require querying the staking contract for all stakers
            // For now, return empty array - full implementation would need the staking contract
            // to provide a way to enumerate all stakers for an audition
            ArrayTrait::new()
        }

        fn get_withdrawn_stakers(
            self: @ContractState, audition_id: felt252,
        ) -> Array<ContractAddress> {
            let mut withdrawn_list = ArrayTrait::new();
            let withdrawn_vec = self.withdrawn_stakers.entry(audition_id);

            for i in 0..withdrawn_vec.len() {
                let staker = withdrawn_vec.at(i).read();
                withdrawn_list.append(staker);
            }

            withdrawn_list
        }

        fn can_withdraw_stake(
            self: @ContractState, staker: ContractAddress, audition_id: felt252,
        ) -> bool {
            // Check if already withdrawn through our contract
            if self.withdrawal_status.read((staker, audition_id)) {
                return false;
            }

            // Check if results are finalized
            if !self.are_results_finalized(audition_id) {
                return false;
            }

            // Check with staking contract
            let staking_contract = IStakeToVoteDispatcher {
                contract_address: self.staking_contract.read(),
            };

            let staker_info = staking_contract.get_staker_info(staker, audition_id);
            staker_info.staked_amount > 0 && staker_info.is_eligible_voter
        }

        fn get_total_stakes_for_audition(
            self: @ContractState, audition_id: felt252,
        ) -> (u256, u32) {
            // This would require enumerating all stakers from the staking contract
            // For now, return zero - full implementation would need the staking contract
            // to provide aggregated data
            (0, 0)
        }

        fn get_pending_withdrawals_count(self: @ContractState, audition_id: felt252) -> u32 {
            // This would require enumerating all stakers from the staking contract
            // For now, return zero
            0
        }

        fn set_staking_config(
            ref self: ContractState, audition_id: felt252, config: StakingConfig,
        ) {
            self.ownable.assert_only_owner();

            // Check if audition exists first
            let audition_contract_addr = self.audition_contract.read();
            if !audition_contract_addr.is_zero() {
                let audition_contract = ISeasonAndAuditionDispatcher {
                    contract_address: audition_contract_addr,
                };
                assert(audition_contract.audition_exists(audition_id), 'Audition does not exist');
            }

            // This function is provided for interface compliance but has architectural limitations.
            // The withdrawal contract calling staking_contract.set_staking_config() creates
            // ownership issues because the staking contract expects its own owner as the caller.
            //
            // In practice, staking configs should be set directly on the staking contract
            // by its owner. This function will only work if both contracts have the same owner.
            let staking_contract = IStakeToVoteDispatcher {
                contract_address: self.staking_contract.read(),
            };

            staking_contract
                .set_staking_config(
                    audition_id,
                    config.required_stake_amount,
                    config.stake_token,
                    config.withdrawal_delay_after_results,
                );
        }

        fn get_staking_config(self: @ContractState, audition_id: felt252) -> StakingConfig {
            let staking_contract = IStakeToVoteDispatcher {
                contract_address: self.staking_contract.read(),
            };

            // Check if audition exists first to avoid errors
            let audition_contract_addr = self.audition_contract.read();
            if !audition_contract_addr.is_zero() {
                let audition_contract = ISeasonAndAuditionDispatcher {
                    contract_address: audition_contract_addr,
                };
                if !audition_contract.audition_exists(audition_id) {
                    // Return default config for non-existent auditions
                    return StakingConfig {
                        required_stake_amount: 0,
                        stake_token: Zero::zero(),
                        withdrawal_delay_after_results: 0,
                    };
                }
            }

            staking_contract.get_staking_config(audition_id)
        }

        fn are_results_finalized(self: @ContractState, audition_id: felt252) -> bool {
            // Check with the audition contract if configured
            let audition_contract_addr = self.audition_contract.read();
            if !audition_contract_addr.is_zero() {
                let audition_contract = ISeasonAndAuditionDispatcher {
                    contract_address: audition_contract_addr,
                };

                // Check if audition has ended and calculation is completed
                let audition_ended = audition_contract.is_audition_ended(audition_id);
                // In a full implementation, you'd also check if aggregate scores are calculated
                // For now, we assume results are finalized when audition ends
                return audition_ended;
            }

            false
        }

        fn set_audition_contract(ref self: ContractState, audition_contract: ContractAddress) {
            self.ownable.assert_only_owner();
            self.audition_contract.write(audition_contract);
        }

        fn set_staking_contract(ref self: ContractState, staking_contract: ContractAddress) {
            self.ownable.assert_only_owner();
            self.staking_contract.write(staking_contract);
        }
    }

    #[generate_trait]
    impl InternalImpl of WithdrawalInternalTrait {
        /// @notice Transfers tokens from contract to recipient
        /// @param recipient The address to receive tokens
        /// @param amount The amount of tokens to transfer
        /// @param token_address The address of the token contract
        fn _send_tokens(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
            token_address: ContractAddress,
        ) {
            let token = IERC20Dispatcher { contract_address: token_address };
            let transferred = token.transfer(recipient, amount);
            assert(transferred, 'Token transfer failed');
        }

        /// @notice Verifies that withdrawal delay has passed
        /// @param audition_id The audition ID
        /// @param delay The required delay in seconds
        fn _verify_withdrawal_delay(self: @ContractState, audition_id: felt252, delay: u64) {
            let audition_contract = ISeasonAndAuditionDispatcher {
                contract_address: self.audition_contract.read(),
            };

            let audition = audition_contract.read_audition(audition_id);
            let end_time: u64 = audition.end_timestamp.try_into().unwrap();
            let current_time = get_block_timestamp();

            assert(current_time >= end_time + delay, 'Withdrawal delay active');
        }

        /// @notice Checks if withdrawal delay has passed (non-asserting version)
        /// @param audition_id The audition ID
        /// @param delay The required delay in seconds
        /// @return bool True if delay has passed
        fn _check_withdrawal_delay(self: @ContractState, audition_id: felt252, delay: u64) -> bool {
            let audition_contract = ISeasonAndAuditionDispatcher {
                contract_address: self.audition_contract.read(),
            };

            let audition = audition_contract.read_audition(audition_id);
            let end_time: u64 = audition.end_timestamp.try_into().unwrap();
            let current_time = get_block_timestamp();

            current_time >= end_time + delay
        }
    }
}
