pub mod errors {
    pub const CALLER_NOT_AUTH_OR_ARTIST: felt252 = 'Not owner or authorized artist';
    pub const CALLER_NOT_OWNER: felt252 = 'Caller is not the owner';
    pub const CALLER_UNAUTHORIZED: felt252 = 'Caller is not authorized';
    pub const INDEX_OUT_OF_BOUNDS: felt252 = 'Index out of bounds;';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const INVALID_CLASS_HASH: felt252 = 'Class hash cannot be zero';
    pub const INVALID_SENDER: felt252 = 'Invalid spender';
    pub const OWNER_ZERO_ADDRESS: felt252 = 'Owner cannot be address zero';
    pub const RECIPIENT_ZERO_ADDRESS: felt252 = 'Recipient is address zero';
    pub const SENDER_ZERO_ADDRESS: felt252 = 'Sender cannot be address zero';
    pub const TOKEN_ALREADY_INITIALIZED: felt252 = 'Token already initialized';
    pub const ZERO_ADDRESS_DETECTED: felt252 = 'Caller is address zero';
}
