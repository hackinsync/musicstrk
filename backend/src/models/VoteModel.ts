import { Schema, model } from "mongoose"
import type { Vote, PersonalityScale } from "../types"

const PersonalityScaleSchema = new Schema<PersonalityScale>({
  energy: { type: Number, required: true, min: 1, max: 10 },
  creativity: { type: Number, required: true, min: 1, max: 10 },
  originality: { type: Number, required: true, min: 1, max: 10 },
})

const VoteSchema = new Schema<Vote>({
  auditionId: { type: String, required: true },
  voterTag: { type: String, required: true },
  performerId: { type: String, required: true },
  walletAddress: { type: String, required: true },
  score: { type: Number, min: 1, max: 10 },
  personalityScale: { type: PersonalityScaleSchema, required: true },
  createdAt: { type: Date, default: Date.now },
  comment: { type: String }, 
  voterRole: { type: String, enum: ["judge", "fan", "influencer"] }, 
  criteria: { type: Schema.Types.Mixed }, 
})

// Create a compound index to ensure uniqueness of walletAddress per performerId and auditionId
VoteSchema.index({ walletAddress: 1, performerId: 1, auditionId: 1 }, { unique: true })

const VoteModel = model<Vote>("Vote", VoteSchema)
export default VoteModel

/**
 * Create a new vote
 */
export const createVote = async (vote: Vote) => {
  return await VoteModel.create(vote)
}

/**
 * Find a vote by wallet address, performer ID, and audition ID
 */
export const findVoteByWalletPerformerAndAudition = async (
  walletAddress: string,
  performerId: string,
  auditionId: string,
) => {
  return await VoteModel.findOne({ walletAddress, performerId, auditionId })
}

/**
 * Find all votes for a specific performer in an audition
 */
export const findVotesByPerformerAndAudition = async (performerId: string, auditionId: string) => {
  return await VoteModel.find({ performerId, auditionId })
}

/**
 * Find all votes for a specific audition
 */
export const findVotesByAudition = async (auditionId: string) => {
  return await VoteModel.find({ auditionId })
}

/**
 * Calculate average scores for a performer in an audition
 */
export const calculateAverageScores = async (performerId: string, auditionId: string) => {
  const result = await VoteModel.aggregate([
    { $match: { performerId, auditionId } },
    {
      $group: {
        _id: null,
        averageScore: { $avg: "$score" },
        averageEnergy: { $avg: "$personalityScale.energy" },
        averageCreativity: { $avg: "$personalityScale.creativity" },
        averageOriginality: { $avg: "$personalityScale.originality" },
        totalVotes: { $sum: 1 },
      },
    },
  ])

  return result.length > 0 ? result[0] : null
}
