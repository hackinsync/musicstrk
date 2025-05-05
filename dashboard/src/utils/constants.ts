import { TypedData } from 'starknet'

export const AUTHENTICATION_SNIP12_MESSAGE = {
  domain: {
    name: 'MusicStrk',
    chainId: '0x534e5f5345504f4c4941', // SEPOLIA
    // chainId: "0x534e5f4d41494e",  // MAIN
    version: '1.0.2',
    revision: '1',
  },
  message: {
    name: 'MusicStrk Authentication',
    // do not use BigInt type if message sent to a web browser
  },
  primaryType: 'Simple',
  types: {
    Simple: [
      {
        name: 'name',
        type: 'shortstring',
      },
    ],
    StarknetDomain: [
      {
        name: 'name',
        type: 'shortstring',
      },
      {
        name: 'chainId',
        type: 'shortstring',
      },
      {
        name: 'version',
        type: 'shortstring',
      },
    ],
  },
} as TypedData

export const API_BASE_URL = `${import.meta.env.VITE_API_URL}/api/v1`
