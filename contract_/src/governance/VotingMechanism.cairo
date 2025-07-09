use contract_::governance::types::{VoteType, Vote, VoteBreakdown, VoteTally};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IVotingMechanism<TContractState> {
    fn cast_vote(
        ref self: TContractState,
        proposal_id: u64,
        vote_type: VoteType,
        token_contract: ContractAddress,
    ) -> u256;
    fn change_vote(
        ref self: TContractState,
        proposal_id: u64,
        new_vote_type: VoteType,
        token_contract: ContractAddress,
    ) -> u256;
    fn delegate_vote(
        ref self: TContractState, token_address: ContractAddress, delegate: ContractAddress,
    );
    fn start_voting_period(ref self: TContractState, proposal_id: u64, duration_seconds: u64);
    fn end_voting_period(ref self: TContractState, proposal_id: u64);
    fn finalize_proposal_status(
        ref self: TContractState, proposal_id: u64, token_contract: ContractAddress,
    ) -> u8;
    fn handle_token_transfer_during_voting(
        ref self: TContractState,
        proposal_id: u64,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
    );
    fn set_proposal_token_threshold(ref self: TContractState, proposal_id: u64, new_threshold: u8);
    fn get_proposal_threshold_status(
        self: @TContractState, proposal_id: u64, token_contract: ContractAddress,
    ) -> (bool, u256, u256);
    fn get_delegation(self: @TContractState, delegator: ContractAddress) -> ContractAddress;
    fn get_vote(self: @TContractState, proposal_id: u64, voter: ContractAddress) -> Vote;
    fn get_vote_breakdown(self: @TContractState, proposal_id: u64) -> VoteBreakdown;
    fn get_vote_weight(self: @TContractState, proposal_id: u64, voter: ContractAddress) -> u256;
    fn get_voter_count(self: @TContractState, proposal_id: u64) -> u64;
    fn get_voting_period(self: @TContractState, proposal_id: u64) -> u64;
    fn is_voting_active(self: @TContractState, proposal_id: u64) -> bool;
    fn has_voted(self: @TContractState, proposal_id: u64, voter: ContractAddress) -> bool;
}

