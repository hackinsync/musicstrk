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
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';

    // Initialization errors (4000-4999)
    pub const TOKEN_ALREADY_INITIALIZED: felt252 = 'Token already initialized';

    // Validation errors (5000-5999)
    pub const INDEX_OUT_OF_BOUNDS: felt252 = 'Index out of bounds;';
    pub const INVALID_CLASS_HASH: felt252 = 'Class hash cannot be zero';
    pub const INVALID_TIMESTAMP: felt252 = 'Invalid timestamp';
    pub const INVALID_SCORE: felt252 = 'Invalid score';
    pub const INVALID_CONFIDENCE: felt252 = 'Invalid confidence level';
    pub const INVALID_VERIFICATION_LEVEL: felt252 = 'Invalid verification level';
    pub const INVALID_ARRAY_LENGTH: felt252 = 'Invalid array length';
    pub const ARRAYS_LENGTH_MISMATCH: felt252 = 'Arrays length mismatch';

    // Season and Audition errors (6000-6999)
    pub const SEASON_NOT_FOUND: felt252 = 'Season not found';
    pub const AUDITION_NOT_FOUND: felt252 = 'Audition not found';
    pub const AUDITION_PAUSED: felt252 = 'Audition is paused';
    pub const AUDITION_NOT_STARTED: felt252 = 'Audition not started';
    pub const AUDITION_ENDED: felt252 = 'Audition has ended';
    pub const DUPLICATE_VOTE: felt252 = 'Vote already exists';

    // Oracle-specific errors (7000-7999)
    pub const ORACLE_NOT_AUTHORIZED: felt252 = 'Oracle not authorized';
    pub const ORACLE_ALREADY_AUTHORIZED: felt252 = 'Oracle already authorized';
    pub const ORACLE_LOW_REPUTATION: felt252 = 'Oracle reputation too low';
    pub const ORACLE_INSUFFICIENT_STAKE: felt252 = 'Insufficient oracle stake';
    pub const ORACLE_ALREADY_STAKED: felt252 = 'Oracle already staked';
    pub const ORACLE_NOT_STAKED: felt252 = 'Oracle not staked';
    pub const ORACLE_COOLDOWN_ACTIVE: felt252 = 'Oracle cooldown active';
    pub const ORACLE_BLACKLISTED: felt252 = 'Oracle is blacklisted';

    // Data Submission errors (8000-8999)
    pub const DATA_ALREADY_SUBMITTED: felt252 = 'Data already submitted';
    pub const DATA_NOT_FOUND: felt252 = 'Data not found';
    pub const DATA_EXPIRED: felt252 = 'Data has expired';
    pub const DATA_CORRUPTED: felt252 = 'Data integrity check failed';
    pub const SUBMISSION_TOO_FREQUENT: felt252 = 'Submission too frequent';
    pub const INVALID_SUBMISSION_HASH: felt252 = 'Invalid submission hash';
    pub const SUBMISSION_WINDOW_CLOSED: felt252 = 'Submission window closed';
    pub const MALFORMED_DATA: felt252 = 'Malformed data submission';

    // Consensus and Conflict Resolution errors (9000-9999)
    pub const CONSENSUS_NOT_REACHED: felt252 = 'Consensus not reached';
    pub const INSUFFICIENT_SUBMISSIONS: felt252 = 'Insufficient submissions';
    pub const CONFLICT_UNRESOLVED: felt252 = 'Data conflict unresolved';
    pub const CONSENSUS_THRESHOLD_TOO_HIGH: felt252 = 'Consensus threshold too high';
    pub const VARIANCE_TOO_HIGH: felt252 = 'Data variance too high';
    pub const CONFLICTING_DATA: felt252 = 'Conflicting data detected';

    // Batch Operations errors (10000-10999)
    pub const BATCH_TOO_LARGE: felt252 = 'Batch size too large';
    pub const BATCH_EMPTY: felt252 = 'Batch cannot be empty';
    pub const BATCH_PARTIAL_FAILURE: felt252 = 'Batch partially failed';
    pub const BATCH_LENGTH_MISMATCH: felt252 = 'Batch arrays length mismatch';

    // Performance and Gas errors (11000-11999)
    pub const GAS_LIMIT_EXCEEDED: felt252 = 'Gas limit exceeded';
    pub const OPERATION_TOO_EXPENSIVE: felt252 = 'Operation too expensive';
    pub const RATE_LIMIT_EXCEEDED: felt252 = 'Rate limit exceeded';

    // Network and Integration errors (12000-12999)
    pub const NETWORK_ERROR: felt252 = 'Network communication error';
    pub const EXTERNAL_CALL_FAILED: felt252 = 'External call failed';
    pub const INVALID_VENUE_DATA: felt252 = 'Invalid venue data';
    pub const PROVIDER_UNAVAILABLE: felt252 = 'Provider unavailable';

    // Security errors (13000-13999)
    pub const REPLAY_ATTACK_DETECTED: felt252 = 'Replay attack detected';
    pub const INVALID_SIGNATURE: felt252 = 'Invalid signature';
    pub const UNAUTHORIZED_ACCESS: felt252 = 'Unauthorized access';
    pub const SECURITY_VIOLATION: felt252 = 'Security violation detected';
    pub const SUSPICIOUS_ACTIVITY: felt252 = 'Suspicious activity detected';

    // Legacy compatibility
    pub const INVALID_PROPOSAL_ID: felt252 = 'Invalid proposal ID';
    pub const INVALID_CHOICE: felt252 = 'Invalid choice';
    pub const ORACLE_NOT_WHITELISTED: felt252 = 'Oracle not whitelisted';
    pub const AUDITION_DOES_NOT_EXIST: felt252 = 'Audition does not exist';
    pub const SESSION_DOES_NOT_EXIST: felt252 = 'Session does not exist';
    pub const INVALID_SESSION_STATUS: felt252 = 'Invalid session status';
    pub const INVALID_PARTICIPANT_ID: felt252 = 'Invalid participant ID';
    pub const INVALID_PROVIDER: felt252 = 'Invalid provider';
}
