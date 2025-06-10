use starknet::ContractAddress;

#[starknet::interface]
pub trait IGovernanceToken<TContractState> {
    // Standard ERC20 functions
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;

    // Governance integration
    fn set_governance_contracts(
        ref self: TContractState,
        voting_mechanism: ContractAddress,
        proposal_system: ContractAddress,
    );
    fn get_governance_contracts(self: @TContractState) -> (ContractAddress, ContractAddress);
    fn is_governance_enabled(self: @TContractState) -> bool;
}

#[starknet::contract]
pub mod GovernanceToken {
    use contract_::governance::VotingMechanism::{
        IVotingMechanismDispatcher, IVotingMechanismDispatcherTrait,
    };
    use contract_::governance::ProposalSystem::{
        IProposalSystemDispatcher, IProposalSystemDispatcherTrait,
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::{ContractAddress, get_caller_address, contract_address_const};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::IGovernanceToken;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Ownable
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // OpenZeppelin Ownable contract
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        // Wrapped token contract
        token: ContractAddress,
        // Governance contracts
        voting_mechanism: ContractAddress,
        proposal_system: ContractAddress,
        governance_enabled: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        GovernanceTransfer: GovernanceTransfer,
        GovernanceContractsSet: GovernanceContractsSet,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GovernanceTransfer {
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub amount: u256,
        pub active_proposals_affected: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GovernanceContractsSet {
        pub voting_mechanism: ContractAddress,
        pub proposal_system: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, token: ContractAddress, owner: ContractAddress) {
        self.token.write(token);
        self.governance_enabled.write(false);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl GovernanceTokenImpl of IGovernanceToken<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            token.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            token.balance_of(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            token.allowance(owner, spender)
        }

        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let from = get_caller_address();
            let token = IERC20Dispatcher { contract_address: self.token.read() };

            // Execute the transfer on the underlying token
            let success = token.transfer(to, amount);

            // If governance is enabled and transfer was successful, notify voting mechanism
            if success && self.governance_enabled.read() {
                let affected_count = self._notify_governance_of_transfer(from, to, amount);
                self
                    .emit(
                        GovernanceTransfer {
                            from, to, amount, active_proposals_affected: affected_count,
                        },
                    );
            }

            success
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            let token = IERC20Dispatcher { contract_address: self.token.read() };

            // Execute the transfer_from on the underlying token
            let success = token.transfer_from(from, to, amount);

            // If governance is enabled and transfer was successful, notify voting mechanism
            if success && self.governance_enabled.read() {
                let affected_count = self._notify_governance_of_transfer(from, to, amount);
                self
                    .emit(
                        GovernanceTransfer {
                            from, to, amount, active_proposals_affected: affected_count,
                        },
                    );
            }

            success
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            token.approve(spender, amount)
        }

        fn set_governance_contracts(
            ref self: ContractState,
            voting_mechanism: ContractAddress,
            proposal_system: ContractAddress,
        ) {
            // Only the owner can set governance contracts
            self.ownable.assert_only_owner();

            self.voting_mechanism.write(voting_mechanism);
            self.proposal_system.write(proposal_system);
            self.governance_enabled.write(true);

            self.emit(GovernanceContractsSet { voting_mechanism, proposal_system });
        }

        fn get_governance_contracts(self: @ContractState) -> (ContractAddress, ContractAddress) {
            (self.voting_mechanism.read(), self.proposal_system.read())
        }

        fn is_governance_enabled(self: @ContractState) -> bool {
            self.governance_enabled.read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _notify_governance_of_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> u64 {
            let voting_mechanism_address = self.voting_mechanism.read();
            let proposal_system_address = self.proposal_system.read();

            if voting_mechanism_address == contract_address_const::<0>()
                || proposal_system_address == contract_address_const::<0>() {
                return 0; // No governance contracts set
            }

            let voting_mechanism = IVotingMechanismDispatcher {
                contract_address: voting_mechanism_address,
            };
            let proposal_system = IProposalSystemDispatcher {
                contract_address: proposal_system_address,
            };

            // Get active proposals for this token
            let token_address = self.token.read();
            let active_proposals = proposal_system.get_active_proposals(token_address);

            // Notify voting mechanism for each active proposal
            let mut i = 0;
            loop {
                if i >= active_proposals.len() {
                    break;
                }

                let proposal_id = *active_proposals.at(i);
                voting_mechanism.handle_token_transfer_during_voting(proposal_id, from, to, amount);

                i += 1;
            };

            active_proposals.len().into()
        }
    }
}
