// import { constants, TypedDataRevision } from "starknet";


const MySNIP12Message = {
    domain: {
        name: 'MusicStrk',
        chainId: "0x534e5f5345504f4c4941",  // SEPOLIA
        // chainId: "0x534e5f4d41494e",  // MAIN
        version: '1.0.2',
        revision: "1",
    },
    message: {
        message: 'MusicStrk Authentication',
        // do not use BigInt type if message sent to a web browser
    },
    primaryType: 'Simple',
    types: {
        Simple: [
            {
                name: 'message',
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



async function signMessage() {
    console.log("[SiGNiNg]");
    document.getElementById("api").innerText = "";


    const starknet = window.starknet;

    await starknet.enable();

    if (starknet.isConnected === false) {
        console.log("[x] Provider Not Connected [x]");
        return;
    }

    console.log("[+] Connected to Starknet [+]");

    // Make sure we are on testnet (sepolia)
    if (await starknet.account.getChainId() != "0x534e5f5345504f4c4941") {

    // Make sure we are on mainnet (SN_MAIN)
    // if (await starknet.account.getChainId() != "0x534e5f4d41494e") {
        // Request a chain switch
        await starknet.request({
            type: "wallet_switchStarknetChain",
            params: {
                chainId: "0x534e5f5345504f4c4941" // SEPOLIA
                // chainId: "0x534e5f4d41494e" // MAIN
            }
        });
    };

    console.log("[TESTNET]: ", await starknet.account.getChainId());

    const signedMessage = await starknet.account.signMessage(MySNIP12Message);
    console.log("[Signature]: ", signedMessage);
    // console.log("[Signature]: ", signedMessage, signedMessage.toDERHex());
    console.log("[MsgHash]: ", await starknet.account.hashMessage(MySNIP12Message));

    const res = await fetch("http://localhost:8080/api/v1/authenticate", {
        method: "POST",
        body: JSON.stringify({
            walletPubKey: signedMessage[2] || await starknet.account.signer.getPubKey(),
            walletAddress: await starknet.selectedAddress,
            // signature: signedMessage.toDERHex(),
            signature: signedMessage,
            msgHash: await starknet.account.hashMessage(MySNIP12Message),
        }),
        headers: {
            "Content-Type": "application/json",
        },
    });
    const data = await res.json();
    console.log("[Response]: ", data);

    if (res.status === 200) {
        console.log("[+] Authenticated [+]");
        document.getElementById("api").innerText = JSON.stringify(data);
    } else {
        console.log("[x] Authentication Failed [x]");
        document.getElementById("api").innerText = JSON.stringify(data);
    }

}



const signButton = document.getElementById("sign");
signButton.onclick = () => signMessage();

const connectButton = document.getElementById("connect");
connectButton.onclick = () => connectWallet();

console.log("[ListenInG]");