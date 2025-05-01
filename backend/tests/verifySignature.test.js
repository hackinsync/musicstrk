const { verifyWalletSignature } = require('../src/utilities/verifySignature');
const { ethers } = require('ethers');

test('verifies a correct EVM signature', async () => {
    const wallet = ethers.Wallet.createRandom();
    const message = 'Sign this message to authenticate';
    const signature = await wallet.signMessage(message);

    const result = verifyWalletSignature(message, signature, wallet.address);
    expect(result).toBe(true);
});

test('fails if signature is invalid', () => {
    const message = 'Hello';
    const signature = '0xdeadbeef';
    const result = verifyWalletSignature(message, signature, '0x1234567890abcdef1234567890abcdef12345678');
    expect(result).toBe(false);
});
