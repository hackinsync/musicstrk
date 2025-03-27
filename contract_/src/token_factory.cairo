// SPDX-License-Identifier: MIT

use core::array::{Array, ArrayTrait};
use core::byte_array::ByteArray;
use starknet::{ContractAddress, ClassHash};
use starknet::syscalls::deploy_syscall;

#[starknet::interface]
pub trait IMusicShareToken<ContractState> {
    fn initialize(
        ref self: ContractState,
        recipient: ContractAddress,
        metadata_uri: ByteArray,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
    );
    fn get_metadata_uri(self: @ContractState) -> ByteArray;
    fn get_decimals(self: @ContractState) -> u8;
}

#[starknet::interface]
pub trait IMusicShareTokenFactory<ContractState> {
    fn deploy_music_token(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        metadata_uri: ByteArray,
    ) -> ContractAddress;
    fn get_token_count(self: @ContractState) -> u64;
    fn get_token_class_hash(self: @ContractState) -> ClassHash;
    fn get_token_at_index(self: @ContractState, index: u64) -> ContractAddress;
    fn get_tokens_by_artist(
        self: @ContractState, artist: ContractAddress,
    ) -> Array<ContractAddress>;
    fn get_all_tokens(self: @ContractState) -> Array<ContractAddress>;
    fn is_token_deployed(self: @ContractState, token_address: ContractAddress) -> bool;
}

#[starknet::contract]
pub mod MusicShareTokenFactory {
    use contract_::errors::errors;
    use core::clone::Clone;
    use core::option::OptionTrait;
    use core::result::Result;
    use core::traits::Into;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, UpgradeableComponent};
    use starknet::{
        get_caller_address,
        storage::{
            Map, MutableVecTrait, Vec, VecTrait, StoragePathEntry, StorageMapReadAccess,
            StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess,
        },
    };
    use super::{
        Array, ArrayTrait, ByteArray, ClassHash, ContractAddress, deploy_syscall,
        IMusicShareTokenFactory, IMusicShareToken, IMusicShareTokenDispatcher,
        IMusicShareTokenDispatcherTrait,
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        token_class_hash: ClassHash,
        token_count: u64,
        tokens: Map<u64, ContractAddress>,
        deployed_tokens: Map<ContractAddress, bool>,
        artist_tokens_count: Map<ContractAddress, u64>,
        artist_tokens_items: Map<(ContractAddress, u64), ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenDeployedEvent: TokenDeployedEvent,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenDeployedEvent {
        pub deployer: ContractAddress,
        pub token_address: ContractAddress,
        pub name: ByteArray,
        pub symbol: ByteArray,
        pub metadata_uri: ByteArray,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, token_class_hash: ClassHash) {
        // Set owner
        self.ownable.initializer(owner);

        // Set the class hash for the token
        self.token_class_hash.write(token_class_hash);

        // Initialize token count
        self.token_count.write(0);
    }

    #[abi(embed_v0)]
    impl MusicShareTokenFactoryImpl of IMusicShareTokenFactory<ContractState> {
        fn deploy_music_token(
            ref self: ContractState,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8,
            metadata_uri: ByteArray,
        ) -> ContractAddress {
            // Get the caller who will be the owner and recipient of the token
            let caller = get_caller_address();

            // Deploy a new token contract
            let class_hash = self.token_class_hash.read();

            // Create calldata for the constructor
            let mut constructor_calldata = ArrayTrait::new();

            // Add the owner (caller) as parameter to the constructor
            constructor_calldata.append(caller.into());

            // Generate a unique salt based on token count and caller
            let token_count = self.token_count.read();
            let salt = token_count.into() + caller.into();

            // Deploy the contract
            let (token_address, _) = deploy_syscall(
                class_hash, salt, constructor_calldata.span(), false // deploy from zero
            )
                .unwrap();
                // .expect('Token deployment failed');

            // Initialize the token with parameters using the dispatcher
            let token = IMusicShareTokenDispatcher { contract_address: token_address };
            token.initialize(caller, metadata_uri.clone(), name.clone(), symbol.clone(), decimals);

            // Update token registry
            self.tokens.write(token_count, token_address);
            self.token_count.write(token_count + 1);
            self.deployed_tokens.write(token_address, true);

            // Add token to artist's list
            let user_count = self.artist_tokens_count.read(caller);
            self.artist_tokens_items.write((caller, user_count), token_address);
            self.artist_tokens_count.write(caller, user_count + 1);

            // Emit deployment event
            self
                .emit(
                    TokenDeployedEvent {
                        deployer: caller,
                        token_address: token_address,
                        name: name.clone(),
                        symbol: symbol.clone(),
                        metadata_uri: metadata_uri.clone(),
                    },
                );

            token_address
        }

        // Token getter functions
        fn get_token_count(self: @ContractState) -> u64 {
            self.token_count.read()
        }

        fn get_token_class_hash(self: @ContractState) -> ClassHash {
            self.token_class_hash.read()
        }

        fn get_token_at_index(self: @ContractState, index: u64) -> ContractAddress {
            assert(index < self.token_count.read(), errors::INDEX_OUT_OF_BOUNDS);
            self.tokens.read(index)
        }

        fn get_tokens_by_artist(
            self: @ContractState, artist: ContractAddress,
        ) -> Array<ContractAddress> {
            let count = self.artist_tokens_count.read(artist);
            let mut tokens_array = ArrayTrait::new();
            let mut i: u64 = 0;

            // Iterate through artist  tokens and add them to the array
            while i < count {
                tokens_array.append(self.artist_tokens_items.read((artist, i)));
                i += 1;
            };
            tokens_array
        }

        fn get_all_tokens(self: @ContractState) -> Array<ContractAddress> {
            let token_count = self.token_count.read();
            let mut all_tokens = ArrayTrait::new();

            // Iterate through all tokens and add them to the array
            let mut i: u64 = 0;
            while i < token_count {
                all_tokens.append(self.tokens.read(i));
                i += 1;
            };

            all_tokens
        }

        fn is_token_deployed(self: @ContractState, token_address: ContractAddress) -> bool {
            self.deployed_tokens.read(token_address)
        }
    }

    //
    // Upgradeable
    //
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
