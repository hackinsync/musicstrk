use starknet::ContractAddress;

#[starknet::interface]
pub trait IStakeToVote<TContractState> {
    /// @notice Sets the staking configuration for an audition.
    /// @dev Only the owner can call this.
    /// @param audition_id The ID of the audition.
    /// @param required_stake_amount The exact amount required for staking.
    /// @param stake_token The contract address of the token to be used for staking (e.g., USDC).
    /// @param withdrawal_delay_after_results The time delay for withdrawal after results are final.
    fn set_staking_config(
        ref self: TContractState,
        audition_id: u256,
        required_stake_amount: u256,
        stake_token: ContractAddress,
        withdrawal_delay_after_results: u64,
    );

    /// @notice Allows a user to stake tokens to become an eligible voter for an audition.
    /// @dev The user must send the exact required amount of tokens.
    /// @param audition_id The ID of the audition to stake for.
    fn stake_to_vote(ref self: TContractState, audition_id: u256);


    /// @notice Checks if a wallet is eligible to vote for a specific audition.
    /// @param audition_id The ID of the audition.
    /// @param voter_address The address of the voter to check.
    /// @return bool True if the voter is eligible, false otherwise.
    fn is_eligible_voter(
        self: @TContractState, audition_id: u256, voter_address: ContractAddress,
    ) -> bool;

    fn required_stake_amount(self: @TContractState, audition_id: u256) -> u256;

    // Additional functions needed for withdrawal integration
    fn get_staker_info(
        self: @TContractState, staker: ContractAddress, audition_id: u256,
    ) -> contract_::audition::types::stake_to_vote::StakerInfo;
    fn get_staking_config(
        self: @TContractState, audition_id: u256,
    ) -> contract_::audition::types::stake_to_vote::StakingConfig;

    // Withdrawal management functions (called only by authorized withdrawal contract)
    fn clear_staker_data(ref self: TContractState, staker: ContractAddress, audition_id: u256);
    fn set_withdrawal_contract(ref self: TContractState, withdrawal_contract: ContractAddress);

    // Admin function to set audition contract address (solves circular dependency)
    fn set_audition_contract(ref self: TContractState, audition_contract: ContractAddress);
}
