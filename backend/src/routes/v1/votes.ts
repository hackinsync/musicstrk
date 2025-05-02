import { Router, type Request, type Response } from "express"
import { validateJWT } from "../../middlewares"
import {
  createVote,
  findVoteByWalletPerformerAndAudition,
  findVotesByPerformerAndAudition,
  findVotesByAudition,
  calculateAverageScores,
} from "../../models/VoteModel"
import type { VotePayload, Vote } from "../../types"

const VotesRoutes = Router()

/**
 * Emits a webhook event for a new vote
 */
async function emitVoteEvent(vote: Vote) {
  // Check if webhook URL is configured
  const webhookUrl = process.env.VOTE_WEBHOOK_URL
  if (!webhookUrl) {
    console.log("No webhook URL configured, skipping event emission")
    return
  }

  try {
    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-API-Key": process.env.WEBHOOK_API_KEY || "",
      },
      body: JSON.stringify({
        event: "new_vote",
        data: vote,
        timestamp: new Date().toISOString(),
      }),
    })

    if (!response.ok) {
      throw new Error(`Webhook failed with status: ${response.status}`)
    }

    return await response.json()
  } catch (error) {
    console.error("Webhook emission failed:", error)
    throw error
  }
}

/**
 * POST /api/v1/votes
 * Submit a new vote for a performer
 */
VotesRoutes.post("/", validateJWT, async (req: Request<{}, {}, VotePayload>, res: Response): Promise<void> => {
  try {
    const { auditionId, voterTag, performerId, walletAddress, score, personalityScale } = req.body

    console.log("Processing vote request:", req.body)

    // Check all required fields
    if (
      !auditionId ||
      !voterTag ||
      !performerId ||
      !walletAddress ||
      !personalityScale ||
      typeof personalityScale !== "object" ||
      typeof personalityScale.energy !== "number" ||
      typeof personalityScale.creativity !== "number" ||
      typeof personalityScale.originality !== "number"
    ) {
      console.log("Missing or invalid required fields:", {
        hasAudition: !!auditionId,
        hasVoterTag: !!voterTag,
        hasPerformer: !!performerId,
        hasWallet: !!walletAddress,
        hasValidPersonalityScale:
          personalityScale &&
          typeof personalityScale === "object" &&
          typeof personalityScale.energy === "number" &&
          typeof personalityScale.creativity === "number" &&
          typeof personalityScale.originality === "number",
      })

      res.status(400).json({ error: true, msg: "Missing or invalid required fields" })
      return
    }

    // Validate score and personality scale values (1-10)
    if (
      (score !== undefined && (score < 1 || score > 10)) ||
      personalityScale.energy < 1 ||
      personalityScale.energy > 10 ||
      personalityScale.creativity < 1 ||
      personalityScale.creativity > 10 ||
      personalityScale.originality < 1 ||
      personalityScale.originality > 10
    ) {
      console.log("Invalid score values:", {
        score,
        energy: personalityScale.energy,
        creativity: personalityScale.creativity,
        originality: personalityScale.originality,
      })

      res.status(400).json({ error: true, msg: "All scores must be between 1 and 10" })
      return
    }

    // Check for duplicate vote
    const existingVote = await findVoteByWalletPerformerAndAudition(walletAddress, performerId, auditionId)
    if (existingVote) {
      console.log("Duplicate vote detected:", { walletAddress, performerId, auditionId })

      res.status(409).json({ error: true, msg: "You have already voted for this performer in this audition" })
      return
    }

    // Create new vote record
    const vote = await createVote({
      auditionId,
      voterTag,
      performerId,
      walletAddress,
      score,
      personalityScale,
    })

    console.log("Vote recorded successfully:", { id: vote._id })

    // Optional: Emit webhook/event for backend tallying
    if (process.env.VOTE_WEBHOOK_URL) {
      try {
        await emitVoteEvent(vote)
        console.log("Vote event emitted for tallying")
      } catch (eventError) {
        // Log the error but don't fail the request
        console.error("Failed to emit vote event:", eventError)
      }
    }

    res.status(201).json({ error: false, msg: "Vote recorded successfully", vote })
  } catch (error: any) {
    console.error("Vote submission failed:", { body: req.body, error })

    // Check for duplicate key error from MongoDB (code 11000)
    if (error.name === "MongoError" && error.code === 11000) {
      res.status(409).json({ error: true, msg: "You have already voted for this performer in this audition" })
      return
    }

    // Add more specific error handling
    if (error.name === "ValidationError") {
      res.status(400).json({ error: true, msg: "Validation error", details: error.message })
      return
    }

    res.status(500).json({ error: true, msg: "Server error" })
  }
})

/**
 * GET /api/v1/votes/audition/:auditionId
 * Get all votes for a specific audition
 */
VotesRoutes.get("/audition/:auditionId", validateJWT, async (req: Request, res: Response): Promise<void> => {
  try {
    const { auditionId } = req.params

    if (!auditionId) {
      res.status(400).json({ error: true, msg: "Audition ID is required" })
      return
    }

    const votes = await findVotesByAudition(auditionId)
    res.status(200).json({ error: false, votes })
  } catch (error: any) {
    console.error("Failed to fetch votes:", error)
    res.status(500).json({ error: true, msg: "Server error" })
  }
})

/**
 * GET /api/v1/votes/performer/:performerId/audition/:auditionId
 * Get all votes for a specific performer in an audition
 */
VotesRoutes.get(
  "/performer/:performerId/audition/:auditionId",
  validateJWT,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { performerId, auditionId } = req.params

      if (!performerId || !auditionId) {
        res.status(400).json({ error: true, msg: "Performer ID and Audition ID are required" })
        return
      }

      const votes = await findVotesByPerformerAndAudition(performerId, auditionId)
      res.status(200).json({ error: false, votes })
    } catch (error: any) {
      console.error("Failed to fetch votes:", error)
      res.status(500).json({ error: true, msg: "Server error" })
    }
  },
)

/**
 * GET /api/v1/votes/stats/performer/:performerId/audition/:auditionId
 * Get statistics for a specific performer in an audition
 */
VotesRoutes.get(
  "/stats/performer/:performerId/audition/:auditionId",
  validateJWT,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const { performerId, auditionId } = req.params

      if (!performerId || !auditionId) {
        res.status(400).json({ error: true, msg: "Performer ID and Audition ID are required" })
        return
      }

      const stats = await calculateAverageScores(performerId, auditionId)

      if (!stats) {
        res.status(404).json({ error: true, msg: "No votes found for this performer in this audition" })
        return
      }

      res.status(200).json({ error: false, stats })
    } catch (error: any) {
      console.error("Failed to calculate statistics:", error)
      res.status(500).json({ error: true, msg: "Server error" })
    }
  },
)

export default VotesRoutes
