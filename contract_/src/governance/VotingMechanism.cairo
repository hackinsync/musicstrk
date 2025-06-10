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
    fn change_vote(
        ref self: TContractState,
        proposal_id: u64,
        new_vote_type: VoteType,
        token_contract: ContractAddress,
    ) -> u256;
    fn start_voting_period(ref self: TContractState, proposal_id: u64, duration_seconds: u64);
    fn end_voting_period(ref self: TContractState, proposal_id: u64);
    fn check_and_finalize_proposal(
        ref self: TContractState, proposal_id: u64, token_contract: ContractAddress,
    ) -> u8;
    fn artist_veto_proposal(
        ref self: TContractState, proposal_id: u64, token_contract: ContractAddress,
    );
    fn get_proposal_threshold_status(
        self: @TContractState, proposal_id: u64, token_contract: ContractAddress,
    ) -> (bool, u256, u256);
    fn handle_token_transfer_during_voting(
        ref self: TContractState,
        proposal_id: u64,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
    );
}

#[starknet::contract]
pub mod VotingMechanism {
    use contract_::governance::types::{VoteType, Vote, VoteTally, VoteBreakdown};
    use contract_::governance::ProposalSystem::{
        IProposalSystemDispatcher, IProposalSystemDispatcherTrait,
    };
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_block_timestamp,
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use core::byte_array::ByteArray;
    use super::IVotingMechanism;

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
        proposal_finalized: Map<u64, bool>, // proposal_id -> finalized status
        artist_vetoed: Map<u64, bool>, // proposal_id -> vetoed by artist
        threshold_percentage: u8, // Default 50% threshold for passing
        snapshot_weights: Map<(u64, ContractAddress), u256>, // Weight at voting start
        voting_started: Map<u64, bool> // proposal_id -> voting has started
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        VoteCast: VoteCast,
        VoteDelegated: VoteDelegated,
        VoteChanged: VoteChanged,
        VotingPeriodStarted: VotingPeriodStarted,
        VotingPeriodEnded: VotingPeriodEnded,
        ProposalFinalized: ProposalFinalized,
        ArtistVeto: ArtistVeto,
        TokenTransferDuringVoting: TokenTransferDuringVoting,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VoteCast {
        #[key]
        pub proposal_id: u64,
        #[key]
        pub voter: ContractAddress,
        pub vote_type: VoteType,
        pub weight: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VoteDelegated {
        #[key]
        pub delegator: ContractAddress,
        #[key]
        pub delegate: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VoteChanged {
        #[key]
        pub proposal_id: u64,
        #[key]
        pub voter: ContractAddress,
        pub old_vote_type: VoteType,
        pub new_vote_type: VoteType,
        pub weight: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VotingPeriodStarted {
        #[key]
        pub proposal_id: u64,
        pub end_timestamp: u64,
        pub duration_seconds: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VotingPeriodEnded {
        #[key]
        pub proposal_id: u64,
        pub final_status: u8,
        pub votes_for: u256,
        pub votes_against: u256,
        pub votes_abstain: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProposalFinalized {
        #[key]
        pub proposal_id: u64,
        pub final_status: u8, // 1=Approved, 2=Rejected
        pub threshold_met: bool,
        pub total_votes_for: u256,
        pub required_threshold: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ArtistVeto {
        #[key]
        pub proposal_id: u64,
        #[key]
        pub artist: ContractAddress,
        pub reason: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenTransferDuringVoting {
        #[key]
        pub proposal_id: u64,
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub amount: u256,
        pub affected_weight: bool,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, proposal_system: ContractAddress, default_voting_period: u64,
    ) {
        self.proposal_system.write(proposal_system);
        self.default_voting_period.write(default_voting_period);
        self.threshold_percentage.write(50); // Default 50% threshold
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

        fn change_vote(
            ref self: ContractState,
            proposal_id: u64,
            new_vote_type: VoteType,
            token_contract: ContractAddress,
        ) -> u256 {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Ensure the proposal is still active
            assert(self.is_voting_active(proposal_id), 'Voting period has ended');

            // Check if the user has already voted on the proposal
            let existing_vote = self.votes.read((proposal_id, caller));
            assert(existing_vote.vote_type != VoteType::None, 'No existing vote to change');

            // Get the weight of the voter's token
            let token = IERC20Dispatcher { contract_address: token_contract };
            let weight = token.balance_of(caller);
            assert(weight > 0, 'No voting power');

            // Update the vote
            let mut vote = existing_vote;
            vote.vote_type = new_vote_type;
            vote.timestamp = timestamp;

            self.votes.write((proposal_id, caller), vote);

            // Update the vote tally
            self._update_vote_tally(proposal_id, new_vote_type, weight);

            // Emit VoteChanged event
            self
                .emit(
                    VoteChanged {
                        proposal_id,
                        voter: caller,
                        old_vote_type: existing_vote.vote_type,
                        new_vote_type,
                        weight,
                    },
                );

            weight
        }

        fn start_voting_period(ref self: ContractState, proposal_id: u64, duration_seconds: u64) {
            let end_timestamp = get_block_timestamp() + duration_seconds;
            self.voting_periods.write(proposal_id, end_timestamp);

            // Emit VotingPeriodStarted event
            self.emit(VotingPeriodStarted { proposal_id, end_timestamp, duration_seconds });
        }

        fn end_voting_period(ref self: ContractState, proposal_id: u64) {
            let tally = self.vote_tallies.read(proposal_id);

            // Determine final status based on current votes
            let final_status = if tally.total_for > tally.total_against {
                1
            } else {
                2
            };

            self.voting_periods.write(proposal_id, 0);

            // Emit VotingPeriodEnded event
            self
                .emit(
                    VotingPeriodEnded {
                        proposal_id,
                        final_status,
                        votes_for: tally.total_for,
                        votes_against: tally.total_against,
                        votes_abstain: tally.total_abstain,
                    },
                );
        }

        fn check_and_finalize_proposal(
            ref self: ContractState, proposal_id: u64, token_contract: ContractAddress,
        ) -> u8 {
            let tally = self.vote_tallies.read(proposal_id);

            // Check if the proposal has met the threshold
            let (threshold_met, total_weight, _threshold) = self
                .get_proposal_threshold_status(proposal_id, token_contract);
            if threshold_met {
                // Finalize the proposal as accepted
                self
                    .emit(
                        ProposalFinalized {
                            proposal_id,
                            final_status: 1,
                            threshold_met: true,
                            total_votes_for: tally.total_for,
                            required_threshold: total_weight / 2,
                        },
                    );
                return 1;
            } else {
                // Finalize the proposal as rejected
                self
                    .emit(
                        ProposalFinalized {
                            proposal_id,
                            final_status: 2,
                            threshold_met: false,
                            total_votes_for: tally.total_for,
                            required_threshold: total_weight / 2,
                        },
                    );
                return 2;
            }
        }

        fn artist_veto_proposal(
            ref self: ContractState, proposal_id: u64, token_contract: ContractAddress,
        ) {
            let caller = get_caller_address();

            // Verify caller is the artist for this token
            let proposal_system = IProposalSystemDispatcher {
                contract_address: self.proposal_system.read(),
            };
            let artist = proposal_system.get_artist_for_token(token_contract);
            assert(caller == artist, 'Only artist can veto');

            // Mark proposal as vetoed
            self.artist_vetoed.write(proposal_id, true);

            // Update proposal status to vetoed (status 4)
            proposal_system.respond_to_proposal(proposal_id, 4, "Vetoed by artist");

            // Emit ArtistVeto event
            self
                .emit(
                    ArtistVeto {
                        proposal_id, artist: caller, reason: "Artist exercised veto power",
                    },
                );
        }

        fn get_proposal_threshold_status(
            self: @ContractState, proposal_id: u64, token_contract: ContractAddress,
        ) -> (bool, u256, u256) {
            let tally = self.vote_tallies.read(proposal_id);

            // Example threshold logic: 50% of total supply must vote in favor
            let token = IERC20Dispatcher { contract_address: token_contract };
            let total_supply = token.total_supply();
            let required_votes = total_supply / 2;

            let threshold_met = tally.total_for >= required_votes;

            (threshold_met, tally.total_for, required_votes)
        }

        fn handle_token_transfer_during_voting(
            ref self: ContractState,
            proposal_id: u64,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
        ) {
            // Early exit if voting is not active for this proposal
            if !self.is_voting_active(proposal_id) {
                return;
            }

            let mut weight_affected = false;
            let mut delegation_affected = false;

            // Handle sender's vote weight adjustment
            if self.has_voted(proposal_id, from) {
                let vote = self.votes.read((proposal_id, from));
                let current_weight = self.voting_weights.read((proposal_id, from));

                // Only adjust if the sender has sufficient tokens remaining
                if current_weight >= amount {
                    let new_weight = current_weight - amount;
                    self.voting_weights.write((proposal_id, from), new_weight);

                    // Update vote tallies to reflect weight change
                    self._adjust_vote_tally(proposal_id, vote.vote_type, amount, false);
                    weight_affected = true;
                } else {
                    // Sender doesn't have enough tokens - invalidate their vote
                    self._invalidate_vote(proposal_id, from);
                    weight_affected = true;
                }
            }

            // Handle delegation chain updates
            let delegation_from_sender = self.delegations.read(from);
            let delegation_to_receiver = self.delegations.read(to);

            if delegation_from_sender != contract_address_const::<0>() {
                // Sender has delegated - update delegate's effective voting power
                self._update_delegated_weight(proposal_id, delegation_from_sender, amount, false);
                delegation_affected = true;
            }

            if delegation_to_receiver != contract_address_const::<0>() {
                // Receiver has delegated - update delegate's effective voting power
                self._update_delegated_weight(proposal_id, delegation_to_receiver, amount, true);
                delegation_affected = true;
            }

            // Record transfer for audit trail
            self
                .emit(
                    TokenTransferDuringVoting {
                        proposal_id,
                        from,
                        to,
                        amount,
                        affected_weight: weight_affected || delegation_affected,
                    },
                );
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

        fn _adjust_vote_tally(
            ref self: ContractState,
            proposal_id: u64,
            vote_type: VoteType,
            weight: u256,
            is_addition: bool,
        ) {
            let mut tally = self.vote_tallies.read(proposal_id);

            match vote_type {
                VoteType::For => {
                    if is_addition {
                        tally.total_for += weight;
                    } else {
                        tally
                            .total_for =
                                if tally.total_for >= weight {
                                    tally.total_for - weight
                                } else {
                                    0
                                };
                    }
                },
                VoteType::Against => {
                    if is_addition {
                        tally.total_against += weight;
                    } else {
                        tally
                            .total_against =
                                if tally.total_against >= weight {
                                    tally.total_against - weight
                                } else {
                                    0
                                };
                    }
                },
                VoteType::Abstain => {
                    if is_addition {
                        tally.total_abstain += weight;
                    } else {
                        tally
                            .total_abstain =
                                if tally.total_abstain >= weight {
                                    tally.total_abstain - weight
                                } else {
                                    0
                                };
                    }
                },
                VoteType::None => {},
            }

            self.vote_tallies.write(proposal_id, tally);
        }

        fn _invalidate_vote(ref self: ContractState, proposal_id: u64, voter: ContractAddress) {
            let vote = self.votes.read((proposal_id, voter));
            let weight = self.voting_weights.read((proposal_id, voter));

            // Remove vote weight from tallies
            self._adjust_vote_tally(proposal_id, vote.vote_type, weight, false);

            // Reset vote to None
            let invalid_vote = Vote {
                vote_type: VoteType::None,
                weight: 0,
                timestamp: vote.timestamp,
                delegated: vote.delegated,
            };

            self.votes.write((proposal_id, voter), invalid_vote);
            self.voting_weights.write((proposal_id, voter), 0);
        }

        fn _update_delegated_weight(
            ref self: ContractState,
            proposal_id: u64,
            delegate: ContractAddress,
            amount: u256,
            is_addition: bool,
        ) {
            // Check if delegate has voted and update their effective weight
            if self.has_voted(proposal_id, delegate) {
                let vote = self.votes.read((proposal_id, delegate));
                let current_weight = self.voting_weights.read((proposal_id, delegate));

                let new_weight = if is_addition {
                    current_weight + amount
                } else {
                    if current_weight >= amount {
                        current_weight - amount
                    } else {
                        0
                    }
                };

                // Update stored weight
                self.voting_weights.write((proposal_id, delegate), new_weight);

                // Adjust vote tallies accordingly
                let weight_diff = if is_addition {
                    amount
                } else {
                    if current_weight >= amount {
                        amount
                    } else {
                        current_weight
                    }
                };

                self._adjust_vote_tally(proposal_id, vote.vote_type, weight_diff, is_addition);
            }
        }
    }
}
