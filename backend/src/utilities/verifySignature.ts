import { hash, ec, Signature } from 'starknet';

const HEX_PREFIX = '0x';
const WALLET_ADDRESS_LENGTH = 66; // 0x + 64 chars
const HEX_REGEX = /^0x[0-9a-fA-F]+$/;
const SIGNATURE_COMPONENT_LENGTH = 66; // 


function isValidHex(value: string, exactLength?: number): boolean {
  if (!HEX_REGEX.test(value)) return false;
  if (exactLength !== undefined && value.length !== exactLength) return false;
  return true;
}

export function verifyStarknetSignature(
  walletAddress: string,
  message: string,
  signature: Signature
): boolean {
  try {
    // Validate address format
    if (
      typeof walletAddress !== 'string' ||
      !isValidHex(walletAddress, WALLET_ADDRESS_LENGTH)
    ) {
      throw new Error('Invalid wallet address format. Must be 0x-prefixed, 64 hex chars.');
    }

    // Validate signature
    if (
      typeof signature !== 'object' ||
      typeof signature.r !== 'string' ||
      typeof signature.s !== 'string' ||
      !isValidHex(signature.r, SIGNATURE_COMPONENT_LENGTH) ||
      !isValidHex(signature.s, SIGNATURE_COMPONENT_LENGTH)
    ) {
      throw new Error('Invalid signature. r and s must be 0x-prefixed hex strings of correct length.');
    }

    // Validate message
    if (typeof message !== 'string' || message.trim() === '') {
      throw new Error('Message must be a non-empty string');
    }

    // Compute message hash using Starknet hash function
    const msgHash = hash.starknetKeccak(message);
    
    // Perform cryptographic signature verification
    return ec.starkCurve.verify(signature, msgHash, walletAddress);
  } catch (err) {
    console.error('[Starknet Signature Verification Error]', err);
    return false;
  }
}
