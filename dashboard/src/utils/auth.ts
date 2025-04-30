import { Signature } from 'starknet'
import { API_BASE_URL } from './constants'

export async function authenticateWallet(
  walletAddress: `0x${string}` | undefined,
  signature: Signature
) {
  const response = await fetch(`${API_BASE_URL}/auth/authenticate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      walletAddress,
      signature,
    }),
  })

  if (!response.ok) {
    const error = await response.json()
    throw new Error(error.msg || 'Authentication failed')
  }

  const data = await response.json()
  return data.token
}
