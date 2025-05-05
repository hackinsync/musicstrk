import crypto from 'crypto';

export class NonceManager {
  private nonces: Map<string, { nonce: string; expiry: number; attempts: number }>;
  private readonly NONCE_EXPIRY_MS = 15 * 60 * 1000; //15 minutes expiration
  private readonly MAX_VERIFICATION_ATTEMPTS = 5; //Max failed verification attempts
  private readonly CLEANUP_INTERVAL_MS = 5 * 60 * 1000; //5 minutes cleanup interval
  private cleanupTimer: NodeJS.Timeout | null = null;
  
  constructor() {
    this.nonces = new Map();
    
    //Periodically clean up expired nonces
    this.cleanupTimer = setInterval(() => this.cleanupExpiredNonces(), this.CLEANUP_INTERVAL_MS);
    
    //Handle cleanup on process termination
    process.on('SIGTERM', () => this.shutdown());
    process.on('SIGINT', () => this.shutdown());
  }
 
  private validateStarknetAddress(walletAddress: string): void {
    if (!walletAddress) {
      throw new Error('Wallet address cannot be empty');
    }
    
    // Validate Starknet address format (0x-prefixed, 64 hex chars)
    if (!/^0x[a-fA-F0-9]{64}$/.test(walletAddress)) {
      throw new Error('Invalid Starknet wallet address. Must be 0x-prefixed and 64 hex characters.');
    }
  }
  
  generateNonce(walletAddress: string): string { 
    this.validateStarknetAddress(walletAddress);
    
    try {
      const randomBytes = crypto.randomBytes(32);
      
      //Add timestamp to prevent replays across time periods
      const timestampBuffer = Buffer.alloc(8);
      timestampBuffer.writeBigUInt64BE(BigInt(Date.now()));
      const combinedBuffer = Buffer.concat([randomBytes, timestampBuffer]);  

      const nonce = '0x' + crypto.createHash('sha256').update(combinedBuffer).digest('hex');
      
      //Store with expiry and reset attempts counter
      const expiry = Date.now() + this.NONCE_EXPIRY_MS;
      const normalizedAddress = walletAddress.toLowerCase();
      
      this.nonces.set(normalizedAddress, { nonce, expiry, attempts: 0 });
      
      return nonce;
    } catch (error) {
      throw new Error(`Failed to generate secure nonce: ${(error as Error).message}`);
    }
  }
  
  verifyNonce(walletAddress: string, nonce: string): boolean {
    if (!walletAddress || !nonce) {
      return false;
    }
    
    try {
      const normalizedAddress = walletAddress.toLowerCase();
      const nonceData = this.nonces.get(normalizedAddress);
      
      //Check if nonce exists
      if (!nonceData) {
        return false;
      }
      
      //Check for too many failed attempts (brute force protection)
      if (nonceData.attempts >= this.MAX_VERIFICATION_ATTEMPTS) {
        this.nonces.delete(normalizedAddress);
        return false;
      }
      
      //Check if nonce has expired
      if (nonceData.expiry < Date.now()) {
        this.nonces.delete(normalizedAddress);
        return false;
      }
      
      //Use constant-time comparison to prevent timing attacks
      const isValid = this.secureCompare(nonceData.nonce, nonce);
      
      if (!isValid) {
        //Increment failed attempts counter
        nonceData.attempts++;
        this.nonces.set(normalizedAddress, nonceData);
        return false;
      }
      
      return true;
    } catch (error) {
      return false;
    }
  }

  private secureCompare(a: string, b: string): boolean {
    // Remove '0x' prefix if present for either string
    const strA = a.startsWith('0x') ? a.slice(2) : a;
    const strB = b.startsWith('0x') ? b.slice(2) : b;
    
    // If lengths differ, strings don't match
    if (strA.length !== strB.length) {
      return false;
    }
    
    try {
      // Use crypto's timingSafeEqual for constant-time comparison
      const bufA = Buffer.from(strA, 'hex');
      const bufB = Buffer.from(strB, 'hex');
      
      return crypto.timingSafeEqual(bufA, bufB);
    } catch (error) {
      // If buffer conversion fails, fall back to a safer comparison
      // Still attempting to be more timing-resistant than direct comparison
      let result = true;
      for (let i = 0; i < strA.length; i++) {
        result = result && (strA.charAt(i) === strB.charAt(i));
      }
      return result;
    }
  }  
 
  invalidateNonce(walletAddress: string): boolean {
    if (!walletAddress) {
      return false;
    }
    
    const normalizedAddress = walletAddress.toLowerCase();
    if (this.nonces.has(normalizedAddress)) {
      this.nonces.delete(normalizedAddress);
      return true;
    }
    
    return false;
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
  
  //Properly release resources when shutting down
  shutdown(): void {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = null;
    }
  }
  
  /**
   * For testing/monitoring: Get the number of active nonces
   */
  getActiveNonceCount(): number {
    return this.nonces.size;
  }
}

export const nonceManager = new NonceManager();
