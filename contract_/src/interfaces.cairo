use starknet::ContractAddress;
use core::byte_array::ByteArray;

#[starknet::interface]
pub trait IRevenueDistribution<TContractState> {
    fn add_revenue(ref self: TContractState, category: ByteArray, amount: u256);
    fn claim_revenue(ref self: TContractState);
    fn calculate_revenue_share(self: @TContractState, holder: ContractAddress) -> u256 ;
    fn distribute_revenue(ref self: TContractState);
    fn get_holder_revenue(self: @TContractState, holder: ContractAddress) -> u256;
    fn get_revenue_by_category(self: @TContractState, category: ByteArray) -> u256;
    fn get_tokens_by_artist(self: @TContractState, artist: ContractAddress) -> Array<ByteArray> ;
}
