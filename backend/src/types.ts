export enum Role {
  ADMIN = "ADMIN",
  USER = "USER",
}

export interface User {
  _id?: bigint
  name?: string
  email?: string
  walletAddress: string
  pubKey: string
  role?: Role
  createdAt?: Date
}

export interface JWTPayload {
  user: User
}

export interface Performer {
  _id?: string
  walletAddress: string
  seasonId: string
  auditionId: string
  stageName: string
  bio: string
  genre: string
  country: string
  tiktokAuditionUrl: string
  tiktokProfileUrl: string
  socialX: string
  createdAt?: Date
}

export interface PerformerRegistrationPayload {
  walletAddress: string
  seasonId: string
  auditionId: string
  stageName: string
  bio: string
  genre: string
  country: string
  tiktokAuditionUrl: string
  tiktokProfileUrl: string
  socialX: string
}
