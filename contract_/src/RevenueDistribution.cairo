#[starknet::contract]
pub mod RevenueDistribution {
    use starknet::storage::StorageMapReadAccess;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use core::num::traits::Zero;

    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StorageMapWriteAccess,
    };
    use contract_::IRevenueDistribution::{
        IRevenueDistribution, Category, RevenueAddedEvent, RevenueDistributedEvent,
    };
    use contract_::erc20::{IMusicShareTokenDispatcher, IMusicShareTokenDispatcherTrait};
    use contract_::erc20::MusicStrk::TOTAL_SHARES;
    use alexandria_storage::{ListTrait, List};

    const DECIMALS: u256 = 1_000_000; // 6 decimal places

    #[storage]
    struct Storage {
        total_revenue: u256,
        holder_revenue: Map<ContractAddress, u256>,
        category_revenue: Map<u8, u256>,
        token_contract: ContractAddress,
        artist_tokens: Map<
            ContractAddress, List<ContractAddress>,
        >, // holder_address -> tokens_address 
        token_holders: Map<
            ContractAddress, List<ContractAddress>,
        > // token_address -> holders_address
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RevenueAddedEvent: RevenueAddedEvent,
        RevenueDistributedEvent: RevenueDistributedEvent,
    }


    #[constructor]
    fn constructor(ref self: ContractState, token_contract: ContractAddress) {
        assert!(!token_contract.is_zero(), "invalid_token_contractaddress");
        self.token_contract.write(token_contract);
    }

    #[abi(embed_v0)]
    impl RevenueDistributionImpl of IRevenueDistribution<ContractState> {
        fn transfer_token_share(ref self: ContractState, to: ContractAddress, amount: u256) {
            let token_contract = self.token_contract.read();
            let caller = get_caller_address();
            let erc20 = IMusicShareTokenDispatcher { contract_address: token_contract };

            assert!(erc20.get_balance_of(caller) >= amount, "caller_have_less_token");

            erc20.transfer_token(caller, to, amount);

            let mut holders = self.token_holders.read(token_contract);
            let _index = holders.append(to);
            self.token_holders.write(token_contract, holders);
        }

        fn add_revenue(ref self: ContractState, category: Category, amount: u256) {
            let current_revenue = self.total_revenue.read();
            self.total_revenue.write(current_revenue + amount);

            let (old_revenue, cat) = self.get_revenue_by_category(category);
            self.category_revenue.write(cat, old_revenue + amount);

            self.emit(RevenueAddedEvent { category, amount, time: get_block_timestamp() });
        }

        fn calculate_revenue_share(self: @ContractState, holder: ContractAddress) -> u256 {
            let token_contract = self.token_contract.read();
            let erc20 = IMusicShareTokenDispatcher { contract_address: token_contract };

            if TOTAL_SHARES == 0 {
                return 0_u256;
            }
            let balance = erc20.get_balance_of(holder);
            (balance * 100) / TOTAL_SHARES
        }

        fn distribute_revenue(ref self: ContractState) {
            let token_contract = self.token_contract.read();

            let holders = self.token_holders.read(token_contract);
            let total_revenue = self.total_revenue.read();

            assert!(total_revenue > 0, "No_revenue_for_Distribute");

            let mut i: u32 = 0;
            loop {
                if i >= holders.len() {
                    break;
                }

                let revenue_share = (self.calculate_revenue_share(holders[i]) * total_revenue)
                    / DECIMALS;
                let current_holder_revenue = self.holder_revenue.read(holders[i]);
                self.holder_revenue.write(holders[i], current_holder_revenue + revenue_share);
                i += 1;
            };
            self
                .emit(
                    RevenueDistributedEvent {
                        total_distributed: total_revenue, time: get_block_timestamp(),
                    },
                );
            self.total_revenue.write(0); // Reset total revenue after distribution
        }

        fn get_holder_revenue(self: @ContractState, holder: ContractAddress) -> u256 {
            self.holder_revenue.read(holder)
        }

        fn get_revenue_by_category(self: @ContractState, category: Category) -> (u256, u8) {
            let cat = match category {
                Category::TICKET => 1_u8,
                Category::MERCH => 2_u8,
                Category::STREAMING => 3_u8,
                _ => 4_u8,
            };
            (self.category_revenue.read(cat), cat)
        }

        fn get_tokens_by_artist(
            self: @ContractState, artist: ContractAddress,
        ) -> Array<ContractAddress> {
            let mut artist_tokens = self.artist_tokens.read(artist);

            let mut tokens = ArrayTrait::new();

            let mut i: u32 = 0;

            loop {
                if i >= artist_tokens.len() {
                    break;
                }

                let id = artist_tokens[i];
                tokens.append(id);

                i += 1;
            };

            tokens
        }

        fn get_artist_by_token(
            self: @ContractState, token: ContractAddress,
        ) -> Array<ContractAddress> {
            let mut artists = self.token_holders.read(token);

            let mut artist_array = ArrayTrait::new();

            let mut i: u32 = 0;

            loop {
                if i >= artists.len() {
                    break;
                }

                let id = artists[i];
                artist_array.append(id);

                i += 1;
            };

            artist_array
        }
    }
}
