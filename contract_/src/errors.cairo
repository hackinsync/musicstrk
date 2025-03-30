pub mod errors {
    // Ownership & Authorization errors (1000-1999)
    pub const OWNER_ZERO_ADDRESS: felt252 = 'Owner cannot be address zero';
    pub const CALLER_NOT_OWNER: felt252 = 'Caller is not the owner';
    pub const CALLER_ZERO_ADDRESS: felt252 = 'Caller is address zero';
    
    // Address validation errors (2000-2999)
    pub const SENDER_ZERO_ADDRESS: felt252 = 'Sender cannot be address zero';
    pub const RECIPIENT_ZERO_ADDRESS: felt252 = 'Recipient is address zero';
    pub const INVALID_SENDER: felt252 = 'Invalid spender';
    
    // Token operation errors (3000-3999)
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';
    
    // Initialization errors (4000-4999)
    pub const TOKEN_ALREADY_INITIALIZED: felt252 = 'Token already initialized';
}