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

export interface PersonalityScale {
  energy: number
  creativity: number
  originality: number
}

export interface Vote {
  _id?: string
  auditionId: string
  voterTag: string
  performerId: string
  walletAddress: string
  score?: number
  personalityScale: PersonalityScale
  createdAt?: Date
  comment?: string;
  voterRole?: "judge" | "fan";
  criteria?: {
    [key: string]: number;
  };
}

export interface VotePayload {
  auditionId: string
  voterTag: string
  performerId: string
  walletAddress: string
  score?: number
  personalityScale: PersonalityScale
}
