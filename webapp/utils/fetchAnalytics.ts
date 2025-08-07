
export async function fetchVoteAnalytics(auditionId: string) {
  const res = await fetch(`${process.env.NEXT_PUBLIC_BACKEND_URL}/analytics/votes/${auditionId}`);
  if (!res.ok) throw new Error("Failed to fetch vote analytics");
  return res.json();
}

export async function fetchCommentaryWeights(auditionId: string) {
  const res = await fetch(`${process.env.NEXT_PUBLIC_BACKEND_URL}/analytics/comments/${auditionId}`);
  if (!res.ok) throw new Error("Failed to fetch commentary weights");
  return res.json();
}
