// SPDX-License-Identifier: MIT

use core::array::{Array, ArrayTrait};
use core::byte_array::ByteArray;
use starknet::syscalls::deploy_syscall;
use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait IMusicShareTokenFactory<ContractState> {
    fn deploy_music_token(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        metadata_uri: ByteArray,
    ) -> ContractAddress;

    // Access control for artists
    fn grant_artist_role(ref self: ContractState, artist: ContractAddress);
    fn revoke_artist_role(ref self: ContractState, artist: ContractAddress);
    fn has_artist_role(self: @ContractState, artist: ContractAddress) -> bool;

    // Token state getter functions
    fn get_token_count(self: @ContractState) -> u64;
    fn get_token_at_index(self: @ContractState, index: u64) -> ContractAddress;
    fn get_tokens_by_artist(
        self: @ContractState, artist: ContractAddress,
    ) -> Array<ContractAddress>;
    fn get_all_tokens(self: @ContractState) -> Array<ContractAddress>;
    fn is_token_deployed(self: @ContractState, token_address: ContractAddress) -> bool;

    // Class hash management
    fn update_token_class_hash(ref self: ContractState, new_class_hash: ClassHash);
    fn get_token_class_hash(self: @ContractState) -> ClassHash;
}

#[starknet::contract]
pub mod MusicShareTokenFactory {
    use contract_::erc20::{IMusicShareTokenDispatcher, IMusicShareTokenDispatcherTrait};
    use contract_::errors::errors;
    use core::clone::Clone;
    use core::num::traits::Zero;
    use core::traits::Into;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::get_caller_address;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::{
        Array, ArrayTrait, ByteArray, ClassHash, ContractAddress, IMusicShareTokenFactory,
        deploy_syscall,
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
        artist_role: Map<ContractAddress, bool>,
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

            // Check if caller is owner or has artist role
            assert(
                self.ownable.owner() == caller || self.artist_role.read(caller),
                errors::CALLER_NOT_AUTH_OR_ARTIST,
            );

            // Deploy a new token contract
            let class_hash = self.token_class_hash.read();

            // Get the factory (this contract) address
            let factory_address = starknet::get_contract_address();

            // Create calldata for the token constructor
            let mut constructor_calldata = ArrayTrait::new();

            // Add the owner (factory) as parameter to the constructor
            constructor_calldata.append(factory_address.into());

            // Generate a unique salt based on token count and caller
            let token_count = self.token_count.read();
            let salt = token_count.into() + caller.into();

            // Deploy the contract
            let (token_address, _) = deploy_syscall(
                class_hash, salt, constructor_calldata.span(), false,
            )
                .expect('Token deployment failed');

            // Initialize token as factory
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

            // Transfer ownership of token to artist
            let ownable = IOwnableDispatcher { contract_address: token_address };
            ownable.transfer_ownership(caller);

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

        // Artist role management
        fn grant_artist_role(ref self: ContractState, artist: ContractAddress) {
            // Only owner can grant artist role
            self.ownable.assert_only_owner();
            assert(!artist.is_zero(), errors::ZERO_ADDRESS_DETECTED);
            self.artist_role.write(artist, true);
        }

        fn revoke_artist_role(ref self: ContractState, artist: ContractAddress) {
            // Only owner can revoke artist role
            self.ownable.assert_only_owner();
            self.artist_role.write(artist, false);
        }

        fn has_artist_role(self: @ContractState, artist: ContractAddress) -> bool {
            self.artist_role.read(artist)
        }

        // Class hash management
        fn update_token_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            // Only owner can update class hash
            self.ownable.assert_only_owner();
            // Ensure the class hash is not zero
            assert(!new_class_hash.is_zero(), errors::INVALID_CLASS_HASH);
            self.token_class_hash.write(new_class_hash);
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
            }
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
            }

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
