pub mod errors {
    // Judge Management errors (7000-7999)
    pub const JUDGE_ALREADY_ASSIGNED: felt252 = 'Judge already assigned';
    pub const JUDGE_NOT_ASSIGNED: felt252 = 'Judge not assigned';
    pub const JUDGE_NOT_FOUND: felt252 = 'Judge not found';
    pub const JUDGE_WEIGHT_EXCEEDS_LIMIT: felt252 = 'Judge weight exceeds limit';
    pub const CELEBRITY_WEIGHT_EXCEEDS_LIMIT: felt252 = 'Celebrity weight exceeds limit';
    pub const TOTAL_JUDGE_WEIGHT_EXCEEDED: felt252 = 'Total judge weight exceeded';
    pub const MAX_JUDGES_LIMIT_REACHED: felt252 = 'Max judges limit reached';
    pub const MIN_JUDGES_REQUIREMENT_NOT_MET: felt252 = 'Min judges requirement not met';
    pub const JUDGE_NOT_ACTIVE: felt252 = 'Judge not active';
    pub const JUDGE_ALREADY_ACTIVE: felt252 = 'Judge already active';
    pub const EXPERTISE_LEVEL_INVALID: felt252 = 'Expertise level must be 1-5';
    pub const WEIGHT_ADJUSTMENT_FORBIDDEN: felt252 = 'Weight adjustment forbidden';
    pub const VOTING_ALREADY_STARTED: felt252 = 'Voting already started';
    pub const EVALUATION_PERIOD_ENDED: felt252 = 'Evaluation period ended';
    pub const JUDGE_PAYMENT_ALREADY_PROCESSED: felt252 = 'Payment already processed';
    pub const JUDGE_NOT_ELIGIBLE_FOR_PAYMENT: felt252 = 'Judge not eligible for payment';
    pub const INSUFFICIENT_POOL_BALANCE: felt252 = 'Insufficient pool balance';
    pub const INVALID_WEIGHT_LIMITS: felt252 = 'Invalid weight limits';
    pub const BATCH_ASSIGNMENT_FAILED: felt252 = 'Batch assignment failed';
    pub const ARRAY_LENGTH_MISMATCH: felt252 = 'Array length mismatch';
}