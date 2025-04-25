import {
  createContext,
  useContext,
  useEffect,
  useState,
  ReactNode,
} from 'react'
import { useAccount, useConnect, useDisconnect } from '@starknet-react/core'
import { authenticateWallet } from '@/utils/auth'
import { AUTHENTICATION_SNIP12_MESSAGE } from '@/utils/constants'

interface AuthContextType {
  isAuthenticated: boolean
  isLoading: boolean
  walletAddress: string | null
  error: string | null
  signIn: (connectorId: string) => Promise<void>
  signOut: () => Promise<void>
}

// Wait for account to be available
const waitForAccount = async (
  account: any,
  maxAttempts = 10,
  interval = 500
): Promise<any> => {
  for (let i = 0; i < maxAttempts; i++) {
    if (account) return account
    await new Promise((resolve) => setTimeout(resolve, interval))
  }
  throw new Error('Account not available after waiting')
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const { address, isConnected, account } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()
  const [isLoading, setIsLoading] = useState(true)
  const [isAuthenticated, setIsAuthenticated] = useState<boolean | undefined>(
    false
  )
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    console.log('Account:', account)
    console.log('Address:', address)
    console.log('Is Connected:', isConnected)

    const token = localStorage.getItem('authToken')
    setIsAuthenticated(!!token && isConnected)
    setIsLoading(false)
  }, [isConnected, account, address])

  const signIn = async (connectorId: string) => {
    try {
      setError(null)
      setIsLoading(true)

      const connector = connectors.find((c) => c.id === connectorId)
      if (!connector) {
        throw new Error('Wallet not found')
      }

      console.log('connector:', connector)

      const wallet = await connect({ connector })

      // Wait for connection to be established
      await new Promise((resolve) => setTimeout(resolve, 1000))

      console.log('Wallet:', wallet)
      console.log('Account:', account)
      console.log('IsConnected:', isConnected)

      if (!isConnected) {
        throw new Error('Failed to connect to wallet')
      }

      const resolvedAccount = await waitForAccount(account)

      if (!resolvedAccount) {
        throw new Error('No account found')
      }

      const signature = await resolvedAccount.signMessage({
        domain: {
          name: 'MusicStrk',
          version: '1',
        },
        types: {
          StarkNetDomain: [
            { name: 'name', type: 'string' },
            { name: 'version', type: 'string' },
          ],
          Message: [{ name: 'message', type: 'string' }],
        },
        primaryType: 'Message',
        message: {
          message: AUTHENTICATION_SNIP12_MESSAGE,
        },
      })

      // Authenticate with backend
      const token = await authenticateWallet(address, signature)

      localStorage.setItem('authToken', token)
      setIsAuthenticated(true)
    } catch (err) {
      console.error('Authentication error:', err)
      setError(err instanceof Error ? err.message : 'Authentication failed')
      throw err
    } finally {
      setIsLoading(false)
    }
  }

  const signOut = async () => {
    try {
      await disconnect()
      localStorage.removeItem('authToken')
      setIsAuthenticated(false)
    } catch (err) {
      console.error('Sign out error:', err)
      setError(err instanceof Error ? err.message : 'Failed to sign out')
    }
  }

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated: isAuthenticated ?? false,
        isLoading,
        walletAddress: address ?? null,
        error,
        signIn,
        signOut,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
