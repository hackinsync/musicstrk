const request = require("supertest")
const express = require("express")
const { json } = require("express")

// Mock starknet provider
jest.mock(
  "starknet",
  () => ({
    Provider: jest.fn().mockImplementation(() => ({
      getChainId: jest.fn().mockResolvedValue("0x534e5f5345504f4c4941"),
      verifyMessageInStarknet: jest.fn((typedData, signature, walletAddress) => {
        // Mock successful verification for specific test wallet
        if (walletAddress === "0x1234567890abcdef" && signature.r && signature.s) {
          return Promise.resolve(true)
        }
        // Mock failed verification for invalid signatures
        if (walletAddress === "0xinvalid") {
          return Promise.resolve(false)
        }
        // Mock contract not found error
        if (walletAddress === "0xnotdeployed") {
          throw new Error("Contract not found")
        }
        return Promise.resolve(false)
      }),
    })),
    constants: {
      StarknetChainId: {
        SN_SEPOLIA: "0x534e5f5345504f4c4941",
        SN_MAIN: "0x534e5f4d41494e",
      },
    },
    ec: {
      starkCurve: {
        Signature: jest.fn().mockImplementation((r, s) => ({
          r: BigInt(r),
          s: BigInt(s),
        })),
      },
    },
  }),
  { virtual: true },
)

const AuthRoutes = require("../src/routes/v1/auth").default
const app = express()
app.use(json())
app.use("/api/v1/auth", AuthRoutes)

describe("Wallet Verification API", () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  test("should verify wallet successfully with valid signature", async () => {
    const payload = {
      walletAddress: "0x1234567890abcdef",
      message: "Sign this message to authenticate",
      signature: ["0x123", "0x456"],
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(200)
    expect(response.body.error).toBe(false)
    expect(response.body.data.verified).toBe(true)
    expect(response.body.data.walletAddress).toBe(payload.walletAddress)
    expect(response.body.data).toHaveProperty("timestamp")
    expect(response.body.data).toHaveProperty("processingTimeMs")
  })

  test("should reject invalid signature", async () => {
    const payload = {
      walletAddress: "0xinvalid",
      message: "Sign this message to authenticate",
      signature: ["0x123", "0x456"],
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

  test("should reject missing required fields", async () => {
    const payload = {
      walletAddress: "0x1234567890abcdef",
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
      walletAddress: "0x1234567890abcdef",
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

  test("should handle contract not found error", async () => {
    const payload = {
      walletAddress: "0xnotdeployed",
      message: "Sign this message to authenticate",
      signature: ["0x123", "0x456"],
    }

    const response = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(400)
    expect(response.body.error).toBe(true)
    expect(response.body.code).toBe("CONTRACT_NOT_FOUND")
    expect(response.body.details).toHaveProperty("network")
  })

  test("should handle different signature formats", async () => {
    // Test Argent 3-element signature format
    const payload3 = {
      walletAddress: "0x1234567890abcdef",
      message: "Sign this message to authenticate",
      signature: ["0x0", "0x123", "0x456"], // [signer_type, r, s]
    }

    const response3 = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload3)
      .set("Accept", "application/json")

    expect(response3.status).toBe(200)
    expect(response3.body.data.verified).toBe(true)

    // Test multi-sig 5-element signature format
    const payload5 = {
      walletAddress: "0x1234567890abcdef",
      message: "Sign this message to authenticate",
      signature: ["0x0", "0x111", "0x123", "0x456", "0x222"], // [signer_type, signer_1, r, s, signer_2]
    }

    const response5 = await request(app)
      .post("/api/v1/auth/verify-wallet")
      .send(payload5)
      .set("Accept", "application/json")

    expect(response5.status).toBe(200)
    expect(response5.body.data.verified).toBe(true)
  })
})
