import express from "express";
import { getVoteAnalytics, getCommentaryWeights } from "../../lib/analytics/audition-analytics-service.js";

const auditionsRouter = express.Router();

// GET /api/v1/auditions/:id/vote-analytics
auditionsRouter.get("/:id/vote-analytics", async (req, res) => {
  try {
    const auditionId = req.params.id;
    const analytics = await getVoteAnalytics(auditionId);
    res.json(analytics);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to fetch vote analytics" });
  }
});

// GET /api/v1/auditions/:id/commentary-weight
auditionsRouter.get("/:id/commentary-weight", async (req, res) => {
  try {
    const auditionId = req.params.id;
    const result = await getCommentaryWeights(auditionId);
    res.json(result);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to fetch commentary weights" });
  }
});

export default auditionsRouter;
