#[starknet::contract]
pub mod RevenueDistribution {
    use contract::errors::errors;
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_block_timestamp};
    use core::num::traits::Zero;
    use core::byte_array::ByteArray;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map, Array,
        ByteArray,
    };
    use core::clone::Clone;

    use contract::interfaces::{
        IRevenueDistribution, IRevenueDistributionDispatcher, IRevenueDistributionDispatcherTrait,
        IMusicShareToken, IMusicShareTokenDispatcher,
    };

    #[storage]
    struct Storage {
        // total revenue accumulated by category 
        total_revenue: u256,
        // Revenue owed to each token holder
        holder_revenue: Map<ContractAddress, u256>,
        // Revenue distribution history
        category_revenue: Map<ByteArray, u256>,
        // Store the token contract address
        token_contract: ContractAddress,
        // Mapping of artist addresses to their associated tokens
        artist_tokens: Map<ContractAddress, Array<ByteArray>>,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        EscrowAddressUpdated: EscrowAddressEvent,
        WagerCreated: WagerCreatedEvent,
        WagerJoined: WagerJoinedEvent,
        OutcomeSubmitted: OutcomeSubmittedEvent,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }


    #[constructor]
    fn constructor(ref self: ContractState, token_contract: ContractAddress) {
        assert!(!token_contract.is_zero(), "invalid_token_contractaddress");
        self.token_contract.write(token_contract);
    }

    #[abi(embed_v0)]
    impl RevenueDistributionImpl of IRevenueDistribution<ContractState> {
        fn add_revenue(ref self: ContractState, category: ByteArray, amount: u256) {
            // Update total revenue for the category
            let current_revenue = self.total_revenue.read();
            self.total_revenue.write(current_revenue + amount);

            let old_amount = self.category_revenue.read(category);
            self.category_revenue.write(category, old_amount + amount);

            self.emit(RevenueAddedEvent { category, amount, time: get_block_timestamp() });
        }

        //  calculate revenue share  gives percentage share in revenue
        fn calculate_revenue_share(self: @ContractState, holder: ContractAddress) -> u256 {
            let token_contract = self.token_contract.read();
            let total_supply = IMusicShareTokenDispatcher::total_supply(token_contract);

            if total_supply == 0 {
                return 0;
            }

            let balance = IMusicShareTokenDispatcher::balance_of(token_contract, holder);

            balance / total_supply
        }

        fn distribute_revenue(ref self: ContractState) {
            let token_contract = self.token_contract.read();
            let total_supply = IMusicShareTokenDispatcher::total_supply(token_contract);

            let holders = IMusicShareTokenDispatcher::get_all_holders(token_contract);

            let total_revenue = self.total_revenue.read();
            assert!(total_revenue > 0, "No_revenue_for_Distribute");

            for holder in holders.iter() {
                let revenue_share = self.calculate_revenue_share(*holder) * total_revenue;
                let current_holder_revenue = self.holder_revenue.read(*holder);
                self.holder_revenue.write(*holder, current_holder_revenue + revenue_share);
            }
        }


        fn get_holder_revenue(self: @ContractState, holder: ContractAddress) -> u256 {
            self.holder_revenue.read(holder)
        }

        fn get_revenue_by_category(self: @ContractState, category: ByteArray) -> u256 {
            self.category_revenue.read(category)
        }


        fn get_tokens_by_artist(self: @ContractState, artist: ContractAddress) -> Array<ByteArray> {
            self.artist_tokens.read(artist).clone()
        }

    }
}
