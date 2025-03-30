use starknet::ContractAddress;

#[derive(PartialEq, Copy, Drop, Serde)]
pub enum Category {
    TICKET,
    MERCH,
    STREAMING,
}

#[derive(Drop, starknet::Event)]
pub struct RevenueAddedEvent {
    pub category: Category,
    pub amount: u256,
    pub time: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RevenueDistributedEvent {
    pub total_distributed: u256,
    pub time: u64,
}

#[starknet::interface]
pub trait IRevenueDistribution<TContractState> {
    fn add_revenue(ref self: TContractState, category: Category, amount: u256);
    fn calculate_revenue_share(self: @TContractState, holder: ContractAddress) -> u256;
    fn distribute_revenue(ref self: TContractState);
    fn get_holder_revenue(self: @TContractState, holder: ContractAddress) -> u256;
    fn get_revenue_by_category(self: @TContractState, category: Category) -> (u256, u8);
    fn transfer_token_share(ref self: TContractState, to: ContractAddress, amount: u256);
    fn get_holders_by_token(self: @TContractState, token: ContractAddress) -> Array<ContractAddress>;
    fn get_distribution_history(self: @TContractState) -> Array<(ContractAddress, u256, u64)> ;
}
