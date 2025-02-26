// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^1.0.0
use starknet::ContractAddress;
#[starknet::interface]
pub trait IMintable<ContractState> {
    fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256);
}

#[starknet::interface]
pub trait IBurnable<ContractState> {
    fn burn(ref self: ContractState, amount: u256);
}

#[starknet::contract]
pub mod MusicStrk {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::UpgradeableComponent;
    use starknet::{ClassHash, ContractAddress, get_caller_address};

    use super::{IBurnable, IMintable};

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
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MintEvent: MintEvent,
        BurnEvent: BurnEvent,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MintEvent {
        pub recipient: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BurnEvent {
        pub from: ContractAddress,
        pub amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc20.initializer("MusicStrk", "MSTRK");
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl MintableImpl of IMintable<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self.erc20.mint(recipient, amount);
            self.emit(MintEvent { recipient, amount });
        }
    }

    #[abi(embed_v0)]
    impl BurnableImpl of IBurnable<ContractState> {
        fn burn(ref self: ContractState, amount: u256) {
            let burner = get_caller_address();
            self.ownable.assert_only_owner();
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
