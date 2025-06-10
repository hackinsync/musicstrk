use contract_::governance::types::{Proposal, Comment, ProposalMetrics};
use core::array::Array;
use core::byte_array::ByteArray;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IProposalSystem<TContractState> {
    fn submit_proposal(
        ref self: TContractState,
        token_contract: ContractAddress,
        title: ByteArray,
        description: ByteArray,
        category: felt252,
    ) -> u64;
    fn respond_to_proposal(
        ref self: TContractState, proposal_id: u64, new_status: u8, response: ByteArray,
    );
    fn add_comment(ref self: TContractState, proposal_id: u64, content: ByteArray);
    fn get_proposals(
        self: @TContractState,
        token_contract: ContractAddress,
        status: u8,
        category: felt252,
        page: u64,
        limit: u64,
    ) -> Array<Proposal>;
    fn get_proposal(self: @TContractState, proposal_id: u64) -> Proposal;
    fn get_comments(
        self: @TContractState, proposal_id: u64, page: u64, limit: u64,
    ) -> Array<Comment>;
    fn get_proposal_metrics(self: @TContractState, proposal_id: u64) -> ProposalMetrics;
    fn register_artist(
        ref self: TContractState, token_contract: ContractAddress, artist: ContractAddress,
    );
    fn get_total_proposals(self: @TContractState) -> u64;
    fn get_proposals_by_artist(
        self: @TContractState, token_contract: ContractAddress,
    ) -> Array<Proposal>;
    fn get_proposals_by_status(self: @TContractState, status: u8) -> Array<Proposal>;
    fn get_active_proposals(self: @TContractState, token_contract: ContractAddress) -> Array<u64>;
    fn get_artist_for_token(
        self: @TContractState, token_contract: ContractAddress,
    ) -> ContractAddress;
    fn get_minimum_threshold(self: @TContractState) -> u8;
    fn update_minimum_threshold(ref self: TContractState, new_threshold: u8);
}

#[starknet::contract]
pub mod ProposalSystem {
    use contract_::governance::types::{Proposal, Comment, ProposalMetrics};
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, contract_address_const,
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::IProposalSystem;

