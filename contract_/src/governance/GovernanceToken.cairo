// SPDX-License-Identifier: MIT
use starknet::ContractAddress;

#[starknet::interface]
pub trait IGovernanceToken<ContractState> {
    fn set_governance_contracts(
        ref self: ContractState,
        proposal_system: ContractAddress,
        voting_mechanism: ContractAddress,
    );
    fn get_governance_contracts(self: @ContractState) -> (ContractAddress, ContractAddress);
}

#[starknet::interface]
pub trait IERC20Extension<ContractState> {
    fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: ContractState, amount: u256);
    fn get_decimals(self: @ContractState) -> u8;
}

#[starknet::contract]
pub mod GovernanceToken {
    use contract_::errors::errors;
    use contract_::governance::ProposalSystem::{
        IProposalSystemDispatcher, IProposalSystemDispatcherTrait,
    };
    use contract_::governance::VotingMechanism::{
        IVotingMechanismDispatcher, IVotingMechanismDispatcherTrait,
    };
    use core::array::ArrayTrait;
    use core::byte_array::ByteArray;
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::upgrades::{interface::IUpgradeable, UpgradeableComponent};
    use starknet::{
        ClassHash, ContractAddress, get_caller_address, get_contract_address,
        storage::{StoragePointerReadAccess, StoragePointerWriteAccess},
    };
    use super::*;

    // OpenZeppelin Components
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External Mixins/Implementations
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal Implementations
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        decimals: u8,
        proposal_system: ContractAddress,
        voting_mechanism: ContractAddress,
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
        GovernanceTokenTransfer: GovernanceTokenTransfer,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MintEvent {
        pub to: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BurnEvent {
        pub from: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GovernanceTokenTransfer {
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub amount: u256,
        pub active_proposals_affected: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        owner: ContractAddress,
        proposal_system: ContractAddress,
        voting_mechanism: ContractAddress,
    ) {
        // Use Zero trait for sanity checks
        let caller = get_caller_address();
        assert(!caller.is_zero(), errors::CALLER_ZERO_ADDRESS);
        assert(!owner.is_zero(), errors::OWNER_ZERO_ADDRESS);

        // Initialize ERC20 storage
        self.erc20.initializer(name, symbol);

        // Initialize Ownable storage
        self.ownable.initializer(owner);

        // Store decimal units
        self.decimals.write(decimals);

        // Set governance contracts
        self.set_governance_contracts(proposal_system, voting_mechanism);
    }

    #[abi(embed_v0)]
    impl GovernanceTokenImpl of IGovernanceToken<ContractState> {
        fn set_governance_contracts(
            ref self: ContractState,
            proposal_system: ContractAddress,
            voting_mechanism: ContractAddress,
        ) {
            // Ensure caller is owner or contract itself
            let caller = get_caller_address();
            assert(
                caller == self.ownable.owner() || caller == get_contract_address(),
                errors::CALLER_NOT_OWNER,
            );

            self.proposal_system.write(proposal_system);
            self.voting_mechanism.write(voting_mechanism);
        }

        fn get_governance_contracts(self: @ContractState) -> (ContractAddress, ContractAddress) {
            (self.proposal_system.read(), self.voting_mechanism.read())
        }
    }

    #[abi(embed_v0)]
    impl ERC20ExtensionImpl of IERC20Extension<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            assert(!recipient.is_zero(), errors::RECIPIENT_ZERO_ADDRESS);
            
            self.erc20.mint(recipient, amount);
            self.emit(MintEvent { to: recipient, amount });
        }

        fn burn(ref self: ContractState, amount: u256) {
            let burner = get_caller_address();
            self.erc20.burn(burner, amount);
            
            self.emit(BurnEvent { from: burner, amount });
        }

        fn get_decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) { // No logic needed before the update
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let mut contract_state = ERC20Component::HasComponent::get_contract_mut(ref self);

            let proposal_system_address = contract_state.proposal_system.read();
            let voting_mechanism_address = contract_state.voting_mechanism.read();

            let proposal_system = IProposalSystemDispatcher {
                contract_address: proposal_system_address,
            };
            let voting_mechanism = IVotingMechanismDispatcher {
                contract_address: voting_mechanism_address,
            };

            // Get active proposals for this token
            let token_address = get_contract_address();
            let active_proposals = proposal_system.get_active_proposals(token_address);

            // Notify voting mechanism for each active proposal
            let mut i = 0;
            loop {
                if i >= active_proposals.len() {
                    break;
                }

                let proposal_id = *active_proposals.at(i);
                voting_mechanism
                    .handle_token_transfer_during_voting(proposal_id, from, recipient, amount);

                i += 1;
            };

            // Emit GovernanceTokenTransfer event
            contract_state
                .emit(
                    GovernanceTokenTransfer {
                        from,
                        to: recipient,
                        amount,
                        active_proposals_affected: active_proposals.len().into(),
                    },
                );
        }
    }
}
