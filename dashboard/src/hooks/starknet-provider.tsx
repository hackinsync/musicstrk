import { type ReactNode } from 'react'
import { sepolia, mainnet } from '@starknet-react/chains'
import {
  StarknetConfig,
  jsonRpcProvider,
  braavos,
  argent,
  useInjectedConnectors,
  voyager,
} from '@starknet-react/core'
import { constants } from 'starknet'

/**
 * StarknetProvider component that configures the Starknet React context
 * for the application.
 *
 * @param {Object} props - Component props
 * @param {ReactNode} props.children - Child components
 * @returns {JSX.Element} Configured StarknetConfig provider
 */
export function StarknetProvider({ children }: { children: ReactNode }) {
  // Define available wallet connectors
  const { connectors } = useInjectedConnectors({
    // Optionally, you can customize the connectors
    recommended: [argent(), braavos()],
    includeRecommended: 'always',
    order: 'random',
  })
  // Validate environment variables
  const rpcUrl = 'https://free-rpc.nethermind.io/sepolia-juno'
  const isTestnet = true

  if (!rpcUrl) {
    throw new Error('Missing RPC URL configuration')
  }

  // Determine which chain to use based on environment
  const defaultChainId = BigInt(
    isTestnet
      ? constants.StarknetChainId.SN_SEPOLIA
      : constants.StarknetChainId.SN_MAIN
  )

  // Create a provider function
  const provider = jsonRpcProvider({
    rpc: () => ({ nodeUrl: rpcUrl }),
  })

  return (
    <StarknetConfig
      chains={[sepolia, mainnet]}
      connectors={connectors}
      provider={provider}
      // defaultChainId={defaultChainId}
      explorer={voyager}
    >
      {children}
    </StarknetConfig>
  )
}
