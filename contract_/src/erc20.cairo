use starknet::{ContractAddress};
use super::errors;
#[starknet::interface]
pub trait Ierc20<ContractState> {
    fn name(self: @ContractState) -> felt252;
    fn symbol(self: @ContractState) -> felt252;
    fn decimal(self: @ContractState) -> u64;
    fn balance_of(self: @ContractState, account: ContractAddress) -> u256;
    fn total_supply(self: @ContractState) -> u256;
    fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool;
    fn transfer(ref self: ContractState, amount: u256, to_: ContractAddress) -> bool;
    fn transfer_from(
        ref self: ContractState, from_: ContractAddress, to_: ContractAddress, amount: u256
    ) -> bool;
    fn allowance(
        self: @ContractState, owner: ContractAddress, spender: ContractAddress
    ) -> u256;
    fn mint(ref self: ContractState, to_: ContractAddress, amount: u256);
    fn burn(ref self: ContractState, amount: u256);
}

#[starknet::contract]
pub mod TokenContract {
    use starknet::event::EventEmitter;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::contract_address_const;
    use super::Ierc20;
    use core::starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };
    use super::errors::errors;




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
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: TransferEvent,
        Approval: ApprovalEvent,
        Mint: MintEvent,
        Burn: BurnEvent,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferEvent {
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ApprovalEvent {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct MintEvent {
        to: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct BurnEvent {
        from: ContractAddress,
        value: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, token_name_: felt252, token_symbol_: felt252, token_decimal_: u64
    ) {
        let owner: ContractAddress = get_caller_address();

        self.token_name.write(token_name_);
        self.token_symbol.write(token_symbol_);
        self.token_decimal.write(token_decimal_);
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl erc20Impl of Ierc20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.token_name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.token_symbol.read()
        }

        fn decimal(self: @ContractState) -> u64 {
            self.token_decimal.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.entry(account).read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.totalSupply.read()
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let owner: ContractAddress = get_caller_address();

            let zero_address = contract_address_const::<0x0>();

            assert(owner != zero_address, errors::OWNER_ZERO_ADDRESS);

            assert(spender != zero_address, errors::INVALID_SENDER);

            self.allowances.entry((owner, spender)).write(amount);

            self
                .emit(
                    Event::Approval(
                        ApprovalEvent { owner: owner, spender: spender, value: amount, }
                    )
                );

            true
        }

        fn transfer(ref self: ContractState, amount: u256, to_: ContractAddress) -> bool {
            // get sender/caller address
            let sender: ContractAddress = get_caller_address();
            let zero_address = contract_address_const::<0x0>();

            // ensure sender is not address zero
            assert(sender != zero_address, errors::SENDER_ZERO_ADDRESS);

            // ensure to address is not zero address
            assert(to_ != zero_address, errors::RECIPIENT_ZERO_ADDRESS);

            // get sender's balance using entry()
            let sender_balance: u256 = self.balances.entry(sender).read();

            // ensure sender's balance is >= amount
            assert(sender_balance >= amount, errors::INSUFFICIENT_BALANCE);

            // remove amount from sender using entry()
            self.balances.entry(sender).write(sender_balance - amount);

            // get the current balance of to_address using entry()
            let to_current_balance = self.balances.entry(to_).read();

            // transfer amount to to_address using entry()
            self.balances.entry(to_).write(to_current_balance + amount);

            self.emit(Event::Transfer(TransferEvent { from: sender, to: to_, value: amount, }));

            true
        }

        fn transfer_from(
            ref self: ContractState, from_: ContractAddress, to_: ContractAddress, amount: u256
        ) -> bool {
            let caller: ContractAddress = get_caller_address();
            let zero_address = contract_address_const::<0x0>();

            assert(caller != zero_address, errors::CALLER_ZERO_ADDRESS);

            // Using entry() for compound key Map
            let allowance = self.allowances.entry((from_, caller)).read();
            assert(allowance >= amount, errors::INSUFFICIENT_ALLOWANCE);

            let from_balance = self.balances.entry(from_).read();
            assert(from_balance >= amount, errors::INSUFFICIENT_BALANCE);

            // Update allowance using entry()
            self.allowances.entry((from_, caller)).write(allowance - amount);

            // Update balances using entry()
            self.balances.entry(from_).write(from_balance - amount);
            let to_balance = self.balances.entry(to_).read();
            self.balances.entry(to_).write(to_balance + amount);

            self.emit(Event::Transfer(TransferEvent { from: from_, to: to_, value: amount }));

            true
        }


        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.allowances.entry((owner, spender)).read()
        }

        fn mint(ref self: ContractState, to_: ContractAddress, amount: u256) {
            //get caller
            let caller: ContractAddress = get_caller_address();

            let zero_address = contract_address_const::<0x0>();
            //get owner
            let owner: ContractAddress = self.owner.read();

            //ensure to_ is not address zero
            assert(to_ != zero_address, errors::RECIPIENT_ZERO_ADDRESS);
            //ensure caller is not address zero
            assert(caller != zero_address, errors::CALLER_ZERO_ADDRESS);

            //ensure caller is the owner
            assert(caller == owner, errors::CALLER_NOT_OWNER);

            //get current ballance
            let to_current_balance = self.balances.entry(to_).read();
            //increase to_ balance with amount
            self.balances.entry(to_).write(to_current_balance + amount);

            //get the current total supply
            let current_supply = self.totalSupply.read();
            //increase total supply with amount
            self.totalSupply.write(current_supply + amount);

            self.emit(Event::Mint(MintEvent { to: to_, value: amount, }));
        }

        fn burn(ref self: ContractState, amount: u256) {
            //get caller
            let caller: ContractAddress = get_caller_address();

            let zero_address = contract_address_const::<0x0>();
            //get owner
            let owner: ContractAddress = self.owner.read();

            //ensure caller is not address zero
            assert(caller != zero_address, errors::CALLER_ZERO_ADDRESS);

            //ensure caller is the owner
            assert(caller == owner, errors::CALLER_NOT_OWNER);

            //get callers current balance
            let caller_balance = self.balances.entry(caller).read();
            //reduce callers balance with amount
            self.balances.entry(caller).write(caller_balance - amount);

            //get the current total supply
            let current_supply = self.totalSupply.read();
            //substract amount from current total supply
            self.totalSupply.write(current_supply - amount);

            self.emit(Event::Burn(BurnEvent { from: caller, value: amount, }));
        }
    }

    #[generate_trait]
    impl internalImpl of internalTrait {
        fn zero_address() -> ContractAddress {
            contract_address_const::<0x0>()
        }
    }
}
