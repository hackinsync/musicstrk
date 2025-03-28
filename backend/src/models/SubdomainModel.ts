import { Schema, model } from "mongoose"

export interface Subdomain {
  name: string
  userId: Schema.Types.ObjectId
  isActive: boolean
  createdAt: Date
  updatedAt: Date
}

const SubdomainSchema = new Schema<Subdomain>({
  name: { type: String, required: true, unique: true, lowercase: true },
  userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
  isActive: { type: Boolean, default: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
})

// Create index for faster lookups
SubdomainSchema.index({ name: 1 })

const SubdomainModel = model<Subdomain>("Subdomain", SubdomainSchema)
export default SubdomainModel

// Helper functions
export const getSubdomainByName = async (name: string) => {
  return await SubdomainModel.findOne({ name, isActive: true })
}

export const createSubdomain = async (subdomain: Omit<Subdomain, "createdAt" | "updatedAt">) => {
  return await SubdomainModel.create(subdomain)
}

export const updateSubdomain = async (name: string, updates: Partial<Subdomain>) => {
  return await SubdomainModel.findOneAndUpdate({ name }, { ...updates, updatedAt: new Date() }, { new: true })
}

export const deleteSubdomain = async (name: string) => {
  return await SubdomainModel.findOneAndUpdate({ name }, { isActive: false, updatedAt: new Date() }, { new: true })
}

