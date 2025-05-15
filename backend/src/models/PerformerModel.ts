import { Schema, model, SortOrder } from "mongoose"
import { Performer } from "../types"

const PerformerSchema = new Schema<Performer>({
  walletAddress: { type: String, required: true },
  seasonId: { type: String, required: true },
  auditionId: { type: String, required: true },
  stageName: { type: String, required: true },
  bio: { type: String, required: true },
  genre: { type: String, required: true },
  country: { type: String, required: true },
  tiktokAuditionUrl: { type: String, required: true },
  tiktokProfileUrl: { type: String, required: true },
  socialX: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
})

// Create a compound index to ensure uniqueness of walletAddress per auditionId
PerformerSchema.index({ walletAddress: 1, auditionId: 1 }, { unique: true })

const PerformerModel = model<Performer>("Performer", PerformerSchema)
export default PerformerModel

/**
 * Create a new performer registration
 */
export const createPerformer = async (performer: Performer) => {
  return await PerformerModel.create(performer)
}

/**
 * Find a performer by wallet address and audition ID
 */
export const findPerformerByWalletAndAudition = async (walletAddress: string, auditionId: string) => {
  return await PerformerModel.findOne({ walletAddress, auditionId })
}

/**
 * Find all performers for a specific audition
 * @param auditionId The ID of the audition
 * @param sort Optional sorting configuration (e.g., { createdAt: -1 })
 */
export const findPerformersByAudition = async (auditionId: string, sort: Record<string, SortOrder> = { createdAt: -1 }) => {
  return await PerformerModel.find({ auditionId }).sort(sort)
}

/**
 * Find all performers for a specific season
 */
export const findPerformersBySeason = async (seasonId: string) => {
  return await PerformerModel.find({ seasonId })
}
