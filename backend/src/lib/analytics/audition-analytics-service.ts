import VoteModel from "../../models/VoteModel";

const ROLE_WEIGHT = {
  judge: 3,
  influencer: 2,
  fan: 1,
} as const; 

export async function getVoteAnalytics(auditionId: string) {
  const votes = await VoteModel.find({ auditionId });

  const performerMap: Record<
    string,
    {
      totalWeighted: number;
      totalVotes: number;
      criteriaTotals: Record<string, number>;
      roleCounts: Record<keyof typeof ROLE_WEIGHT, number>;
    }
  > = {};

  for (const vote of votes) {
    const { performerId } = vote;

    const voterRole: keyof typeof ROLE_WEIGHT = vote.voterRole ?? "fan";

    const criteria = vote.criteria ?? {};

    if (!performerMap[performerId]) {
      performerMap[performerId] = {
        totalWeighted: 0,
        totalVotes: 0,
        criteriaTotals: {},
        roleCounts: { judge: 0, influencer: 0, fan: 0 },
      };
    }

    const roleWeight = ROLE_WEIGHT[voterRole];

    performerMap[performerId].totalWeighted += roleWeight;
    performerMap[performerId].totalVotes += 1;
    performerMap[performerId].roleCounts[voterRole] += 1;

    for (const key in criteria) {
      if (!performerMap[performerId].criteriaTotals[key]) {
        performerMap[performerId].criteriaTotals[key] = 0;
      }
      performerMap[performerId].criteriaTotals[key] += criteria[key] * roleWeight;
    }
  }

  return {
    performers: performerMap,
    totalVotes: votes.length,
  };
}

export async function getCommentaryWeights(auditionId: string) {
  const votes = await VoteModel.find({ auditionId });

  return votes.map((vote) => {
    const voterRole: keyof typeof ROLE_WEIGHT = vote.voterRole ?? "fan";
    return {
      performerId: vote.performerId,
      comment: vote.comment,
      voterRole,
      weight: ROLE_WEIGHT[voterRole],
    };
  });
}
