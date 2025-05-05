import crypto from 'crypto';

//Manages nonces for wallet verification to prevent replay attacks
export class NonceManager {
  private nonces: Map<string, { nonce: string, expiry: number }>;
  private readonly NONCE_EXPIRY_MS = 15 * 60 * 1000; // 15 minutes expiration
  
  constructor() {
    this.nonces = new Map();
    
    //Periodically clean up expired nonces
    setInterval(() => this.cleanupExpiredNonces(), 5 * 60 * 1000); // every 5 minutes
  }
  
  //Generate a new nonce for a wallet address
  generateNonce(walletAddress: string): string { 
    if (
      !walletAddress ||
      !/^0x[a-fA-F0-9]{64}$/.test(walletAddress)
    ) {
      throw new Error('Invalid Starknet wallet address. Must be 0x-prefixed and 64 hex characters.');
    }

    const nonce = '0x' + crypto.randomBytes(32).toString('hex');
    const expiry = Date.now() + this.NONCE_EXPIRY_MS;

    this.nonces.set(walletAddress.toLowerCase(), { nonce, expiry });
    return nonce;
  }
  
  //verify a nonce for a wallet address
  verifyNonce(walletAddress: string, nonce: string): boolean {
    if (!walletAddress || !nonce) {
      return false;
    }
    
    const normalizedAddress = walletAddress.toLowerCase();
    const nonceData = this.nonces.get(normalizedAddress);
    
    //Check if nonce exists and is valid
    if (!nonceData || nonceData.nonce !== nonce) {
      return false;
    }
    
    // Check if nonce has expired
    if (nonceData.expiry < Date.now()) {
      //Remove expired nonce
      this.nonces.delete(normalizedAddress);
      return false;
    }
    
    return true;
  }
  
  //Invalidate a nonce after use to prevent replay attacks
  invalidateNonce(walletAddress: string): void {
    if (walletAddress) {
      this.nonces.delete(walletAddress.toLowerCase());
    }
  }
  
  //Clean up 
  private cleanupExpiredNonces(): void {
    const now = Date.now();
    
    for (const [address, nonceData] of this.nonces.entries()) {
      if (nonceData.expiry < now) {
        this.nonces.delete(address);
      }
    }
  }
}

//Export a singleton instance
export const nonceManager = new NonceManager();
