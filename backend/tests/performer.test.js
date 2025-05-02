const request = require("supertest")
const express = require("express")
const { json } = require("express")

// Mock middleware
jest.mock(
  "../src/middlewares",
  () => ({
    validateJWT: jest.fn((req, res, next) => {
      next()
    }),
  }),
  { virtual: true },
)

// Mock DB
jest.mock(
  "../src/models/PerformerModel",
  () => ({
    createPerformer: jest.fn((performer) => ({
      ...performer,
      _id: "mock_id",
      createdAt: new Date(),
    })),
    findPerformerByWalletAndAudition: jest.fn((walletAddress, auditionId) => {
      if (walletAddress === "0xDUPLICATE" && auditionId === "audition_abc") {
        return { walletAddress, auditionId }
      }
      return null
    }),
  }),
  { virtual: true },
)

const PerformerRoutes = require("../src/routes/v1/performer").default
const app = express()
app.use(json())

app.use("/api/v1/performers", PerformerRoutes)

describe("Performer Registration API", () => {
  test("should register a new performer successfully", async () => {
    const payload = {
      walletAddress: "0x123456",
      seasonId: "season_xyz",
      auditionId: "audition_abc",
      stageName: "John Dopey",
      bio: "Afrofusion from Vahalla",
      genre: "afrofusion",
      country: "Nigeria",
      tiktokAuditionUrl: "https://tiktok.com/audition",
      tiktokProfileUrl: "https://tiktok.com/@john",
      socialX: "https://twitter.com/john",
    }

    const response = await request(app)
      .post("/api/v1/performers")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(201)
    expect(response.body.error).toBe(false)
    expect(response.body.performer).toHaveProperty("_id")
    expect(response.body.performer.walletAddress).toBe(payload.walletAddress)
  })

  test("should reject duplicate registration", async () => {
    const payload = {
      walletAddress: "0xDUPLICATE",
      seasonId: "season_xyz",
      auditionId: "audition_abc",
      stageName: "John Dopey",
      bio: "Afrofusion from Vahalla",
      genre: "afrofusion",
      country: "Nigeria",
      tiktokAuditionUrl: "https://tiktok.com/audition",
      tiktokProfileUrl: "https://tiktok.com/@john",
      socialX: "https://twitter.com/john",
    }

    const response = await request(app)
      .post("/api/v1/performers")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(409)
    expect(response.body.error).toBe(true)
    expect(response.body.msg).toContain("already registered")
  })

  test("should reject invalid URLs", async () => {
    const payload = {
      walletAddress: "0x123456",
      seasonId: "season_xyz",
      auditionId: "audition_abc",
      stageName: "John Dopey",
      bio: "Afrofusion from Vahalla",
      genre: "afrofusion",
      country: "Nigeria",
      tiktokAuditionUrl: "invalid-url",
      tiktokProfileUrl: "https://tiktok.com/@john",
      socialX: "https://twitter.com/john",
    }

    const response = await request(app)
      .post("/api/v1/performers")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(400)
    expect(response.body.error).toBe(true)
    expect(response.body.msg).toContain("Invalid URL format")
  })

  test("should reject missing required fields", async () => {
    const payload = {
      walletAddress: "0x123456",
      stageName: "John Dopey",
    }

    const response = await request(app)
      .post("/api/v1/performers")
      .send(payload)
      .set("Accept", "application/json")

    expect(response.status).toBe(400)
    expect(response.body.error).toBe(true)
    expect(response.body.msg).toContain("Missing required fields")
  })
})
