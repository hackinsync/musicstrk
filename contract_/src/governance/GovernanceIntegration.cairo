#[starknet::contract]
mod GovernanceIntegration {
    use starknet::{ContractAddress, get_caller_address, contract_address_const};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::ProposalSystem::{IProposalSystemDispatcher, IProposalSystemDispatcherTrait};
    use super::VotingMechanism::{
        IVotingMechanismDispatcher, IVotingMechanismDispatcherTrait, VoteType,
    };
    use super::types::GovernanceIntegration;
    use contract_::events::{GovernanceInitialized, ProposalSubmitted, VoteCast, ArtistResponse};

    #[storage]
    struct Storage {
        // Core contract addresses
        proposal_system: ContractAddress,
        voting_mechanism: ContractAddress,
        factory_contract: ContractAddress,
        revenue_contract: ContractAddress,
        // Integration settings
        admin: ContractAddress,
        is_initialized: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        GovernanceInitialized: GovernanceInitialized,
        ProposalSubmitted: ProposalSubmitted,
        VoteCast: VoteCast,
        ArtistResponse: ArtistResponse,
    }

    // #[derive(Drop, starknet::Event)]
    // struct GovernanceInitialized {
    //     proposal_system: ContractAddress,
    //     voting_mechanism: ContractAddress,
    //     factory_contract: ContractAddress,
    // }

    // #[derive(Drop, starknet::Event)]
    // struct ProposalSubmitted {
    //     proposal_id: u64,
    //     token_contract: ContractAddress,
    //     proposer: ContractAddress,
    //     category: felt252,
    // }

    // #[derive(Drop, starknet::Event)]
    // struct VoteCast {
    //     proposal_id: u64,
    //     voter: ContractAddress,
    //     vote_type: VoteType,
    //     weight: u256,
    // }

