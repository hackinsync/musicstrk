    pub mod errors {
        pub const OWNER_ZERO_ADDRESS: felt252 = 'Owner cannot be address zero';
        pub const INVALID_SENDER: felt252 = 'Invalid spender';
        pub const SENDER_ZERO_ADDRESS: felt252 = 'Sender cannot be address zero';
        pub const RECIPIENT_ZERO_ADDRESS: felt252 = 'Recipient is address zero';
        pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';
        pub const CALLER_ZERO_ADDRESS: felt252 = 'Caller is address zero';
        pub const CALLER_NOT_OWNER: felt252 = 'Caller is not the owner';
    }