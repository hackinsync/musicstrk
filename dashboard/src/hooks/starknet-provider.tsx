'use client'

import { sepolia, mainnet } from '@starknet-react/chains'
import {
  alchemyProvider,
  argent,
  infuraProvider,
  lavaProvider,
  nethermindProvider,
  reddioProvider,
  StarknetConfig,
  starkscan,
  useInjectedConnectors,
} from '@starknet-react/core'


interface StarknetProviderProps {
  children: React.ReactNode
}

export function StarknetProvider({ children }: StarknetProviderProps) {
  const { connectors } = useInjectedConnectors({
    recommended: [argent()],
    includeRecommended: 'always',
  })

  const apiKey = import.meta.env.VITE_RPC_API_KEY
  const nodeProvider = import.meta.env.VITE_STARKNET_RPC



  let provider
  if (nodeProvider == 'infura') {
    provider = infuraProvider({ apiKey })
  } else if (nodeProvider == 'alchemy') {
    provider = alchemyProvider({ apiKey })
  } else if (nodeProvider == 'lava') {
    provider = lavaProvider({ apiKey })
  } else if (nodeProvider == 'nethermind') {
    provider = nethermindProvider({ apiKey })
  } else {
    provider = reddioProvider({ apiKey })
  }

  return (
    <StarknetConfig
      connectors={connectors}
      chains={[sepolia, mainnet]}
      provider={provider}
      explorer={starkscan}
      autoConnect
    >
      {children}
    </StarknetConfig>
  )
}
