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

    // Access control
    fn get_owner(self: @ContractState) -> ContractAddress;
    fn grant_artist_role(ref self: ContractState, artist: ContractAddress);
    fn revoke_artist_role(ref self: ContractState, artist: ContractAddress);
    fn has_artist_role(self: @ContractState, artist: ContractAddress) -> bool;

    // Class hash management
    fn update_token_class_hash(ref self: ContractState, new_class_hash: ClassHash);
    fn get_token_class_hash(self: @ContractState) -> ClassHash;

    // Token state getter functions
    fn get_token_count(self: @ContractState) -> u64;
    fn get_token_at_index(self: @ContractState, index: u64) -> ContractAddress;
    fn get_tokens_by_artist(
        self: @ContractState, artist: ContractAddress,
    ) -> Array<ContractAddress>;
    fn get_artist_for_token(
        self: @ContractState, token_address: ContractAddress,
    ) -> ContractAddress;
    fn get_all_tokens(self: @ContractState) -> Array<ContractAddress>;
    fn is_token_deployed(self: @ContractState, token_address: ContractAddress) -> bool;
}

#[starknet::contract]
pub mod MusicShareTokenFactory {
    use contract_::erc20::{IMusicShareTokenDispatcher, IMusicShareTokenDispatcherTrait};
    use contract_::errors::errors;
    use contract_::events::{RoleGranted, RoleRevoked, TokenDeployedEvent};
    use core::clone::Clone;
    use core::num::traits::Zero;
    use core::traits::Into;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{get_block_timestamp, get_caller_address, get_contract_address};
    use super::*;

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
        token_owners: Map<ContractAddress, ContractAddress>,
        deployed_tokens: Map<ContractAddress, bool>,
        artist_role: Map<ContractAddress, bool>,
        artist_tokens_count: Map<ContractAddress, u64>,
        // artist -> artist token id -> artist token address
        artist_tokens: Map<(ContractAddress, u64), ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenDeployedEvent: TokenDeployedEvent,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        RoleGranted: RoleGranted,
        RoleRevoked: RoleRevoked,
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
            let factory_address = get_contract_address();

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
            let artist_tokens_counter = self.artist_tokens_count.read(caller);
            self.artist_tokens.write((caller, artist_tokens_counter), token_address);
            self.artist_tokens_count.write(caller, artist_tokens_counter + 1);

            // Map token address to its owner
            self.token_owners.write(token_address, caller);

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
                        timestamp: get_block_timestamp(),
                    },
                );

            token_address
        }

        // Access Role management
        fn get_owner(self: @ContractState) -> ContractAddress {
            self.ownable.owner()
        }

        fn grant_artist_role(ref self: ContractState, artist: ContractAddress) {
            // Only owner can grant artist role
            self.ownable.assert_only_owner();
            assert(!artist.is_zero(), errors::ZERO_ADDRESS_DETECTED);
            self.artist_role.write(artist, true);
            self.emit(RoleGranted { artist, timestamp: get_block_timestamp() });
        }

        fn revoke_artist_role(ref self: ContractState, artist: ContractAddress) {
            // Only owner can revoke artist role
            self.ownable.assert_only_owner();
            self.artist_role.write(artist, false);
            self.emit(RoleRevoked { artist, timestamp: get_block_timestamp() });
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

        fn get_token_class_hash(self: @ContractState) -> ClassHash {
            self.token_class_hash.read()
        }

        // Token getter functions
        fn get_token_count(self: @ContractState) -> u64 {
            self.token_count.read()
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

            // Iterate through artist tokens and add them to the array
            while i < count {
                tokens_array.append(self.artist_tokens.read((artist, i)));
                i += 1;
            }
            tokens_array
        }

        fn get_artist_for_token(
            self: @ContractState, token_address: ContractAddress,
        ) -> ContractAddress {
            assert(self.deployed_tokens.read(token_address), errors::TOKEN_NOT_DEPLOYED);
            self.token_owners.read(token_address)
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
