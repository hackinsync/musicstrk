// import { constants, TypedDataRevision } from "starknet";


const MySNIP12Message = {
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

async function signMessage() {
    console.log("[SiGNiNg]");

    const starknet = window.starknet;

    await starknet.enable();

    if (starknet.isConnected === false) {
        console.log("[x] Provider Not Connected [x]");
        return;
    }

    console.log("[+] Connected to Starknet [+]");
    // const myProvider = {}; // Replace with your provider
    // const address = '0x...'; // Replace with your account address
    // const privateKey = '0x...'; // Replace with your private key

    // const account0 = new Account(myProvider, address, privateKey);
    // Make sure we are on testnet (sepolia)
    if (await starknet.account.getChainId() != "0x534e5f5345504f4c4941") {
        // Request a chain switch
        await starknet.request({
            type: "wallet_switchStarknetChain",
            params: {
                chainId: "0x534e5f5345504f4c4941" // SEPOLIA
            }
        });
    };

    console.log("[TESTNET]: ", await starknet.account.getChainId());

    const signedMessage = await starknet.account.signMessage(MySNIP12Message);
    console.log("[Signature]: ", signedMessage);

    // try {
    //     const msgHash = await account0.hashMessage(myTypedData);
    //     const signature = (await account0.signMessage(myTypedData));
    //     console.log('Message Hash:', msgHash);
    //     console.log('Signature:', signature);
    // } catch (error) {
    //     console.error('Error signing message:', error);
    // }
}

async function connectWallet() {
    console.log("[CoNNeCTiNG]");
    if (window.starknet === undefined) {
        console.log("[x] No Injected Provider Found [x]");
        return false;
    }

    await window.starknet.enable();

    if (window.starknet.isConnected) {
        const address = await window.starknet.selectedAddress;
        const connectButton = document.getElementById("connect");
        connectButton.classList.remove("not-connected");
        connectButton.classList.add("connected");
        connectButton.textContent = address;
        console.log("[+] Connected to Starknet [+]");
    } else {
        console.log("[x] Provider Not Connected [x]");
    }
}

const signButton = document.getElementById("sign");
signButton.onclick = () => signMessage();

const connectButton = document.getElementById("connect");
connectButton.onclick = () => connectWallet();

console.log("[ListenInG]");