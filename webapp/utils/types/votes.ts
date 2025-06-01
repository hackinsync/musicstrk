// Define the vote criteria types
export type VoteCriteria = {
  vocalPower: number;
  diction: number;
  confidence: number;
  timing: number;
  stagePresence: number;
  musicalExpression: number;
};

// Define the vote type
export type Vote = {
  id: string;
  auditionId: string;
  voterWalletAddress: string;
  performerId: string;
  timestamp: string;
  criteria: VoteCriteria;
};

// Define performer type with name for display
export type Performer = {
  id: string;
  name: string;
  imageUrl?: string;
};

// Define voter type
export type Voter = {
  walletAddress: string;
  voteCount: number;
};

// Define aggregated vote data for a performer
export type PerformerVoteData = {
  performer: Performer;
  aggregateScore: number;
  voteCount: number;
  criteriaAverages: VoteCriteria;
};

// Define time-based vote activity
export type VoteActivity = {
  hour: number;
  voteCount: number;
};
