// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^1.0.0
use starknet::ContractAddress;
use core::byte_array::ByteArray;

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
    fn get_balance_of(self: @ContractState, account: ContractAddress) -> u256;
    fn transfer_token(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    );
}

#[starknet::interface]
pub trait IBurnable<ContractState> {
    fn burn(ref self: ContractState, amount: u256);
}

#[starknet::contract]
pub mod MusicStrk {
    // use openzeppelin_token::erc20::interface::IERC20Mixin;
    use contract_::errors::errors;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::UpgradeableComponent;
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    use core::num::traits::Zero;
    use core::byte_array::ByteArray;
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::clone::Clone;

    use super::{IBurnable, IMusicShareToken};

    // Token hard cap - exactly 100 tokens per contract
    pub const TOTAL_SHARES: u256 = 100_u256;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Immutable metadata URI for the share token (typically IPFS link)
        share_metadata_uri: ByteArray,
        // Flag to track if the token has been initialized
        initialized: bool,
        // Decimal units for the token
        decimal_units: u8,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenInitializedEvent: TokenInitializedEvent,
        BurnEvent: BurnEvent,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenInitializedEvent {
        pub recipient: ContractAddress,
        pub amount: u256,
        pub metadata_uri: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BurnEvent {
        pub from: ContractAddress,
        pub amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        // Use Zero trait for checking zero address
        assert(!owner.is_zero(), errors::OWNER_ZERO_ADDRESS);
        self.ownable.initializer(owner);
        // Initialize the storage value directly
        self.initialized.write(false);
    }

    #[abi(embed_v0)]
    impl MusicShareTokenImpl of IMusicShareToken<ContractState> {
        fn initialize(
            ref self: ContractState,
            recipient: ContractAddress,
            metadata_uri: ByteArray,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8,
        ) {
            // Only the owner can initialize the token
            self.ownable.assert_only_owner();

            // Ensure the token hasn't been initialized yet
            assert!(!self.initialized.read(), "Token already initialized");

            // Ensure the recipient address is valid
            assert(!recipient.is_zero(), errors::RECIPIENT_ZERO_ADDRESS);

            // Initialize ERC20 token with name, symbol and decimals
            self.erc20.initializer(name, symbol);

            // Set the decimal units
            self.decimal_units.write(decimals);

            // Clone the metadata_uri before writing it to storage so we can use it in the event
            let metadata_uri_clone = metadata_uri.clone();

            // Set the metadata URI (immutable)
            self.share_metadata_uri.write(metadata_uri);

            // Mint exactly 100 tokens to the recipient
            self.erc20.mint(recipient, TOTAL_SHARES);

            // Mark as initialized
            self.initialized.write(true);

            // Emit initialization event
            self
                .emit(
                    TokenInitializedEvent {
                        recipient, amount: TOTAL_SHARES, metadata_uri: metadata_uri_clone,
                    },
                );
        }

        fn get_metadata_uri(self: @ContractState) -> ByteArray {
            // Read the storage value
            self.share_metadata_uri.read()
        }

        fn get_decimals(self: @ContractState) -> u8 {
            // Read the decimals configuration
            self.decimal_units.read()
        }

        fn get_balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn transfer_token(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            self.erc20.transfer_from(from, to, amount);
        }
    }

    #[abi(embed_v0)]
    impl BurnableImpl of IBurnable<ContractState> {
        fn burn(ref self: ContractState, amount: u256) {
            let burner = get_caller_address();
            self.erc20.burn(burner, amount);
            self.emit(BurnEvent { from: burner, amount });
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
