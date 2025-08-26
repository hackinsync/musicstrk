pub mod IRevenueDistribution;
pub mod RevenueDistribution;
pub mod erc20;
pub mod errors;
pub mod events;
pub mod token_factory;
pub mod audition {
    pub mod season_and_audition;
    pub mod stake_to_vote;
    pub mod types {
        pub mod season_and_audition;
        pub mod stake_to_vote;
    }
    pub mod interfaces {
        pub mod iseason_and_audition;
        pub mod istake_to_vote;
    }
}
pub mod governance {
    pub mod GovernanceToken;
    pub mod ProposalSystem;
    pub mod VotingMechanism;
    pub mod types;
}
pub mod presets {
    pub mod mock_erc20;
}
