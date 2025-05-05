import { describe, it, expect, jest } from '@jest/globals';
import { hash, ec, Signature } from 'starknet.js';
import { verifyStarknetSignature } from '../verifySignature.starknet';

//Mock starknet.js library dependencies
jest.mock('starknet.js', () => ({
  hash: {
    starknetKeccak: jest.fn()
  },
  ec: {
    starkCurve: {
      verify: jest.fn()
    }
  }
}));

describe('verifyStarknetSignature', () => {
  //Valid test data
  const validWalletAddress = '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const validMessage = 'Test message for signature verification';
  const validSignature: Signature = {
    r: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    s: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
  };
  
  //Setup and teardown for each test
  beforeEach(() => {
    jest.clearAllMocks();
    
    //Setup default mock implementation to return true for valid data
    const mockStarknetKeccak = hash.starknetKeccak as jest.Mock;
    mockStarknetKeccak.mockReturnValue('mocked-hash-value');
    
    const mockVerify = ec.starkCurve.verify as jest.Mock;
    mockVerify.mockReturnValue(true);
  });

  it('should return true for valid signature verification', () => {
    const result = verifyStarknetSignature(validWalletAddress, validMessage, validSignature);
    
    expect(hash.starknetKeccak).toHaveBeenCalledWith(validMessage);
    expect(ec.starkCurve.verify).toHaveBeenCalledWith(validSignature, 'mocked-hash-value', validWalletAddress);
    expect(result).toBe(true);
  });

  it('should return false for invalid signature verification', () => {
    const mockVerify = ec.starkCurve.verify as jest.Mock;
    mockVerify.mockReturnValue(false);
    
    const result = verifyStarknetSignature(validWalletAddress, validMessage, validSignature);
    
    expect(result).toBe(false);
  });

  it('should return false for invalid wallet address format', () => {
    //Log spy to verify error logging
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    
    //Test cases for invalid wallet addresses
    const invalidAddressCases = [
      'invalid-address', // Not hex
      '0x123', // Too short
      '0x' + 'a'.repeat(65), // Too long
      '123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef', // Missing 0x prefix
      123456, // Not a string
      null, // Not a string
      undefined // Not a string
    ];
    
    invalidAddressCases.forEach(invalidAddress => {
      const result = verifyStarknetSignature(invalidAddress as any, validMessage, validSignature);
      expect(result).toBe(false);
      expect(consoleErrorSpy).toHaveBeenCalled();
      consoleErrorSpy.mockClear();
    });
    
    consoleErrorSpy.mockRestore();
  });

  it('should return false for invalid message', () => {
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    
    //Test cases for invalid messages
    const invalidMessageCases = [
      '', // Empty string
      '   ', // Whitespace only
      null, // Not a string
      undefined, // Not a string
      123 // Not a string
    ];
    
    invalidMessageCases.forEach(invalidMessage => {
      const result = verifyStarknetSignature(validWalletAddress, invalidMessage as any, validSignature);
      expect(result).toBe(false);
      expect(consoleErrorSpy).toHaveBeenCalled();
      consoleErrorSpy.mockClear();
    });
    
    consoleErrorSpy.mockRestore();
  });

  it('should return false for invalid signature format', () => {
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    
    //Test cases for invalid signatures
    const invalidSignatureCases = [
      // Missing r
      { s: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' },
      // Missing s
      { r: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' },
      // Invalid r format (no 0x)
      { 
        r: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        s: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
      },
      // Invalid s format (no 0x)
      { 
        r: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        s: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
      },
      // Invalid r format (not hex)
      { 
        r: '0xghijklmnopqrstu0123456789abcdef0123456789abcdef0123456789abcdef',
        s: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
      },
      // Invalid s format (not hex)
      { 
        r: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        s: '0xghijklmnopqrstu0123456789abcdef0123456789abcdef0123456789abcdef'
      },
      // Not an object
      'invalid-signature',
      // r is not a string
      { r: 12345, s: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' },
      // s is not a string
      { r: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef', s: 12345 },
      // r too short
      { 
        r: '0x01234',
        s: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
      },
      // s too short
      { 
        r: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        s: '0x01234'
      },
      null,
      undefined
    ];
    
    invalidSignatureCases.forEach(invalidSignature => {
      const result = verifyStarknetSignature(validWalletAddress, validMessage, invalidSignature as any);
      expect(result).toBe(false);
      expect(consoleErrorSpy).toHaveBeenCalled();
      consoleErrorSpy.mockClear();
    });
    
    consoleErrorSpy.mockRestore();
  });

  it('should handle exceptions thrown by starknet library', () => {
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    
    //Mock starknetKeccak to throw an error
    const mockStarknetKeccak = hash.starknetKeccak as jest.Mock;
    mockStarknetKeccak.mockImplementation(() => {
      throw new Error('Mocked hash function error');
    });
    
    const result = verifyStarknetSignature(validWalletAddress, validMessage, validSignature);
    
    expect(result).toBe(false);
    expect(consoleErrorSpy).toHaveBeenCalled();
    
    consoleErrorSpy.mockRestore();
  });

  it('should handle exceptions thrown by verification function', () => {
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    
    //Mock verify to throw an error
    const mockVerify = ec.starkCurve.verify as jest.Mock;
    mockVerify.mockImplementation(() => {
      throw new Error('Mocked verification error');
    });
    
    const result = verifyStarknetSignature(validWalletAddress, validMessage, validSignature);
    
    expect(result).toBe(false);
    expect(consoleErrorSpy).toHaveBeenCalled();
    
    consoleErrorSpy.mockRestore();
  });

  //Integration test with real values when using the improved version with isValidHex
  it('should validate hex length correctly', () => {
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    
    //Test with r value that's incorrect length
    const invalidLengthSignature = {
      r: '0x0123456789abcdef', // Too short
      s: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
    };
    
    const result = verifyStarknetSignature(validWalletAddress, validMessage, invalidLengthSignature as any);
    
    expect(result).toBe(false);
    expect(consoleErrorSpy).toHaveBeenCalled();
    
    consoleErrorSpy.mockRestore();
  });
});
