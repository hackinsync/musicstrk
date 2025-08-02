pub mod IRevenueDistribution;
pub mod RevenueDistribution;
pub mod erc20;
pub mod errors;
pub mod events;
pub mod token_factory;
pub mod audition {
    pub mod season_and_audition;
    pub mod vote_staking_structs;
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
