import { type ReactNode } from 'react'
import { StarknetConfig, InjectedConnector, braavos, argent, useInjectedConnectors } from '@starknet-react/core'
import { RpcProvider, constants } from 'starknet'


// Define supported chains
const chains = [
  {
    id: BigInt(constants.StarknetChainId.SN_MAIN),
    network: 'mainnet',
    name: 'Starknet Mainnet',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
      address:
        '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7' as `0x${string}`, // ETH contract address
    },
    rpcUrls: {
      default: {
        http: ['https://starknet-sepolia.drpc.org'],
      },
      public: {
        http: ['https://starknet-sepolia.drpc.org'],
      },
    },
    explorerUrl: 'https://starkscan.co',
  },
  {
    id: BigInt(constants.StarknetChainId.SN_SEPOLIA),
    network: 'sepolia',
    name: 'Starknet Sepolia',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
      address:
        '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7' as `0x${string}`, // ETH contract address
    },
    rpcUrls: {
      default: {
        http: ['https://free-rpc.nethermind.io/sepolia-juno/'], // Consider using Infura or Alchemy
      },
      public: {
        http: ['https://free-rpc.nethermind.io/sepolia-juno/'],
      },
    },
    explorerUrl: 'https://sepolia.starkscan.co',
  },
]

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
  includeRecommended: "always",
});
  // Validate environment variables
  const rpcUrl = 'https://free-rpc.nethermind.io/sepolia-juno/'
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
  const provider = () => {
    return new RpcProvider({
      nodeUrl: rpcUrl,
      chainId: isTestnet
        ? constants.StarknetChainId.SN_SEPOLIA
        : constants.StarknetChainId.SN_MAIN,
    })
  }

  return (
    <StarknetConfig
      chains={chains}
      connectors={connectors}
      provider={provider}
      defaultChainId={defaultChainId}
      autoConnect
    >
      {children}
    </StarknetConfig>
  )
}
