use starknet::{ContractAddress, get_caller_address};

#[starknet::interface]
pub trait Ierc20<ContractState>{
    fn name(self: ContractState) -> felt252;
    fn symbol(self: ContractState) -> felt252;
    fn decimal(self: ContractState, dec: u64) -> u64;
    fn transfer(ref self: ContractState, amount: u256, to: ContractAddress);
    fn transferFrom(ref self: ContractState, from: ContractAddress, to: ContractAddress);
    fn approve(ref self: ContractState, spender: ContractAddress);
    fn allowance(ref self: ContractState, owner: ContractAddress, spender: ContractAddress);
    fn mint();
    fn burn();
}

#[starknet::contract]
pub mod TokenContract {

    use starknet::{ContractAddress, get_caller_address};
    #[storage]
    struct Storage {
        erc20_token: u256,
        token_name: felt252,
        token_symbol: felt252,
        token_decimal: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_name_: felt252, token_symbol_: felt252, token_decimal_: u64) {
        self.token_name.write(token_name_);
        self.token_symbol.write(token_symbol_);
        self.token_decimal.write(token_decimal_);
    }

    #[abi(embed_v0)]
    impl erc20Impl of super::Ierc20<ContractState>{
        fn name(self: ContractState) -> felt252{
            self.token_name.read();
        }

        fn symbol(self: ContractState) -> felt252{
            self.token_symbol.read();
        }

        fn decimal(self: ContractState, dec: u64) -> u64{
            self.token_decimal.read();
        }

        fn transfer(ref self: ContractState, amount: u256, to: ContractAddress){
            //get owners address
            let owner: ContractAddress = ;

            // ensure owner is not address zero

            // ensure only owner can transfer

            // ensure owners balance is => amount to transfer

            // ensure to address is not zero address

            // transfer amount to address to

        }
    }

}