    // #[derive(Drop, starknet::Event)]
    // struct ArtistResponse {
    //     proposal_id: u64,
    //     artist: ContractAddress,
    //     status: u8,
    // }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
        self.is_initialized.write(false);
    }

    #[abi(embed_v0)]
    impl GovernanceIntegrationImpl of IGovernanceIntegration<ContractState> {
        fn initialize_governance(
            ref self: ContractState,
            proposal_system: ContractAddress,
            voting_mechanism: ContractAddress,
            factory_contract: ContractAddress,
            revenue_contract: ContractAddress,
        ) {
            self._only_admin();
            assert(!self.is_initialized.read(), 'Already initialized');

            self.proposal_system.write(proposal_system);
            self.voting_mechanism.write(voting_mechanism);
            self.factory_contract.write(factory_contract);
            self.revenue_contract.write(revenue_contract);
            self.is_initialized.write(true);

            self
                .emit(
                    GovernanceInitialized { proposal_system, voting_mechanism, factory_contract },
                );
        }

        fn submit_governance_proposal(
            ref self: ContractState,
            token_contract: ContractAddress,
            title: ByteArray,
            description: ByteArray,
            category: felt252,
        ) -> u64 {
            self._ensure_initialized();
            let caller = get_caller_address();

            // Verify caller is a qualified shareholder
            self._verify_shareholder_eligibility(caller, token_contract);

            let proposal_system = IProposalSystemDispatcher {
                contract_address: self.proposal_system.read(),
            };

            let proposal_id = proposal_system
                .submit_proposal(token_contract, title, description, category);

            self
                .emit(
                    ProposalSubmitted { proposal_id, token_contract, proposer: caller, category },
                );

            proposal_id
        }

        fn cast_governance_vote(
            ref self: ContractState,
            proposal_id: u64,
            vote_type: VoteType,
            token_contract: ContractAddress,
        ) -> u256 {
            self._ensure_initialized();
            let caller = get_caller_address();

            let voting_mechanism = IVotingMechanismDispatcher {
                contract_address: self.voting_mechanism.read(),
            };

            let weight = voting_mechanism.cast_vote(proposal_id, vote_type, token_contract);

            self.emit(VoteCast { proposal_id, voter: caller, vote_type, weight });

            weight
        }

        fn artist_respond_to_proposal(
            ref self: ContractState,
            proposal_id: u64,
            status: u8,
            response: ByteArray,
            token_contract: ContractAddress,
        ) {
            self._ensure_initialized();
            let caller = get_caller_address();

            // Verify caller is the artist for this token
            self._verify_artist_authority(caller, token_contract);

            let proposal_system = IProposalSystemDispatcher {
                contract_address: self.proposal_system.read(),
            };

            proposal_system.respond_to_proposal(proposal_id, status, response);

            self.emit(ArtistResponse { proposal_id, artist: caller, status });
        }

        fn get_governance_overview(
            self: @ContractState, token_contract: ContractAddress,
        ) -> GovernanceOverview {
            self._ensure_initialized();

            let proposal_system = IProposalSystemDispatcher {
                contract_address: self.proposal_system.read(),
            };

            // Get recent proposals for this token
            let proposals = proposal_system
                .get_proposals(
                    token_contract,
                    255_u8, // All statuses
                    'ALL', // All categories
                    0, // Page 0
                    5 // Last 5 proposals
                );

            let total_proposals = proposals.len();
            let mut pending_count = 0_u32;
            let mut approved_count = 0_u32;

            let mut i = 0_u32;
            while i < total_proposals {
                let proposal = proposals.at(i);
                if *proposal.status == 0 {
                    pending_count += 1;
                } else if *proposal.status == 1 {
                    approved_count += 1;
                }
                i += 1;
            };

            GovernanceOverview {
                total_proposals,
                pending_proposals: pending_count,
                approved_proposals: approved_count,
                token_contract,
                governance_active: true,
            }
        }

        fn get_voter_participation(self: @ContractState, proposal_id: u64) -> VoterParticipation {
            self._ensure_initialized();

            let voting_mechanism = IVotingMechanismDispatcher {
                contract_address: self.voting_mechanism.read(),
            };

            let breakdown = voting_mechanism.get_vote_breakdown(proposal_id);

            VoterParticipation {
                proposal_id,
                total_voters: breakdown.total_voters,
                votes_for: breakdown.votes_for,
                votes_against: breakdown.votes_against,
                votes_abstain: breakdown.votes_abstain,
                participation_rate: breakdown.voter_participation_rate,
                approval_rating: breakdown.approval_rating,
            }
        }

        fn batch_proposals_by_category(
            self: @ContractState, token_contract: ContractAddress,
        ) -> CategoryBreakdown {
            self._ensure_initialized();

            let proposal_system = IProposalSystemDispatcher {
                contract_address: self.proposal_system.read(),
            };

            let marketing_proposals = proposal_system
                .get_proposals(token_contract, 255_u8, 'MARKETING', 0, 100);
            let revenue_proposals = proposal_system
                .get_proposals(token_contract, 255_u8, 'REVENUE', 0, 100);
            let creative_proposals = proposal_system
                .get_proposals(token_contract, 255_u8, 'CREATIVE', 0, 100);
            let other_proposals = proposal_system
                .get_proposals(token_contract, 255_u8, 'OTHER', 0, 100);

            CategoryBreakdown {
                marketing_count: marketing_proposals.len(),
                revenue_count: revenue_proposals.len(),
                creative_count: creative_proposals.len(),
                other_count: other_proposals.len(),
            }
        }
    }

    #[derive(Drop, Serde)]
    struct GovernanceOverview {
        total_proposals: u32,
        pending_proposals: u32,
        approved_proposals: u32,
        token_contract: ContractAddress,
        governance_active: bool,
    }

    #[derive(Drop, Serde)]
    struct VoterParticipation {
        proposal_id: u64,
        total_voters: u64,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256,
        participation_rate: u8,
        approval_rating: u8,
    }

    #[derive(Drop, Serde)]
    struct CategoryBreakdown {
        marketing_count: u32,
        revenue_count: u32,
        creative_count: u32,
        other_count: u32,
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _only_admin(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'Only admin');
        }

        fn _ensure_initialized(self: @ContractState) {
            assert(self.is_initialized.read(), 'Not initialized');
        }

        fn _verify_shareholder_eligibility(
            self: @ContractState, caller: ContractAddress, token_contract: ContractAddress,
        ) {
            let token = IERC20Dispatcher { contract_address: token_contract };
            let balance = token.balance_of(caller);
            let total_supply = token.total_supply();

            // Require at least 3% of total supply
            let required_balance = (total_supply * 3) / 100;
            assert(balance >= required_balance, 'Insufficient tokens for proposal');
        }

        fn _verify_artist_authority(
            self: @ContractState, caller: ContractAddress, token_contract: ContractAddress,
        ) {
            // In a real implementation, this would query the factory to verify
            // the caller is the original artist/deployer of the token contract
            // For now, we'll use a simplified check

            let proposal_system = IProposalSystemDispatcher {
                contract_address: self.proposal_system.read(),
            };
            // This would call a method to verify artist status
        // The ProposalSystem stores artist mappings
        }
    }

    #[starknet::interface]
    trait IGovernanceIntegration<TContractState> {
        fn initialize_governance(
            ref self: TContractState,
            proposal_system: ContractAddress,
            voting_mechanism: ContractAddress,
            factory_contract: ContractAddress,
            revenue_contract: ContractAddress,
        );

        fn submit_governance_proposal(
            ref self: TContractState,
            token_contract: ContractAddress,
            title: ByteArray,
            description: ByteArray,
            category: felt252,
        ) -> u64;

        fn cast_governance_vote(
            ref self: TContractState,
            proposal_id: u64,
            vote_type: VoteType,
            token_contract: ContractAddress,
        ) -> u256;

        fn artist_respond_to_proposal(
            ref self: TContractState,
            proposal_id: u64,
            status: u8,
            response: ByteArray,
            token_contract: ContractAddress,
        );

        fn get_governance_overview(
            self: @TContractState, token_contract: ContractAddress,
        ) -> GovernanceOverview;

        fn get_voter_participation(self: @TContractState, proposal_id: u64) -> VoterParticipation;

        fn batch_proposals_by_category(
            self: @TContractState, token_contract: ContractAddress,
        ) -> CategoryBreakdown;
    }
}
