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
    
    // Contract state errors (7000-7999)
    pub const CONTRACT_PAUSED: felt252 = 'Contract is paused';
    
    // Audition errors (8000-8999)
    pub const AUDITION_NOT_FOUND: felt252 = 'Audition does not exist';
    pub const AUDITION_PAUSED: felt252 = 'Audition is paused';
    pub const AUDITION_ENDED: felt252 = 'Audition has ended';
    pub const AUDITION_NOT_ENDED: felt252 = 'Audition must end first';
    pub const AUDITION_NOT_PAUSED: felt252 = 'Audition is not paused';
    pub const AUDITION_NOT_CANCELED_OR_ENDED: felt252 = 'Audition not canceled/ended';
    
    // Registration errors (9000-9999)
    pub const ALREADY_REGISTERED: felt252 = 'Already registered';
    pub const NO_FEE_TO_REFUND: felt252 = 'No fee to refund';
    pub const ALREADY_REFUNDED: felt252 = 'Registration already refunded';
    
    // Token transfer errors (10000-10999)
    pub const TRANSFER_FAILED: felt252 = 'Transfer failed';
    pub const REFUND_TRANSFER_FAILED: felt252 = 'Refund transfer failed';
    pub const INVALID_TOKEN_ADDRESS: felt252 = 'Invalid token address';
    pub const FEE_AMOUNT_TOO_LARGE: felt252 = 'Fee amount too large';
    pub const AMOUNT_TOO_LARGE: felt252 = 'Amount too large';
    
    // Prize errors (11000-11999)
    pub const NO_PRIZE: felt252 = 'No prize for this audition';
    pub const PRIZE_ALREADY_DEPOSITED: felt252 = 'Prize already deposited';
    pub const PRIZE_ALREADY_DISTRIBUTED: felt252 = 'Prize already distributed';
    pub const INVALID_AMOUNT: felt252 = 'Amount must be more than zero';
    pub const INVALID_WINNER_ADDRESS: felt252 = 'null contract address';
    pub const INVALID_SHARES_TOTAL: felt252 = 'total does not add up';
    
    // Authorization errors (12000-12999)
    pub const NOT_AUTHORIZED: felt252 = 'Not Authorized';
}
