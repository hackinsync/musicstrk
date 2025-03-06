import { constants, TypedDataRevision } from "starknet";


export const AUTHENTICATION_SNIP12_MESSAGE = {
    domain: {
        name: 'MusicStrk',
        chainId: "0x534e5f5345504f4c4941",  // SEPOLIA
        version: '1.0.2',
        revision: "1",
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
};

export const AUTHENTICATION_SNIP12_MESSAGE_HASH = "0x3fb79316e367534b134a6cc217a66b71eeb38c92006496058b9036a7c306fa4";