const { nonceManager } = require('../src/utilities/nonceManager');

test('generates and validates a nonce correctly', () => {
    const wallet = '0x1234567890abcdef1234567890abcdef12345678';
    const nonce = nonceManager.generateNonce(wallet);
    expect(typeof nonce).toBe('string');
    expect(nonceManager.verifyNonce(wallet, nonce)).toBe(true);
});

test('rejects invalid nonce', () => {
    const wallet = '0x1234567890abcdef1234567890abcdef12345678';
    nonceManager.generateNonce(wallet);
    expect(nonceManager.verifyNonce(wallet, '0xnotthenonce')).toBe(false);
});

test('invalidates a nonce after use', () => {
    const wallet = '0x1234567890abcdef1234567890abcdef12345678';
    const nonce = nonceManager.generateNonce(wallet);
    expect(nonceManager.verifyNonce(wallet, nonce)).toBe(true);
    nonceManager.invalidateNonce(wallet);
    expect(nonceManager.verifyNonce(wallet, nonce)).toBe(false);
});
