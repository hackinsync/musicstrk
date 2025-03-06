

enum Role {
  user, admin
}


export interface User {
  id: BigInt;
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