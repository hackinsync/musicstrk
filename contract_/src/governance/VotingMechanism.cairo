use contract_::governance::types::{VoteType, Vote, VoteBreakdown};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IVotingMechanism<TContractState> {
    fn cast_vote(
        ref self: TContractState,
        proposal_id: u64,
        vote_type: VoteType,
        token_contract: ContractAddress,
    ) -> u256;
    fn delegate_vote(ref self: TContractState, delegate: ContractAddress);
    fn get_vote_breakdown(self: @TContractState, proposal_id: u64) -> VoteBreakdown;
    fn get_vote(self: @TContractState, proposal_id: u64, voter: ContractAddress) -> Vote;
    fn get_delegation(self: @TContractState, delegator: ContractAddress) -> ContractAddress;
    fn has_voted(self: @TContractState, proposal_id: u64, voter: ContractAddress) -> bool;
    fn get_voting_period(self: @TContractState, proposal_id: u64) -> u64;
    fn set_voting_period(ref self: TContractState, proposal_id: u64, end_timestamp: u64);
    fn is_voting_active(self: @TContractState, proposal_id: u64) -> bool;
    fn get_voter_count(self: @TContractState, proposal_id: u64) -> u64;
    fn get_voting_weight(self: @TContractState, proposal_id: u64, voter: ContractAddress) -> u256;
}

#[starknet::contract]
pub mod VotingMechanism {
    use contract_::governance::types::{VoteType, Vote, VoteTally, VoteBreakdown};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerWriteAccess,
    };
    use super::IVotingMechanism;
    use contract_::events::{VoteCast, VoteDelegated};

    #[storage]
    struct Storage {
        // Voting records: (proposal_id, voter) -> Vote
        votes: Map<(u64, ContractAddress), Vote>,
        // Voter participation tracking: proposal_id -> Array<voter_address>
        proposal_voters: Map<(u64, u64), ContractAddress>, // (proposal_id, voter_index) -> voter
        voter_counts: Map<u64, u64>, // proposal_id -> total_voters
        // Voting weights: (proposal_id, voter) -> weight
        voting_weights: Map<(u64, ContractAddress), u256>,
        // Proposal system contract
        proposal_system: ContractAddress,
        // Voting periods: proposal_id -> end_timestamp
        voting_periods: Map<u64, u64>,
        default_voting_period: u64, // Default 7 days in seconds
        // Delegation system: delegator -> delegate
        delegations: Map<ContractAddress, ContractAddress>,
        // Vote tallying cache for gas optimization
        vote_tallies: Map<u64, VoteTally>,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        VoteCast: VoteCast,
        VoteDelegated: VoteDelegated,
    }

    // #[derive(Drop, starknet::Event)]
    // pub struct VoteCast {
    //     #[key]
    //     pub proposal_id: u64,
    //     #[key]
    //     pub voter: ContractAddress,
    //     pub vote_type: VoteType,
    //     pub weight: u256,
    // }

    // #[derive(Drop, starknet::Event)]
    // pub struct VoteDelegated {
    //     #[key]
    //     pub delegator: ContractAddress,
    //     #[key]
    //     pub delegate: ContractAddress,
    // }

    #[constructor]
    fn constructor(
        ref self: ContractState, proposal_system: ContractAddress, default_voting_period: u64,
    ) {
        self.proposal_system.write(proposal_system);
        self.default_voting_period.write(default_voting_period);
    }

    #[abi(embed_v0)]
    impl VotingMechanismImpl of IVotingMechanism<ContractState> {
        fn cast_vote(
            ref self: ContractState,
            proposal_id: u64,
            vote_type: VoteType,
            token_contract: ContractAddress,
        ) -> u256 {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Check if user has already voted
            let existing_vote = self.votes.read((proposal_id, caller));
            assert(existing_vote.vote_type == VoteType::None, 'Already voted');

            // Get voting weight from token balance
            let token = IERC20Dispatcher { contract_address: token_contract };
            let weight = token.balance_of(caller);
            assert(weight > 0, 'No voting power');

            // Record the vote
            let vote = Vote { vote_type, weight, timestamp, delegated: false };

            self.votes.write((proposal_id, caller), vote);
            self.voting_weights.write((proposal_id, caller), weight);

            // Update voter count
            let current_count = self.voter_counts.read(proposal_id);
            self.proposal_voters.write((proposal_id, current_count), caller);
            self.voter_counts.write(proposal_id, current_count + 1);

            // Update vote tally
            self._update_vote_tally(proposal_id, vote_type, weight);

            self.emit(VoteCast { proposal_id, voter: caller, vote_type, weight });

            weight
        }

        fn delegate_vote(ref self: ContractState, delegate: ContractAddress) {
            let caller = get_caller_address();
            assert(caller != delegate, 'Cannot delegate to self');

            self.delegations.write(caller, delegate);

            self.emit(VoteDelegated { delegator: caller, delegate });
        }

        fn get_vote_breakdown(self: @ContractState, proposal_id: u64) -> VoteBreakdown {
            let tally = self.vote_tallies.read(proposal_id);
            let total_voters = self.voter_counts.read(proposal_id);

            VoteBreakdown {
                votes_for: tally.total_for,
                votes_against: tally.total_against,
                votes_abstain: tally.total_abstain,
                total_voters,
            }
        }

        fn get_vote(self: @ContractState, proposal_id: u64, voter: ContractAddress) -> Vote {
            self.votes.read((proposal_id, voter))
        }

        fn get_delegation(self: @ContractState, delegator: ContractAddress) -> ContractAddress {
            self.delegations.read(delegator)
        }

        fn has_voted(self: @ContractState, proposal_id: u64, voter: ContractAddress) -> bool {
            let vote = self.votes.read((proposal_id, voter));
            vote.vote_type != VoteType::None
        }

        fn get_voting_period(self: @ContractState, proposal_id: u64) -> u64 {
            self.voting_periods.read(proposal_id)
        }

        fn set_voting_period(ref self: ContractState, proposal_id: u64, end_timestamp: u64) {
            self.voting_periods.write(proposal_id, end_timestamp);
        }

        fn is_voting_active(self: @ContractState, proposal_id: u64) -> bool {
            let end_time = self.voting_periods.read(proposal_id);
            if end_time == 0 {
                return true; // No end time set means voting is active
            }
            get_block_timestamp() < end_time
        }

        fn get_voter_count(self: @ContractState, proposal_id: u64) -> u64 {
            self.voter_counts.read(proposal_id)
        }

        fn get_voting_weight(
            self: @ContractState, proposal_id: u64, voter: ContractAddress,
        ) -> u256 {
            self.voting_weights.read((proposal_id, voter))
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _update_vote_tally(
            ref self: ContractState, proposal_id: u64, vote_type: VoteType, weight: u256,
        ) {
            let mut tally = self.vote_tallies.read(proposal_id);

            match vote_type {
                VoteType::For => { tally.total_for += weight; },
                VoteType::Against => { tally.total_against += weight; },
                VoteType::Abstain => { tally.total_abstain += weight; },
                VoteType::None => {},
            }

            self.vote_tallies.write(proposal_id, tally);
        }
    }
}