    #[storage]
    struct Storage {
        // Core proposal storage
        proposals: Map<u64, Proposal>,
        next_proposal_id: u64,
        // Comments storage: proposal_id -> comment_id -> Comment
        comments: Map<(u64, u64), Comment>,
        comment_counts: Map<u64, u64>,
        next_comment_id: Map<u64, u64>,
        // Governance settings
        minimum_token_threshold_percentage: u8, // Default 3%
        factory_contract: ContractAddress,
        // Metrics tracking
        proposal_metrics: Map<u64, ProposalMetrics>,
        // Artist registry (token_contract -> artist_address)
        artists: Map<ContractAddress, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ProposalCreated: ProposalCreated,
        ProposalStatusChanged: ProposalStatusChanged,
        CommentAdded: CommentAdded,
        VoteCast: VoteCast,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProposalCreated {
        #[key]
        pub proposal_id: u64,
        #[key]
        pub token_contract: ContractAddress,
        pub proposer: ContractAddress,
        pub category: felt252,
        pub title: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProposalStatusChanged {
        #[key]
        pub proposal_id: u64,
        pub old_status: u8,
        pub new_status: u8,
        pub responder: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CommentAdded {
        #[key]
        pub proposal_id: u64,
        pub comment_id: u64,
        pub commenter: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VoteCast {
        #[key]
        pub proposal_id: u64,
        pub voter: ContractAddress,
        pub vote_type: u8, // 0=Against, 1=For
        pub weight: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        factory_contract: ContractAddress,
        minimum_threshold_percentage: u8,
    ) {
        self.factory_contract.write(factory_contract);
        self.minimum_token_threshold_percentage.write(minimum_threshold_percentage);
        self.next_proposal_id.write(1);
    }

    #[abi(embed_v0)]
    impl ProposalSystemImpl of IProposalSystem<ContractState> {
        fn submit_proposal(
            ref self: ContractState,
            token_contract: ContractAddress,
            title: ByteArray,
            description: ByteArray,
            category: felt252,
        ) -> u64 {
            let caller = get_caller_address();

            // Verify caller is a shareholder with minimum threshold
            self._verify_shareholder_threshold(caller, token_contract);

            let proposal_id = self.next_proposal_id.read();
            let timestamp = get_block_timestamp();

            let proposal = Proposal {
                id: proposal_id,
                title: title.clone(),
                description: description.clone(),
                category,
                status: 0, // Pending
                proposer: caller,
                token_contract,
                timestamp,
                votes_for: 0,
                votes_against: 0,
                artist_response: Default::default(),
            };

            self.proposals.write(proposal_id, proposal);
            self.next_proposal_id.write(proposal_id + 1);

            // Initialize metrics
            let metrics = ProposalMetrics {
                comment_count: 0, total_voters: 0, total_votes: 0, approval_rating: 0,
            };
            self.proposal_metrics.write(proposal_id, metrics);

            // Register artist if not already registered
            self._register_artist_if_needed(token_contract);

            self
                .emit(
                    ProposalCreated {
                        proposal_id, token_contract, proposer: caller, category, title,
                    },
                );

            proposal_id
        }

        fn respond_to_proposal(
            ref self: ContractState, proposal_id: u64, new_status: u8, response: ByteArray,
        ) {
            let caller = get_caller_address();
            let mut proposal = self.proposals.read(proposal_id);

            // Verify caller is the artist
            self._verify_artist(caller, proposal.token_contract);

            let old_status = proposal.status;
            proposal.status = new_status;
            proposal.artist_response = response;

            self.proposals.write(proposal_id, proposal);

            self
                .emit(
                    ProposalStatusChanged {
                        proposal_id, old_status, new_status, responder: caller,
                    },
                );
        }

        fn add_comment(ref self: ContractState, proposal_id: u64, content: ByteArray) {
            let caller = get_caller_address();
            let proposal = self.proposals.read(proposal_id);

            // Verify caller is a token holder
            self._verify_token_holder(caller, proposal.token_contract);

            let comment_id = self.next_comment_id.read(proposal_id);
            let timestamp = get_block_timestamp();

            let comment = Comment {
                id: comment_id, proposal_id, commenter: caller, content, timestamp,
            };

            self.comments.write((proposal_id, comment_id), comment);
            self.next_comment_id.write(proposal_id, comment_id + 1);

            // Update comment count
            let current_count = self.comment_counts.read(proposal_id);
            self.comment_counts.write(proposal_id, current_count + 1);

            // Update metrics
            let mut metrics = self.proposal_metrics.read(proposal_id);
            metrics.comment_count = current_count + 1;
            self.proposal_metrics.write(proposal_id, metrics);

            self.emit(CommentAdded { proposal_id, comment_id, commenter: caller });
        }

        fn get_proposals(
            self: @ContractState,
            token_contract: ContractAddress,
            status: u8,
            category: felt252,
            page: u64,
            limit: u64,
        ) -> Array<Proposal> {
            let mut proposals = ArrayTrait::new();
            let mut current_id = 1_u64;
            let max_id = self.next_proposal_id.read();
            let start_index = page * limit;
            let mut found_count = 0_u64;
            let mut added_count = 0_u64;

            while current_id < max_id && added_count < limit {
                let proposal = self.proposals.read(current_id);

                // Apply filters
                let matches_token = token_contract == contract_address_const::<0>()
                    || proposal.token_contract == token_contract;
                let matches_status = status == 255_u8 || proposal.status == status;
                let matches_category = category == 'ALL' || proposal.category == category;

                if matches_token && matches_status && matches_category {
                    if found_count >= start_index {
                        proposals.append(proposal);
                        added_count += 1;
                    }
                    found_count += 1;
                }

                current_id += 1;
            };

            proposals
        }

        fn get_proposal(self: @ContractState, proposal_id: u64) -> Proposal {
            self.proposals.read(proposal_id)
        }

        fn get_comments(
            self: @ContractState, proposal_id: u64, page: u64, limit: u64,
        ) -> Array<Comment> {
            let mut comments = ArrayTrait::new();
            let total_comments = self.comment_counts.read(proposal_id);
            let start_index = page * limit;
            let mut added_count = 0_u64;
            let mut current_index = start_index;

            while current_index < total_comments && added_count < limit {
                let comment = self.comments.read((proposal_id, current_index));
                comments.append(comment);
                added_count += 1;
                current_index += 1;
            };

            comments
        }

        fn get_proposal_metrics(self: @ContractState, proposal_id: u64) -> ProposalMetrics {
            self.proposal_metrics.read(proposal_id)
        }

        fn register_artist(
            ref self: ContractState, token_contract: ContractAddress, artist: ContractAddress,
        ) {
            // This would typically be called by the factory or during token creation
            self.artists.write(token_contract, artist);
        }

        fn get_total_proposals(self: @ContractState) -> u64 {
            self.next_proposal_id.read() - 1
        }

        fn get_proposals_by_artist(
            self: @ContractState, token_contract: ContractAddress,
        ) -> Array<Proposal> {
            let mut proposals = ArrayTrait::new();
            let mut current_id = 1_u64;
            let max_id = self.next_proposal_id.read();

            while current_id < max_id {
                let proposal = self.proposals.read(current_id);
                if proposal.token_contract == token_contract {
                    proposals.append(proposal);
                }
                current_id += 1;
            };

            proposals
        }

        fn get_proposals_by_status(self: @ContractState, status: u8) -> Array<Proposal> {
            let mut proposals = ArrayTrait::new();
            let mut current_id = 1_u64;
            let max_id = self.next_proposal_id.read();

            while current_id < max_id {
                let proposal = self.proposals.read(current_id);
                if proposal.status == status {
                    proposals.append(proposal);
                }
                current_id += 1;
            };

            proposals
        }

        fn get_active_proposals(
            self: @ContractState, token_contract: ContractAddress,
        ) -> Array<u64> {
            let mut active_proposals = ArrayTrait::new();
            let mut current_id = 1_u64;
            let max_id = self.next_proposal_id.read();

            while current_id < max_id {
                let proposal = self.proposals.read(current_id);
                if proposal.token_contract == token_contract && proposal.status == 0 {
                    active_proposals.append(proposal.id);
                }
                current_id += 1;
            };

            active_proposals
        }

        fn get_artist_for_token(
            self: @ContractState, token_contract: ContractAddress,
        ) -> ContractAddress {
            self.artists.read(token_contract)
        }

        fn get_minimum_threshold(self: @ContractState) -> u8 {
            self.minimum_token_threshold_percentage.read()
        }

        fn update_minimum_threshold(ref self: ContractState, new_threshold: u8) {
            // In a real implementation, this should have access control
            assert(new_threshold <= 100, 'Threshold must be <= 100');
            self.minimum_token_threshold_percentage.write(new_threshold);
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _verify_shareholder_threshold(
            self: @ContractState, caller: ContractAddress, token_contract: ContractAddress,
        ) {
            let token = IERC20Dispatcher { contract_address: token_contract };
            let caller_balance = token.balance_of(caller);
            let total_supply = token.total_supply();
            let threshold_percentage = self.minimum_token_threshold_percentage.read();

            let required_balance = (total_supply * threshold_percentage.into()) / 100;
            assert(caller_balance >= required_balance, 'Insufficient token balance');
        }

        fn _verify_token_holder(
            self: @ContractState, caller: ContractAddress, token_contract: ContractAddress,
        ) {
            let token = IERC20Dispatcher { contract_address: token_contract };
            let balance = token.balance_of(caller);
            assert(balance > 0, 'Not a token holder');
        }

        fn _verify_artist(
            self: @ContractState, caller: ContractAddress, token_contract: ContractAddress,
        ) {
            let artist = self.artists.read(token_contract);
            assert(caller == artist, 'Only artist can respond');
        }

        fn _register_artist_if_needed(ref self: ContractState, token_contract: ContractAddress) {
            // In a real implementation, this would query the factory to get the artist
            // For now, we'll assume the first caller is the artist if not registered
            let current_artist = self.artists.read(token_contract);
            if current_artist == contract_address_const::<
                0,
            >() { // Query factory for artist address (simplified)
            // self.artists.write(token_contract, factory_artist_address);
            }
        }
    }
}
