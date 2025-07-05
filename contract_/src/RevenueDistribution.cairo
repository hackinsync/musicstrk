#[starknet::contract]
pub mod RevenueDistribution {
    use alexandria_storage::{List, ListTrait};
    use contract_::IRevenueDistribution::{
        Category, IRevenueDistribution, RevenueAddedEvent, RevenueDistributedEvent,
    };
    use contract_::erc20::MusicStrk::TOTAL_SHARES;
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp};

    const DECIMALS: u256 = 1_000_000;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // External
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        total_revenue: u256,
        holder_revenue: Map<ContractAddress, u256>,
        category_revenue: Map<u8, u256>,
        token_contract: ContractAddress,
        token_holders: Map<
            ContractAddress, List<ContractAddress>,
        >, // token_address -> holders_address
        distribution_history: List<(ContractAddress, u256, u64)>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        RevenueAddedEvent: RevenueAddedEvent,
        RevenueDistributedEvent: RevenueDistributedEvent,
    }


    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, token_contract: ContractAddress,
    ) {
        assert!(!token_contract.is_zero(), "invalid_token_contractaddress");
        self.token_contract.write(token_contract);
        // Set owner
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl RevenueDistributionImpl of IRevenueDistribution<ContractState> {
        fn transfer_token_share(ref self: ContractState, to: ContractAddress, amount: u256) {
            let token_contract = self.token_contract.read();
            let erc20 = IERC20Dispatcher { contract_address: token_contract };

            erc20.transfer(to, amount);

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
            let erc20 = IERC20Dispatcher { contract_address: token_contract };

            if TOTAL_SHARES == 0 {
                return 0_u256;
            }

            let balance = erc20.balance_of(holder);
            (balance * DECIMALS)
        }

        fn distribute_revenue(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let token_contract = self.token_contract.read();
            let holders = self.token_holders.read(token_contract);
            let total_revenue = self.total_revenue.read();

            assert!(total_revenue > 0, "No_revenue_for_Distribute");

            let mut i: u32 = 0;
            while i < holders.len() {
                let revenue_share = (self.calculate_revenue_share(holders[i]) * total_revenue)
                    / (TOTAL_SHARES * DECIMALS);

                let current_holder_revenue = self.holder_revenue.read(holders[i]);
                self.holder_revenue.write(holders[i], current_holder_revenue + revenue_share);

                // Track distribution history
                let mut history = self.distribution_history.read();
                let _idx = history.append((holders[i], revenue_share, get_block_timestamp()));
                self.distribution_history.write(history);

                i += 1;
            };

            self.total_revenue.write(0);
            self
                .emit(
                    RevenueDistributedEvent {
                        total_distributed: total_revenue, time: get_block_timestamp(),
                    },
                );
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


        fn get_holders_by_token(
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

        fn get_distribution_history(self: @ContractState) -> Array<(ContractAddress, u256, u64)> {
            let mut history = self.distribution_history.read();

            let mut history_array = ArrayTrait::new();

            let mut i: u32 = 0;

            loop {
                if i >= history.len() {
                    break;
                }

                let id = history[i];
                history_array.append(id);

                i += 1;
            };

            history_array
        }
    }
}
