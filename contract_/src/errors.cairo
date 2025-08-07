pub mod errors {
    // Ownership & Authorization errors (1000-1999)
    pub const CALLER_NOT_AUTH_OR_ARTIST: felt252 = 'Not owner or authorized artist';
    pub const CALLER_NOT_OWNER: felt252 = 'Caller is not the owner';
    pub const CALLER_UNAUTHORIZED: felt252 = 'Caller is not authorized';
    pub const CALLER_ZERO_ADDRESS: felt252 = 'Caller is address zero';
    pub const OWNER_ZERO_ADDRESS: felt252 = 'Owner cannot be address zero';
    pub const PROPOSAL_SYSTEM_ZERO_ADDRESS: felt252 = 'Proposal cannot be address zero';
    pub const VOTING_MECHANISM_ZERO_ADDRESS: felt252 = 'Voting cannot be address zero';

    // Address validation errors (2000-2999)
    pub const INVALID_SENDER: felt252 = 'Invalid spender';
    pub const RECIPIENT_ZERO_ADDRESS: felt252 = 'Recipient is address zero';
    pub const SENDER_ZERO_ADDRESS: felt252 = 'Sender cannot be address zero';
    pub const ZERO_ADDRESS_DETECTED: felt252 = 'Caller is address zero';

    // Token operation errors (3000-3999)
    pub const TOKEN_NOT_DEPLOYED: felt252 = 'Token not yet deployed';
    pub const TOKEN_ALREADY_INITIALIZED: felt252 = 'Token already initialized';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';

    // Validation errors (4000-4999)
    pub const INDEX_OUT_OF_BOUNDS: felt252 = 'Index out of bounds;';
    pub const INVALID_CLASS_HASH: felt252 = 'Class hash cannot be zero';

    // Voting errors (6000-6999)
    pub const DUPLICATE_VOTE: felt252 = 'Vote already exists';

    // Vote Staking errors
    pub const AUDITION_DOES_NOT_EXIST: felt252 = 'Audition does not exist';
    pub const AUDITION_HAS_ENDED: felt252 = 'Audition has ended';
    pub const AUDITION_NOT_YET_ENDED: felt252 = 'Audition not yet ended';
    pub const STAKE_TOKEN_CANNOT_BE_ZERO: felt252 = 'Stake token cannot be zero';
    pub const STAKE_AMOUNT_MUST_BE_GRAETER_THAN_ZERO: felt252 = 'Stake amount must be > 0';
    pub const STAKING_NOT_ENABLED: felt252 = 'Staking not enabled';
    pub const ALREADY_STAKED: felt252 = 'Already staked';
    pub const NO_STAKE_TO_WITHDRAW: felt252 = 'No stake to withdraw';
    pub const WITHDRAWAL_DELAY_ACTIVE: felt252 = 'Withdrawal delay active';
    pub const TRANSFER_FAILED: felt252 = 'transfer failed';
}
