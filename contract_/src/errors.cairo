pub mod errors {
    // Ownership & Authorization errors (1000-1999)
    pub const CALLER_NOT_AUTH_OR_ARTIST: felt252 = 'Not owner or authorized artist';
    pub const CALLER_NOT_OWNER: felt252 = 'Caller is not the owner';
    pub const CALLER_UNAUTHORIZED: felt252 = 'Caller is not authorized';
    pub const CALLER_ZERO_ADDRESS: felt252 = 'Caller is address zero';
    pub const OWNER_ZERO_ADDRESS: felt252 = 'Owner cannot be address zero';

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
}
