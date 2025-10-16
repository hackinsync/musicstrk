const request = require("supertest")
const express = require("express")
const { json } = require("express")
const { Account, Provider, ec, hash, typedData, constants } = require("starknet")

// Create a real provider for testing
const provider = new Provider({
  sequencer: { 
    baseUrl: process.env.NODE_ENV === "production" 
      ? "https://alpha-mainnet.starknet.io" 
      : "https://alpha4.starknet.io" 
  }
})

// Test account setup - you should use a real test account
const TEST_PRIVATE_KEY = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
const TEST_ACCOUNT_ADDRESS = "0x1234567890abcdef1234567890abcdef12345678"

describe("Wallet Verification API", () => {
  let app

  beforeAll(() => {
    // Setup express app with the auth routes
    const AuthRoutes = require("../src/routes/v1/auth").default
    app = express()
    app.use(json())
    app.use("/api/v1/auth", AuthRoutes)
  })

  beforeEach(() => {
    jest.clearAllMocks()
  })

  /**
   * Helper function to create a real signature for testing
   */
  const createRealSignature = async (walletAddress, message, privateKey) => {
    try {
      // Create the same typed data structure as in the API
      const typedDataStructure = {
        domain: {
          name: "MusicStrk Wallet Verification",
          chainId: process.env.NODE_ENV === "production"
            ? "0x534e5f4d41494e" // SN_MAIN
            : "0x534e5f5345504f4c4941", // SN_SEPOLIA
          version: "1.0.0",
          revision: "1",
        },
        message: {
          content: message,
        },
        primaryType: "VerificationMessage",
        types: {
          VerificationMessage: [
            {
              name: "content",
              type: "shortstring",
            },
          ],
          StarknetDomain: [
            {
              name: "name",
              type: "shortstring",
            },
            {
              name: "chainId",
              type: "shortstring",
            },
            {
              name: "version",
              type: "shortstring",
            },
          ],
        },
      }

      // Get the message hash
      const messageHash = typedData.getMessageHash(typedDataStructure, walletAddress)

      // Sign the message hash
      const keyPair = ec.starkCurve.getStarkKey(privateKey)
      const signature = ec.starkCurve.sign(messageHash, privateKey)

      return [signature.r.toString(), signature.s.toString()]
    } catch (error) {
      console.error("Error creating signature:", error)
      throw error
    }
  }

  test("should verify wallet successfully with real signature", async () => {
    const message = "Sign this message to authenticate with MusicStrk"
    
    // Generate a real signature
    const realSignature = await createRealSignature(
      TEST_ACCOUNT_ADDRESS,
      message,
      TEST_PRIVATE_KEY
    )

    const payload = {
      walletAddress: TEST_ACCOUNT_ADDRESS,
      message: message,
      signature: realSignature,
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(200)
    expect(response.body.error).toBe(false)
    expect(response.body.data.verified).toBe(true)
    expect(response.body.data.walletAddress).toBe(payload.walletAddress.toLowerCase())
    expect(response.body.data).toHaveProperty("timestamp")
    expect(response.body.data).toHaveProperty("processingTimeMs")
  })

  test("should reject signature from different private key", async () => {
    const message = "Sign this message to authenticate with MusicStrk"
    const wrongPrivateKey = "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
    
    // Generate signature with wrong private key
    const wrongSignature = await createRealSignature(
      TEST_ACCOUNT_ADDRESS,
      message,
      wrongPrivateKey
    )

    const payload = {
      walletAddress: TEST_ACCOUNT_ADDRESS,
      message: message,
      signature: wrongSignature,
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(401)
    expect(response.body.error).toBe(true)
    expect(response.body.code).toBe("SIGNATURE_MISMATCH")
    expect(response.body.details.verified).toBe(false)
  })

  test("should reject signature for different message", async () => {
    const originalMessage = "Sign this message to authenticate with MusicStrk"
    const differentMessage = "Different message content"
    
    // Sign the original message but send different message in request
    const signature = await createRealSignature(
      TEST_ACCOUNT_ADDRESS,
      originalMessage,
      TEST_PRIVATE_KEY
    )

    const payload = {
      walletAddress: TEST_ACCOUNT_ADDRESS,
      message: differentMessage, // Different message
      signature: signature,
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(401)
    expect(response.body.error).toBe(true)
    expect(response.body.code).toBe("SIGNATURE_MISMATCH")
  })

  test("should handle Argent wallet signature format", async () => {
    const message = "Sign this message to authenticate with MusicStrk"
    
    // Generate base signature
    const baseSignature = await createRealSignature(
      TEST_ACCOUNT_ADDRESS,
      message,
      TEST_PRIVATE_KEY
    )

    // Format as Argent signature: [signer_type, r, s]
    const argentSignature = ["0x0", baseSignature[0], baseSignature[1]]

    const payload = {
      walletAddress: TEST_ACCOUNT_ADDRESS,
      message: message,
      signature: argentSignature,
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(200)
    expect(response.body.data.verified).toBe(true)
  })

  test("should handle multi-sig Argent signature format", async () => {
    const message = "Sign this message to authenticate with MusicStrk"
    
    // Generate base signature
    const baseSignature = await createRealSignature(
      TEST_ACCOUNT_ADDRESS,
      message,
      TEST_PRIVATE_KEY
    )

    // Format as multi-sig Argent signature: [signer_type, signer_1, r, s, signer_2]
    const multiSigSignature = [
      "0x0", 
      "0x1111111111111111", 
      baseSignature[0], 
      baseSignature[1], 
      "0x2222222222222222"
    ]

    const payload = {
      walletAddress: TEST_ACCOUNT_ADDRESS,
      message: message,
      signature: multiSigSignature,
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(200)
    expect(response.body.data.verified).toBe(true)
  })

  test("should reject missing required fields", async () => {
    const payload = {
      walletAddress: TEST_ACCOUNT_ADDRESS,
      // Missing message and signature
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(400)
    expect(response.body.error).toBe(true)
    expect(response.body.code).toBe("MISSING_FIELDS")
  })

  test("should reject invalid wallet address format", async () => {
    const payload = {
      walletAddress: "invalid-address",
      message: "Sign this message to authenticate",
      signature: ["0x123", "0x456"],
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(400)
    expect(response.body.error).toBe(true)
    expect(response.body.code).toBe("INVALID_WALLET_FORMAT")
  })

  test("should reject invalid signature format", async () => {
    const payload = {
      walletAddress: TEST_ACCOUNT_ADDRESS,
      message: "Sign this message to authenticate",
      signature: "not-an-array",
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(400)
    expect(response.body.error).toBe(true)
    expect(response.body.code).toBe("INVALID_SIGNATURE_FORMAT")
  })

  test("should reject empty signature array", async () => {
    const payload = {
      walletAddress: TEST_ACCOUNT_ADDRESS,
      message: "Sign this message to authenticate",
      signature: [],
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(400)
    expect(response.body.error).toBe(true)
    expect(response.body.code).toBe("INVALID_SIGNATURE_FORMAT")
  })

  test("should reject unsupported signature array length", async () => {
    const payload = {
      walletAddress: TEST_ACCOUNT_ADDRESS,
      message: "Sign this message to authenticate",
      signature: ["0x123"], // Only 1 element - unsupported
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(500)
    expect(response.body.error).toBe(true)
    expect(response.body.code).toBe("INTERNAL_ERROR")
  })

  test("should handle malformed signature values", async () => {
    const payload = {
      walletAddress: TEST_ACCOUNT_ADDRESS,
      message: "Sign this message to authenticate",
      signature: ["invalid-hex", "also-invalid"],
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(400)
    expect(response.body.error).toBe(true)
    expect(response.body.code).toBe("INVALID_SIGNATURE")
  })

  // Integration test with environment variables
  test("should use correct chain ID based on environment", async () => {
    const originalEnv = process.env.NODE_ENV
    
    // Test with production environment
    process.env.NODE_ENV = "production"
    
    const message = "Sign this message to authenticate with MusicStrk"
    const signature = await createRealSignature(
      TEST_ACCOUNT_ADDRESS,
      message,
      TEST_PRIVATE_KEY
    )

    const payload = {
      walletAddress: TEST_ACCOUNT_ADDRESS,
      message: message,
      signature: signature,
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    // Restore original environment
    process.env.NODE_ENV = originalEnv

    // Should work with production chain ID
    expect(response.status).toBe(200)
    expect(response.body.data.verified).toBe(true)
  })
})

// Additional helper for creating test accounts if needed
const createTestAccount = () => {
  const privateKey = ec.starkCurve.utils.randomPrivateKey()
  const publicKey = ec.starkCurve.getStarkKey(privateKey)
  const address = hash.calculateContractAddressFromHash(
    publicKey,
    hash.getSelectorFromName("initialize"),
    [publicKey],
    0
  )
  
  return {
    privateKey: `0x${privateKey.toString(16)}`,
    publicKey: `0x${publicKey.toString(16)}`,
    address: `0x${address.toString(16)}`,
  }
}