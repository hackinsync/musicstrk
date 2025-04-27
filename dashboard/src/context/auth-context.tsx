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

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const { address, isConnected, account, status } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnectAsync } = useDisconnect()
  const [isLoading, setIsLoading] = useState(true)
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false)
  const [error, setError] = useState<string | null>(null)
  const [connectingWallet, setConnectingWallet] = useState<boolean>(false)

  // Check authentication status whenever connection status changes
  useEffect(() => {
    const checkAuth = async () => {
      const token = localStorage.getItem('authToken')
      setIsAuthenticated(!!token && !!isConnected)
      setIsLoading(false)
    }

    if (status !== 'connecting') {
      checkAuth()
    }
  }, [isConnected, status])

  // Handle the completion or failure of a wallet connection
  useEffect(() => {
    if (connectingWallet) {
      if (status === 'connected' && account && address) {
        // Proceed with authentication
        completeAuthentication()
      } else if (status === 'disconnected' && !isLoading) {
        // Connection failed or cancelled
        console.log('Connection failed or cancelled')
        setConnectingWallet(false)
        setError('Wallet connection was cancelled or failed')
        setIsLoading(false)
      }
    }
  }, [status, connectingWallet, account, address])

  const completeAuthentication = async () => {
    try {
      setConnectingWallet(false)
      if (isConnected && account && address) {
        const signature = await account?.signMessage(
          AUTHENTICATION_SNIP12_MESSAGE
        )
        const token = await authenticateWallet(address, signature)
        localStorage.setItem('authToken', token)
        setIsAuthenticated(true)
        setError(null)
      }
    } catch (err) {
      console.error('Authentication error:', err)
      const errorMessage =
        err instanceof Error ? err.message : 'Authentication failed'
      setError(errorMessage)
    } finally {
      setIsLoading(false)
    }
  }

  const signIn = async (connectorId: string) => {
    try {
      setError(null)
      setIsLoading(true)

      const connector = connectors.find((c) => c.id === connectorId)
      if (!connector) {
        throw new Error('Wallet not found')
      }

      if (typeof window === 'undefined' || !(window as any).starknet) {
        throw new Error(
          'Wallet provider not detected. Please install Argent X or Braavos.'
        )
      }

      // Initiate the connection and set flag to track connection process
      setConnectingWallet(true)
      connect({ connector })
    } catch (err) {
      console.error('Connection error:', err)
      setConnectingWallet(false)
      setIsLoading(false)
      const errorMessage =
        err instanceof Error ? err.message : 'Connection failed'
      setError(errorMessage)
      throw new Error(errorMessage)
    }
  }

  const signOut = async () => {
    try {
      await disconnectAsync();
      localStorage.removeItem('authToken');
      setIsAuthenticated(false);
      setError(null);
    } catch (err) {
      console.error('Sign out error:', err);
      const errorMessage = err instanceof Error ? err.message : 'Failed to sign out';
      setError(errorMessage);
    }
  };

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated,
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
