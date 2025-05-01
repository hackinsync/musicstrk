import { verifyMessage } from "ethers";

/**
 * Verifies that a signature was created by the owner of a specific Ethereum wallet address
 * 
 * @param message - The original message that was signed (includes the nonce)
 * @param signature - The cryptographic signature to verify
 * @param expectedAddress - The wallet address that supposedly created the signature
 * @returns boolean - True if the signature is valid and matches the address, false otherwise
 */

export function verifyWalletSignature(
  message: string,
  signature: string,
  expectedAddress: string
): boolean {
  try {
    //Validate inputs
    if (!message || !signature || !expectedAddress) {
        return false;
      }

    // Basic format validation for wallet address
    if (!expectedAddress.match(/^0x[a-fA-F0-9]{40}$/) &&
        !expectedAddress.match(/^0x[a-fA-F0-9]{64}$/)) {
        return false;
      }
      
      const normalizedExpectedAddress = expectedAddress.toLowerCase();
      
      const recoveredAddress = verifyMessage(message, signature);
      
      //Compare the recovered address with the expected address (case insensitive)
      return recoveredAddress.toLowerCase() === normalizedExpectedAddress;
    } catch (err) {
      console.error('Signature verification error:', err);
      return false;
    }
  }
