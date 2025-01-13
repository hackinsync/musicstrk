use starknet::{ContractAddress, get_caller_address};

#[starknet::interface]
pub trait Ierc20<ContractState>{
    fn name(self: @ContractState) -> felt252;
    fn symbol(self: @ContractState) -> felt252;
    fn decimal(self: @ContractState, dec: u64) -> u64;
    fn balance_of(self: @ContractState, account: ContractAddress) -> u256;
    fn totalSupply(self: @ContractAddress) -> u256;
    fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool;
    fn transfer(ref self: ContractState, amount: u256, to_: ContractAddress) -> bool;
    fn transferFrom(ref self: ContractState, from_: ContractAddress, to_: ContractAddress, amount: u256) -> bool;
    fn getAllowance(ref self: ContractState, spender: ContractAddress) -> u256;
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
        totalSupply: u256,
        owner: ContractAddress,
        sender: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        balances: LegacyMap<ContractAddress, u256>,
        allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
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

        fn totalSupply(self: @ContractAddress) -> u256{
            self.totalSupply.read();
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool{
            let owner: ContractAddress = get_caller_address();

            asser(owner != contract_address_const<0x0>, "owner can't be address zero")

            assert(spender != contract_address_const<0x0>, "invalid spender");

            self.allowances.write((owner, spender), amount);

            true
        }

        fn transfer(ref self: ContractState, amount: u256, to_: ContractAddress) -> bool{
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

            true

        }

        fn transferFrom(ref self: ContractState, from_: ContractAddress, to_: ContractAddress, amount: u256) -> bool{
            //get caller address
            let caller: ContractAddress = get_caller_address();

            // ensure caller is not address zero
            assert(caller != zero_address(), "caller can't be address zero");

            //check allowance
            let allowance = self.allowances.read(from, caller);

            //ensure allowance is greater/equal to amount
            assert(allowance >= amount, 'insufficient allowance');


            //check balanace
            let from_balance = self.balances.read(from_);
            assert(from_balance >= amount, "insufficient balance");

            //update allowance
            self.allowances.write((from_, caller), from_balance - amount);

            //update balance, taking amount from from_
            self.balanaces.write(from_, from_balance - amount);

            //grt recipient balance
            let to_current_balance = self.balances.read(to_);

            //update to_ balance
            self.balanaces.write(to_, to_current_balance + amount);

            true
        }

        fn getAllowance(ref self: ContractState, owner: ContractAddress, spender: ContractAddress) -> u256{
            self.allowances.read(owner, spender);
        }

    }

    #[generate_trait]
    impl internalImpl of internalTrait{
        fn zero_address() -> ContractAddress {
            contract_address_const::<0x0>()
        }
    }

}