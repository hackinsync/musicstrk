import {
  Vote,
  Performer,
  VoteActivity,
  PerformerVoteData,
  VoteCriteria,
} from "./types/votes";

// Mock performers
const performers: Performer[] = [
  {
    id: "1",
    name: "Emma Johnson",
    imageUrl: "https://randomuser.me/api/portraits/women/1.jpg",
  },
  {
    id: "2",
    name: "Michael Chen",
    imageUrl: "https://randomuser.me/api/portraits/men/2.jpg",
  },
  {
    id: "3",
    name: "Sofia Rodriguez",
    imageUrl: "https://randomuser.me/api/portraits/women/3.jpg",
  },
  {
    id: "4",
    name: "David Kim",
    imageUrl: "https://randomuser.me/api/portraits/men/4.jpg",
  },
  {
    id: "5",
    name: "Olivia Williams",
    imageUrl: "https://randomuser.me/api/portraits/women/5.jpg",
  },
  {
    id: "6",
    name: "James Taylor",
    imageUrl: "https://randomuser.me/api/portraits/men/6.jpg",
  },
  {
    id: "7",
    name: "Ava Martinez",
    imageUrl: "https://randomuser.me/api/portraits/women/7.jpg",
  },
  {
    id: "8",
    name: "Ethan Brown",
    imageUrl: "https://randomuser.me/api/portraits/men/8.jpg",
  },
];

// Generate random votes
const generateMockVotes = (auditionId: string, count: number): Vote[] => {
  const votes: Vote[] = [];

  for (let i = 0; i < count; i++) {
    const performerId =
      performers[Math.floor(Math.random() * performers.length)].id;
    const timestamp = new Date(
      Date.now() - Math.floor(Math.random() * 48) * 60 * 60 * 1000
    ).toISOString();

    votes.push({
      id: `vote-${i}`,
      auditionId,
      voterWalletAddress: `0x${Math.random().toString(16).slice(2, 12)}`,
      performerId,
      timestamp,
      criteria: {
        vocalPower: Math.floor(Math.random() * 10) + 1,
        diction: Math.floor(Math.random() * 10) + 1,
        confidence: Math.floor(Math.random() * 10) + 1,
        timing: Math.floor(Math.random() * 10) + 1,
        stagePresence: Math.floor(Math.random() * 10) + 1,
        musicalExpression: Math.floor(Math.random() * 10) + 1,
      },
    });
  }

  return votes;
};

// Get a specific performer by ID
export const getPerformerById = (
  performerId: string
): Performer | undefined => {
  return performers.find((performer) => performer.id === performerId);
};

// Get all performers
export const getAllPerformers = (): Performer[] => {
  return performers;
};

// Get votes for a specific audition
export const getMockVotes = (auditionId: string): Vote[] => {
  return generateMockVotes(auditionId, 150); 
};

// Calculate aggregate performer data from votes
export const calculatePerformerData = (votes: Vote[]): PerformerVoteData[] => {
  const performerMap = new Map<
    string,
    {
      voteCount: number;
      criteriaSum: VoteCriteria;
    }
  >();

  // Initialize map with all performers
  performers.forEach((performer) => {
    performerMap.set(performer.id, {
      voteCount: 0,
      criteriaSum: {
        vocalPower: 0,
        diction: 0,
        confidence: 0,
        timing: 0,
        stagePresence: 0,
        musicalExpression: 0,
      },
    });
  });

  // Aggregate votes
  votes.forEach((vote) => {
    const performerData = performerMap.get(vote.performerId);

    if (performerData) {
      performerData.voteCount += 1;

      // Sum up all criteria
      Object.keys(vote.criteria).forEach((key) => {
        const criteriaKey = key as keyof VoteCriteria;
        performerData.criteriaSum[criteriaKey] += vote.criteria[criteriaKey];
      });
    }
  });

  // Calculate averages and create final data
  const performerData: PerformerVoteData[] = [];

  performerMap.forEach((data, performerId) => {
    const performer = performers.find((p) => p.id === performerId);

    if (performer && data.voteCount > 0) {
      const criteriaAverages: VoteCriteria = {
        vocalPower:
          Math.round((data.criteriaSum.vocalPower / data.voteCount) * 10) / 10,
        diction:
          Math.round((data.criteriaSum.diction / data.voteCount) * 10) / 10,
        confidence:
          Math.round((data.criteriaSum.confidence / data.voteCount) * 10) / 10,
        timing:
          Math.round((data.criteriaSum.timing / data.voteCount) * 10) / 10,
        stagePresence:
          Math.round((data.criteriaSum.stagePresence / data.voteCount) * 10) /
          10,
        musicalExpression:
          Math.round(
            (data.criteriaSum.musicalExpression / data.voteCount) * 10
          ) / 10,
      };

      // Calculate aggregate score as average of all criteria
      const aggregateScore =
        Object.values(criteriaAverages).reduce((sum, val) => sum + val, 0) /
        Object.keys(criteriaAverages).length;

      performerData.push({
        performer,
        aggregateScore: Math.round(aggregateScore * 10) / 10,
        voteCount: data.voteCount,
        criteriaAverages,
      });
    }
  });

  return performerData.sort((a, b) => b.aggregateScore - a.aggregateScore);
};

// Calculate unique voters
export const calculateUniqueVoters = (votes: Vote[]): number => {
  const uniqueVoters = new Set(votes.map((vote) => vote.voterWalletAddress));
  return uniqueVoters.size;
};

// Calculate vote activity by hour (last 48 hours)
export const calculateVoteActivity = (votes: Vote[]): VoteActivity[] => {
  const hourlyActivity: Record<number, number> = {};

  // Initialize all hours with 0
  for (let i = 0; i < 48; i++) {
    hourlyActivity[i] = 0;
  }

  
  votes.forEach((vote) => {
    const voteTime = new Date(vote.timestamp);
    const now = new Date();
    const hoursDiff = Math.floor(
      (now.getTime() - voteTime.getTime()) / (1000 * 60 * 60)
    );

    if (hoursDiff < 48) {
      hourlyActivity[hoursDiff] = (hourlyActivity[hoursDiff] || 0) + 1;
    }
  });

  
  return Object.entries(hourlyActivity)
    .map(([hour, voteCount]) => ({
      hour: parseInt(hour),
      voteCount,
    }))
    .sort((a, b) => a.hour - b.hour);
};
