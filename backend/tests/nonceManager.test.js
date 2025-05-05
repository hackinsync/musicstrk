import { NonceManager } from '../nonceManager';
import crypto from 'crypto';

// Mock crypto.randomBytes to make tests predictable
jest.mock('crypto', () => ({
  randomBytes: jest.fn(),
  createHash: jest.fn(),
  timingSafeEqual: jest.fn()
}));

describe('NonceManager', () => {
  let nonceManager: NonceManager;
  const mockWalletAddress = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
  const invalidWalletAddress = '0x123'; // Too short
  const mockNonce = '0x1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
  
  beforeEach(() => {
    jest.clearAllMocks();
    nonceManager = new NonceManager();
    
    // Setup crypto mocks to return predictable values
    // Mock randomBytes to return a buffer with predictable content
    const mockBuffer = Buffer.from('1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff', 'hex');
    (crypto.randomBytes as jest.Mock).mockReturnValue(mockBuffer);
    
    // Mock createHash to return an object with digest method
    const mockHashDigest = {
      update: jest.fn().mockReturnThis(),
      digest: jest.fn().mockReturnValue(Buffer.from('1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff', 'hex'))
    };
    (crypto.createHash as jest.Mock).mockReturnValue(mockHashDigest);
    
    // Mock timingSafeEqual to simulate proper comparison
    (crypto.timingSafeEqual as jest.Mock).mockImplementation((a, b) => {
      // Simple implementation for testing purposes
      return a.toString('hex') === b.toString('hex');
    });
    
    // Replace the auto cleanup interval with a mock
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
    // Ensure proper shutdown of the nonce manager
    nonceManager.shutdown();
  });

  describe('generateNonce', () => {
    test('should generate valid nonce for valid wallet address', () => {
      const nonce = nonceManager.generateNonce(mockWalletAddress);
      expect(nonce).toBe(mockNonce);
      expect(crypto.randomBytes).toHaveBeenCalledWith(32);
    });

    test('should store nonce with expiry time', () => {
      jest.spyOn(Date, 'now').mockImplementation(() => 1000);
      nonceManager.generateNonce(mockWalletAddress);
      
      // Access private property for testing (using any type casting)
      const nonceData = (nonceManager as any).nonces.get(mockWalletAddress.toLowerCase());
      expect(nonceData).toBeDefined();
      expect(nonceData.nonce).toBe(mockNonce);
      // 15 minutes (900000ms) + 1000ms mock time
      expect(nonceData.expiry).toBe(901000);
    });

    test('should throw error for invalid wallet address format', () => {
      expect(() => {
        nonceManager.generateNonce(invalidWalletAddress);
      }).toThrow('Invalid Starknet wallet address. Must be 0x-prefixed and 64 hex characters.');
    });

    test('should throw error for empty wallet address', () => {
      expect(() => {
        nonceManager.generateNonce('');
      }).toThrow('Wallet address cannot be empty');
    });

    test('should normalize wallet address to lowercase when storing', () => {
      const mixedCaseAddress = '0xABCDef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
      nonceManager.generateNonce(mixedCaseAddress);
      
      // Access private property for testing
      const hasNonce = (nonceManager as any).nonces.has(mixedCaseAddress.toLowerCase());
      expect(hasNonce).toBe(true);
    });

    test('should overwrite previous nonce when generating for same wallet', () => {
      const firstNonce = nonceManager.generateNonce(mockWalletAddress);
      
      // Change mock implementation for second call
      const mockNewBuffer = Buffer.from('0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff', 'hex');
      (crypto.randomBytes as jest.Mock).mockReturnValue(mockNewBuffer);
      
      // Update digest mock for new hash
      const mockNewHashDigest = {
        update: jest.fn().mockReturnThis(),
        digest: jest.fn().mockReturnValue(Buffer.from('0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff', 'hex'))
      };
      (crypto.createHash as jest.Mock).mockReturnValue(mockNewHashDigest);
      
      const secondNonce = nonceManager.generateNonce(mockWalletAddress);
      expect(secondNonce).not.toBe(firstNonce);
      
      // Only the second nonce should be stored
      const storedNonce = (nonceManager as any).nonces.get(mockWalletAddress.toLowerCase()).nonce;
      expect(storedNonce).toBe(secondNonce);
    });
  });

  describe('verifyNonce', () => {
    test('should verify valid non-expired nonce', () => {
      nonceManager.generateNonce(mockWalletAddress);
      const isValid = nonceManager.verifyNonce(mockWalletAddress, mockNonce);
      expect(isValid).toBe(true);
    });

    test('should reject invalid nonce value', () => {
      nonceManager.generateNonce(mockWalletAddress);
      const isValid = nonceManager.verifyNonce(mockWalletAddress, '0xWRONGNONCE');
      expect(isValid).toBe(false);
    });

    test('should reject when no nonce exists for wallet', () => {
      const isValid = nonceManager.verifyNonce(mockWalletAddress, mockNonce);
      expect(isValid).toBe(false);
    });

    test('should reject expired nonce and remove it', () => {
      jest.spyOn(Date, 'now').mockImplementation(() => 1000);
      nonceManager.generateNonce(mockWalletAddress);
      
      // Fast forward past expiration time
      jest.spyOn(Date, 'now').mockImplementation(() => 1000 + 16 * 60 * 1000); // 16 minutes later
      
      const isValid = nonceManager.verifyNonce(mockWalletAddress, mockNonce);
      expect(isValid).toBe(false);
      
      // Should be removed from storage
      const hasNonce = (nonceManager as any).nonces.has(mockWalletAddress.toLowerCase());
      expect(hasNonce).toBe(false);
    });

    test('should handle empty inputs gracefully', () => {
      expect(nonceManager.verifyNonce('', '')).toBe(false);
      expect(nonceManager.verifyNonce(mockWalletAddress, '')).toBe(false);
      expect(nonceManager.verifyNonce('', mockNonce)).toBe(false);
    });

    test('should normalize wallet address for verification', () => {
      nonceManager.generateNonce(mockWalletAddress.toLowerCase());
      const isValid = nonceManager.verifyNonce(mockWalletAddress.toUpperCase(), mockNonce);
      expect(isValid).toBe(true);
    });
    
    test('should increment attempts counter on failed verification', () => {
      nonceManager.generateNonce(mockWalletAddress);
      
      // First attempt - wrong nonce
      nonceManager.verifyNonce(mockWalletAddress, '0xWRONGNONCE');
      
      // Check attempts counter
      const nonceData = (nonceManager as any).nonces.get(mockWalletAddress.toLowerCase());
      expect(nonceData.attempts).toBe(1);
      
      // Try multiple times and verify counter increases
      nonceManager.verifyNonce(mockWalletAddress, '0xWRONGNONCE');
      nonceManager.verifyNonce(mockWalletAddress, '0xSTILLWRONG');
      
      const updatedNonceData = (nonceManager as any).nonces.get(mockWalletAddress.toLowerCase());
      expect(updatedNonceData.attempts).toBe(3);
    });
    
    test('should delete nonce after max verification attempts', () => {
      nonceManager.generateNonce(mockWalletAddress);
      
      // Make MAX_VERIFICATION_ATTEMPTS failed attempts
      for (let i = 0; i < 5; i++) {
        nonceManager.verifyNonce(mockWalletAddress, '0xWRONGNONCE');
      }
      
      // After max attempts, the nonce should be deleted
      const hasNonce = (nonceManager as any).nonces.has(mockWalletAddress.toLowerCase());
      expect(hasNonce).toBe(false);
    });
  });

  describe('invalidateNonce', () => {
    test('should remove nonce after invalidation', () => {
      nonceManager.generateNonce(mockWalletAddress);
      const result = nonceManager.invalidateNonce(mockWalletAddress);
      
      expect(result).toBe(true);
      const hasNonce = (nonceManager as any).nonces.has(mockWalletAddress.toLowerCase());
      expect(hasNonce).toBe(false);
    });

    test('should return false when invalidating non-existent nonces', () => {
      const result = nonceManager.invalidateNonce('0xNONEXISTENT1234567890abcdef1234567890abcdef1234567890abcdef');
      expect(result).toBe(false);
    });

    test('should return false for empty wallet address', () => {
      const result = nonceManager.invalidateNonce('');
      expect(result).toBe(false);
    });

    test('should normalize wallet address for invalidation', () => {
      nonceManager.generateNonce(mockWalletAddress.toLowerCase());
      const result = nonceManager.invalidateNonce(mockWalletAddress.toUpperCase());
      
      expect(result).toBe(true);
      const hasNonce = (nonceManager as any).nonces.has(mockWalletAddress.toLowerCase());
      expect(hasNonce).toBe(false);
    });
  });

  describe('cleanupExpiredNonces', () => {
    test('should remove expired nonces during cleanup', () => {
      // Setup initial time
      jest.spyOn(Date, 'now').mockImplementation(() => 1000);
      
      // Generate nonces for two wallets
      nonceManager.generateNonce(mockWalletAddress);
      const secondWallet = '0x0000000000abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      nonceManager.generateNonce(secondWallet);
      
      // Fast forward time to expire only first nonce
      jest.spyOn(Date, 'now').mockImplementation(() => 1000 + 16 * 60 * 1000); // 16 minutes
      
      // Manually call cleanup (private method access through any)
      (nonceManager as any).cleanupExpiredNonces();
      
      // Check that first nonce is removed but second remains
      const hasFirstNonce = (nonceManager as any).nonces.has(mockWalletAddress.toLowerCase());
      const hasSecondNonce = (nonceManager as any).nonces.has(secondWallet.toLowerCase());
      
      expect(hasFirstNonce).toBe(false);
      expect(hasSecondNonce).toBe(true);
    });

    test('should perform cleanup on the scheduled interval', () => {
      jest.spyOn(Date, 'now').mockImplementation(() => 1000);
      nonceManager.generateNonce(mockWalletAddress);
      
      // Verify nonce exists initially
      const hasNonceBefore = (nonceManager as any).nonces.has(mockWalletAddress.toLowerCase());
      expect(hasNonceBefore).toBe(true);
      
      // Fast forward past expiration
      jest.spyOn(Date, 'now').mockImplementation(() => 1000 + 16 * 60 * 1000);
      
      // Fast forward the timer to trigger the cleanup interval (5 minutes)
      jest.advanceTimersByTime(5 * 60 * 1000 + 100);
      
      // Check that cleanup was performed
      const hasNonceAfter = (nonceManager as any).nonces.has(mockWalletAddress.toLowerCase());
      expect(hasNonceAfter).toBe(false);
    });
  });

  describe('Singleton instance', () => {
    test('should export a singleton instance', () => {
      // Import the singleton
      const { nonceManager } = require('../nonceManager');
      
      // Verify it's an instance of NonceManager
      expect(nonceManager instanceof NonceManager).toBe(true);
      
      // Generate a nonce using the singleton
      const nonce = nonceManager.generateNonce(mockWalletAddress);
      expect(nonce).toBeDefined();
    });
  });

  describe('Race conditions and edge cases', () => {
    test('should handle many concurrent nonce requests', () => {
      // Generate many nonces concurrently
      const addresses = Array.from({ length: 100 }, (_, i) => 
        `0x${i.toString().padStart(64, '0')}`
      );
      
      addresses.forEach(addr => {
        nonceManager.generateNonce(addr);
      });
      
      // Verify all were stored
      const storedCount = (nonceManager as any).nonces.size;
      expect(storedCount).toBe(addresses.length);
    });
    
    test('should handle verify/invalidate race condition', () => {
      nonceManager.generateNonce(mockWalletAddress);
      
      // First verify
      const isValid1 = nonceManager.verifyNonce(mockWalletAddress, mockNonce);
      expect(isValid1).toBe(true);
      
      // Invalidate
      nonceManager.invalidateNonce(mockWalletAddress);
      
      // Try to verify again
      const isValid2 = nonceManager.verifyNonce(mockWalletAddress, mockNonce);
      expect(isValid2).toBe(false);
    });
  });
  
  describe('secureCompare', () => {
    test('should compare nonces with or without 0x prefix', () => {
      // Access private method for testing
      const compare = (nonceManager as any).secureCompare.bind(nonceManager);
      
      expect(compare('0xabcd', '0xabcd')).toBe(true);
      expect(compare('0xabcd', 'abcd')).toBe(true);
      expect(compare('abcd', '0xabcd')).toBe(true);
      expect(compare('abcd', 'abcd')).toBe(true);
      expect(compare('0xabcd', '0xABCD')).toBe(false);
    });
    
    test('should return false for different length strings', () => {
      const compare = (nonceManager as any).secureCompare.bind(nonceManager);
      expect(compare('0xabcd', '0xabcdef')).toBe(false);
    });
    
    test('should handle error cases gracefully', () => {
      // Force an error in timingSafeEqual by mocking it to throw
      (crypto.timingSafeEqual as jest.Mock).mockImplementation(() => {
        throw new Error('Mocked error');
      });
      
      const compare = (nonceManager as any).secureCompare.bind(nonceManager);
      expect(compare('0xabcd', '0xabcd')).toBe(true);
      expect(compare('0xabcd', '0xABCD')).toBe(false);
    });
  });
  
  describe('getActiveNonceCount', () => {
    test('should return correct count of active nonces', () => {
      expect(nonceManager.getActiveNonceCount()).toBe(0);
      
      nonceManager.generateNonce(mockWalletAddress);
      expect(nonceManager.getActiveNonceCount()).toBe(1);
      
      const secondWallet = '0x0000000000abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      nonceManager.generateNonce(secondWallet);
      expect(nonceManager.getActiveNonceCount()).toBe(2);
      
      nonceManager.invalidateNonce(mockWalletAddress);
      expect(nonceManager.getActiveNonceCount()).toBe(1);
    });
  });
});