#[starknet::contract]
pub mod VotingMechanism {
    use contract_::governance::ProposalSystem::{
        IProposalSystemDispatcher, IProposalSystemDispatcherTrait,
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{
        contract_address_const, get_caller_address, get_block_timestamp,
        storage::{
            Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
            StoragePointerWriteAccess,
        },
    };
    use super::*;
    use contract_::events::{VoteCast, VoteDelegated};

    #[storage]
    struct Storage {
        // Votes: (proposal_id, voter) -> Vote
        votes: Map<(u64, ContractAddress), Vote>,
        // Proposal voters: (proposal_id, voter_index) -> voter
        proposal_voters: Map<(u64, u64), ContractAddress>,
        // Voting weights: (proposal_id, voter) -> weight
        vote_weights: Map<(u64, ContractAddress), u256>,
        delegations: Map<ContractAddress, ContractAddress>, // delegator -> delegate
        delegation_weights: Map<ContractAddress, u256>, // delegate -> total delegated weights
        vote_tallies: Map<u64, VoteTally>, //proposal_id -> VoteTally
        voters_count: Map<u64, u64>, // proposal_id -> total_voters
        voting_periods: Map<u64, u64>, // proposal_id -> end_timestamp
        voting_thresholds: Map<u64, u8>, // proposal_id -> required threshold
        completed_votings: Map<u64, bool>,
        default_voting_period: u64,
        default_token_threshold_percentage: u8,
        proposal_system: ContractAddress,
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
        TokenTransferDuringVoting: TokenTransferDuringVoting,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        proposal_system: ContractAddress,
        default_voting_period: u64,
        minimum_token_threshold_percentage: u8,
    ) {
        self.proposal_system.write(proposal_system);
        self.default_voting_period.write(default_voting_period);
        self.default_token_threshold_percentage.write(minimum_token_threshold_percentage);
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

            // Verify proposal exists
            assert(self._verify_proposal_id(proposal_id), 'Invalid proposal ID');

            // Confirm proposal status is Pending(0)
            assert(
                self._confirm_proposal_status(proposal_id) == 0, 'Proposal is not in voting state',
            );

            // Assert voting has not already ended
            assert(!self.completed_votings.read(proposal_id), 'Voting has already ended');

            // Check if user has already voted
            assert(self.has_voted(proposal_id, caller) == false, 'Already voted');

            // Ensure the vote type is valid
            assert(vote_type != VoteType::None, 'Invalid vote type');

            // Check if voting is active for this proposal
            if !self.is_voting_active(proposal_id) {
                // If not started, set the voting period to default
                self.start_voting_period(proposal_id, self.default_voting_period.read());
            }
            // Check if the user has delegated their vote
            let delegation = self.delegations.read(caller);
            if delegation != contract_address_const::<0>()
                && self.delegation_weights.read(delegation) > 0 {
                // If caller already delegated, revert the vote
                assert(self.has_voted(proposal_id, caller), 'Cannot vote after delegation');
            }

            // Get voting weight from token balance
            let token = IERC20Dispatcher { contract_address: token_contract };
            let mut weight = token.balance_of(caller);
            assert(weight > 0, 'No voting power');
            weight += self.delegation_weights.read(caller);

            // Record the vote
            let vote = Vote { vote_type, weight, timestamp, delegated: false };
            self.votes.write((proposal_id, caller), vote);
            self.vote_weights.write((proposal_id, caller), weight);

            // Update voter count
            let current_count = self.voters_count.read(proposal_id);
            self.proposal_voters.write((proposal_id, current_count), caller);
            self.voters_count.write(proposal_id, current_count + 1);

            // Update vote tally
            self._update_vote_tally(proposal_id, vote_type, weight, true);

            // Emit VoteCast event
            self.emit(VoteCast { proposal_id, voter: caller, vote_type, weight });

            weight
        }

        fn change_vote(
            ref self: ContractState,
            proposal_id: u64,
            new_vote_type: VoteType,
            token_contract: ContractAddress,
        ) -> u256 {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            assert(self._verify_proposal_id(proposal_id), 'Proposal ID does not exist');
            assert(self.is_voting_active(proposal_id), 'Voting period has ended');

            // Check if the user has already voted on the proposal
            let existing_vote = self.votes.read((proposal_id, caller));
            assert(existing_vote.vote_type != VoteType::None, 'No existing vote to change');

            // Get the weight of the voter
            let token = IERC20Dispatcher { contract_address: token_contract };
            let weight = token.balance_of(caller);
            assert(weight > 0, 'No voting power');

            // Update the vote
            let mut vote = existing_vote;
            vote.vote_type = new_vote_type;
            vote.timestamp = timestamp;

            self.votes.write((proposal_id, caller), vote);

            // Update the vote tally
            self
                ._update_vote_tally(
                    proposal_id, existing_vote.vote_type, existing_vote.weight, false,
                );
            self._update_vote_tally(proposal_id, new_vote_type, weight, true);

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

        fn delegate_vote(
            ref self: ContractState, token_address: ContractAddress, delegate: ContractAddress,
        ) {
            let caller = get_caller_address();
            assert(caller != delegate, 'Cannot delegate to self');
            assert(
                self.delegations.read(caller) == contract_address_const::<0>(), 'Already delegated',
            );

            // Ensure delegator has token balance
            let token = IERC20Dispatcher { contract_address: token_address };
            let delegator_weight = token.balance_of(caller);
            assert(delegator_weight > 0, 'Delegator has no voting power');

            self.delegations.write(caller, delegate);

            let mut delegate_weight = self.delegation_weights.read(delegate);
            self.delegation_weights.write(delegate, delegate_weight + delegator_weight);

            self.emit(VoteDelegated { delegator: caller, delegate });
        }

        fn start_voting_period(ref self: ContractState, proposal_id: u64, duration_seconds: u64) {
            assert(self._verify_proposal_id(proposal_id), 'Invalid proposal ID');
            assert(duration_seconds > 0, 'Voting period must be > 0');

            let end_timestamp = get_block_timestamp() + duration_seconds;
            self.voting_periods.write(proposal_id, end_timestamp);

            // Emit VotingPeriodStarted event
            self.emit(VotingPeriodStarted { proposal_id, end_timestamp, duration_seconds });
        }

        fn end_voting_period(ref self: ContractState, proposal_id: u64) {
            assert(self._verify_proposal_id(proposal_id), 'Invalid proposal ID');
            assert(self.is_voting_active(proposal_id), 'Voting period is not active');

            let tally = self.vote_tallies.read(proposal_id);

            // Determine final status based on current votes
            let final_status = if tally.total_for > tally.total_against {
                1
            } else {
                2
            };

            // Set voting period to current timestamp to mark as ended
            self.voting_periods.write(proposal_id, get_block_timestamp());

            // Finalize voting status
            self.completed_votings.write(proposal_id, true);

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

        fn finalize_proposal_status(
            ref self: ContractState, proposal_id: u64, token_contract: ContractAddress,
        ) -> u8 {
            assert(self._verify_proposal_id(proposal_id), 'Invalid proposal ID');
            assert(self.is_voting_active(proposal_id) == false, 'Voting period is still active');

            let proposal_system_dispatcher = IProposalSystemDispatcher {
                contract_address: self.proposal_system.read(),
            };

            // Check if the proposal has met the threshold
            let (threshold_met, total_votes_for, threshold) = self
                .get_proposal_threshold_status(proposal_id, token_contract);

            if threshold_met {
                // Update the proposal status in the proposal system to Approved
                proposal_system_dispatcher.finalize_proposal(proposal_id, 1);

                self
                    .emit(
                        ProposalFinalized {
                            proposal_id,
                            final_status: 1,
                            threshold_met: true,
                            total_votes_for,
                            required_threshold: threshold,
                        },
                    );

                1
            } else {
                // Finalize the proposal as rejected
                proposal_system_dispatcher.finalize_proposal(proposal_id, 2);

                self
                    .emit(
                        ProposalFinalized {
                            proposal_id,
                            final_status: 2,
                            threshold_met: false,
                            total_votes_for,
                            required_threshold: threshold,
                        },
                    );

                2
            }
        }

        fn handle_token_transfer_during_voting(
            ref self: ContractState,
            proposal_id: u64,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
        ) {
            // Verify proposal ID valid and voting is active for this proposal
            assert(self._verify_proposal_id(proposal_id), 'Invalid proposal ID');
            assert(self.is_voting_active(proposal_id), 'Voting period is not active');
            assert(amount > 0, 'Transfer amount must be > 0');

            let mut weight_affected = false;
            let mut delegation_affected = false;

            // Handle sender's vote weight adjustment
            if self.has_voted(proposal_id, from) {
                let vote = self.votes.read((proposal_id, from));
                let current_weight = self.vote_weights.read((proposal_id, from));

                // Only adjust if the sender has sufficient tokens remaining
                if current_weight > amount {
                    let new_weight = current_weight - amount;
                    self.vote_weights.write((proposal_id, from), new_weight);

                    // Update vote tallies to reflect weight change
                    self._update_vote_tally(proposal_id, vote.vote_type, amount, false);
                    weight_affected = true;
                } else {
                    // Sender doesn't have enough tokens - invalidate their vote
                    self._invalidate_vote(proposal_id, from);
                    weight_affected = true;
                }
            }

            // Handle receiver's vote weight adjustment
            if self.has_voted(proposal_id, to) {
                let vote = self.votes.read((proposal_id, to));
                let current_weight = self.vote_weights.read((proposal_id, to));

                let new_weight = current_weight + amount;
                self.vote_weights.write((proposal_id, to), new_weight);

                // Update vote tallies to reflect weight change
                self._update_vote_tally(proposal_id, vote.vote_type, amount, true);
                weight_affected = true;
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

        fn set_proposal_token_threshold(
            ref self: ContractState, proposal_id: u64, new_threshold: u8,
        ) {
            assert(self._verify_proposal_id(proposal_id), 'Invalid proposal ID');

            let caller = get_caller_address();
            let proposal_system_dispatcher = IProposalSystemDispatcher {
                contract_address: self.proposal_system.read(),
            };

            let proposer = proposal_system_dispatcher.get_proposal(proposal_id).proposer;
            assert(caller == proposer, 'Only proposer can set threshold');

            self.voting_thresholds.write(proposal_id, new_threshold);
        }

        fn get_proposal_threshold_status(
            self: @ContractState, proposal_id: u64, token_contract: ContractAddress,
        ) -> (bool, u256, u256) {
            let tally = self.vote_tallies.read(proposal_id);
            let total_votes = tally.total_for + tally.total_against + tally.total_abstain;
            let token_threshold_percentage = if self.voting_thresholds.read(proposal_id) == 0 {
                self.default_token_threshold_percentage.read()
            } else {
                self.voting_thresholds.read(proposal_id)
            };

            let token = IERC20Dispatcher { contract_address: token_contract };
            let total_supply = token.total_supply();
            let token_supply_threshold = (token_threshold_percentage.into() * total_supply) / 100;

            // Threshold logic: Majority must vote in favor and must meet the token threshold
            let threshold_met = tally.total_for > tally.total_against
                && total_votes >= token_supply_threshold;

            (threshold_met, tally.total_for, token_supply_threshold)
        }

        fn get_delegation(self: @ContractState, delegator: ContractAddress) -> ContractAddress {
            self.delegations.read(delegator)
        }

        fn get_vote(self: @ContractState, proposal_id: u64, voter: ContractAddress) -> Vote {
            self.votes.read((proposal_id, voter))
        }

        fn get_vote_breakdown(self: @ContractState, proposal_id: u64) -> VoteBreakdown {
            let tally = self.vote_tallies.read(proposal_id);
            let total_voters = self.voters_count.read(proposal_id);

            VoteBreakdown {
                votes_for: tally.total_for,
                votes_against: tally.total_against,
                votes_abstain: tally.total_abstain,
                total_voters,
            }
        }

        fn get_vote_weight(self: @ContractState, proposal_id: u64, voter: ContractAddress) -> u256 {
            self.vote_weights.read((proposal_id, voter))
        }

        fn get_voter_count(self: @ContractState, proposal_id: u64) -> u64 {
            self.voters_count.read(proposal_id)
        }

        fn get_voting_period(self: @ContractState, proposal_id: u64) -> u64 {
            self.voting_periods.read(proposal_id)
        }

        fn is_voting_active(self: @ContractState, proposal_id: u64) -> bool {
            let end_timestamp = self.voting_periods.read(proposal_id);
            let current_timestamp = get_block_timestamp();
            end_timestamp >= current_timestamp && end_timestamp != 0
        }

        fn has_voted(self: @ContractState, proposal_id: u64, voter: ContractAddress) -> bool {
            let vote = self.votes.read((proposal_id, voter));
            vote.vote_type != VoteType::None
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _verify_proposal_id(ref self: ContractState, proposal_id: u64) -> bool {
            let proposal_system_dispatcher = IProposalSystemDispatcher {
                contract_address: self.proposal_system.read(),
            };

            proposal_system_dispatcher.get_proposal(proposal_id).id != 0
        }

        fn _confirm_proposal_status(ref self: ContractState, proposal_id: u64) -> u8 {
            let proposal_system_dispatcher = IProposalSystemDispatcher {
                contract_address: self.proposal_system.read(),
            };

            proposal_system_dispatcher.get_proposal(proposal_id).status
        }

        fn _update_vote_tally(
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
                                if tally.total_for > weight {
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
                                if tally.total_against > weight {
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
                                if tally.total_abstain > weight {
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
            let weight = self.vote_weights.read((proposal_id, voter));

            // Remove vote weight from tallies
            self._update_vote_tally(proposal_id, vote.vote_type, weight, false);

            // Reset vote to None
            let invalid_vote = Vote {
                vote_type: VoteType::None,
                weight: 0,
                timestamp: vote.timestamp,
                delegated: vote.delegated,
            };

            self.votes.write((proposal_id, voter), invalid_vote);
            self.vote_weights.write((proposal_id, voter), 0);
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
                let current_weight = self.vote_weights.read((proposal_id, delegate));

                let new_weight = if is_addition {
                    current_weight + amount
                } else {
                    if current_weight > amount {
                        current_weight - amount
                    } else {
                        0
                    }
                };

                // Update stored weight
                self.vote_weights.write((proposal_id, delegate), new_weight);

                // Adjust vote tallies accordingly
                let weight_diff = if is_addition {
                    amount
                } else {
                    if current_weight > amount {
                        amount
                    } else {
                        current_weight
                    }
                };

                self._update_vote_tally(proposal_id, vote.vote_type, weight_diff, is_addition);
            }
        }
    }
}
