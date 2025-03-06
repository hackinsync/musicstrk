
export enum Role {
  ADMIN = 'ADMIN',
  USER = 'USER'
}


export interface User {
  _id: BigInt;
  name: string;
  email: string;
  walletAddress: string;
  pubKey: string;
  role: Role;
  createdAt: Date;
}


export interface JWTPayload {
  user: User
}