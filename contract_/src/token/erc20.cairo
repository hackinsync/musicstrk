use starknet::{ContractAddress, get_caller_address};

#[starknet::interface]
pub trait Ierc20<ContractState>{
    fn name(self: @ContractState) -> felt252;
    fn symbol(self: @ContractState) -> felt252;
    fn decimal(self: @ContractState, dec: u64) -> u64;
    fn balance_of(self: @ContractState, account: ContractAddress) -> u256;
    fn transfer(ref self: ContractState, amount: u256, to_: ContractAddress);
    fn transferFrom(ref self: ContractState, from_: ContractAddress, to_: ContractAddress, amount: u256);
    fn approve(ref self: ContractState, spender: ContractAddress);
    fn allowance(ref self: ContractState, owner: ContractAddress, spender: ContractAddress);
    fn mint();
    fn burn();
}

#[starknet::contract]
pub mod TokenContract {

    use starknet::{ContractAddress, get_caller_address};
    use starknet::contract_address_const;

    #[storage]
    struct Storage {
        erc20_token: u256,
        token_name: felt252,
        token_symbol: felt252,
        token_decimal: u64,
        owner: ContractAddress,
        sender: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        balances: LegacyMap<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_name_: felt252, token_symbol_: felt252, token_decimal_: u64) {
        let owner: ContractAddress = get_caller_address();
        self.token_name.write(token_name_);
        self.token_symbol.write(token_symbol_);
        self.token_decimal.write(token_decimal_);
        self.owner.write(owner);
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

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256{
            self.balances.read(account);
        }

        fn transfer(ref self: ContractState, amount: u256, to_: ContractAddress){
            //get sender/caller address
            let sender: ContractAddress = get_caller_address();

            // ensure owner is not address zero
            assert(sender != zero_address(), "sender can't be address zero");

            // ensure to address is not zero address
            assert(to_ != zero_address(), "to_address can't be address zero")

            // ensure owners balance is => amount to transfer
            let sender_balance: u256 = self.balances.read(sender);

            // ensure owner's balance is => amount
            assert(sender_balance >= amount, "insufficient balance");

            // remove amount from sender
            self.balances.write(sender, sender_balance - amount);

            // get the current balance of to_address
            let to_current_balance = self.balances.read(to_);

            //add amount to to_current_balance 
            let to_new_balance = to_current_balance + amount;

            // transfer amount to to_address
            self.balances.write(to_, to_new_balance)

        }

        fn transferFrom(ref self: ContractState, from_: ContractAddress, to_: ContractAddress, amount: u256){
            //get caller address
            let caller: ContractAddress = get_caller_address();

            // ensure caller is not address zero
            assert(caller != zero_address(), "caller can't be address zero");

            //ensure from is not address zero
            assert(from_ != zero_address(), "from can't be address zero");

            //ensure to is not address zero
            assert(to_ != zero_address(), "to can't be address zero");

            // ensure owners balance is => amount to transfer
            let from_balance: u256 = self.balances.read(from_);

            // ensure owner's balance is => amount
            assert(from_balance >= amount, "insufficient balance");

            //remove amount from from_ balance
            self.balances.write(from_, from_balance - amount);

            // get the current balance of to_address
            let to_current_balance = self.balances.read(to_);

            // transfer amount from from_address to to_address
            self.from.write(to_, to_current_balance + amount)
        }


    }

    #[generate_trait]
    impl internalImpl of internalTrait{
        fn zero_address() -> ContractAddress {
            contract_address_const::<0x0>()
        }
    }

}