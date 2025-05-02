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
  "../src/models/VoteModel",
  () => ({
    createVote: jest.fn((vote) => ({
      ...vote,
      _id: "mock_vote_id",
      createdAt: new Date(),
    })),
    findVoteByWalletPerformerAndAudition: jest.fn((walletAddress, performerId, auditionId) => {
      if (walletAddress === "0xDUPLICATE" && performerId === "performer_123" && auditionId === "audition_abc") {
        return { walletAddress, performerId, auditionId }
      }
      return null
    }),
  }),
  { virtual: true },
)

const VotesRoutes = require("../src/routes/v1/votes").default
const app = express()
app.use(json())

app.use("/api/v1/votes", VotesRoutes)

describe("Voting API", () => {
  test("should record a vote successfully", async () => {
    const payload = {
      auditionId: "audition_abc",
      voterTag: "OD Community",
      performerId: "performer_123",
      walletAddress: "0xVOTER",
      score: 8,
      personalityScale: {
        energy: 9,
        creativity: 7,
        originality: 6,
      },
    }

    const response = await request(app).post("/api/v1/votes").send(payload).set("Accept", "application/json")

    expect(response.status).toBe(201)
    expect(response.body.error).toBe(false)
    expect(response.body.vote).toHaveProperty("_id")
    expect(response.body.vote.walletAddress).toBe(payload.walletAddress)
    expect(response.body.vote.personalityScale.energy).toBe(payload.personalityScale.energy)
  })

  test("should reject duplicate votes", async () => {
    const payload = {
      auditionId: "audition_abc",
      voterTag: "OD Community",
      performerId: "performer_123",
      walletAddress: "0xDUPLICATE",
      score: 8,
      personalityScale: {
        energy: 9,
        creativity: 7,
        originality: 6,
      },
    }

    const response = await request(app).post("/api/v1/votes").send(payload).set("Accept", "application/json")

    expect(response.status).toBe(409)
    expect(response.body.error).toBe(true)
    expect(response.body.msg).toContain("already voted")
  })

  test("should reject invalid score values", async () => {
    const payload = {
      auditionId: "audition_abc",
      voterTag: "OD Community",
      performerId: "performer_123",
      walletAddress: "0xVOTER",
      score: 11, // Invalid score (> 10)
      personalityScale: {
        energy: 9,
        creativity: 7,
        originality: 6,
      },
    }

    const response = await request(app).post("/api/v1/votes").send(payload).set("Accept", "application/json")

    expect(response.status).toBe(400)
    expect(response.body.error).toBe(true)
    expect(response.body.msg).toContain("must be between 1 and 10")
  })

  test("should reject missing required fields", async () => {
    const payload = {
      auditionId: "audition_abc",
      walletAddress: "0xVOTER",
      // Missing performerId and personalityScale
    }

    const response = await request(app).post("/api/v1/votes").send(payload).set("Accept", "application/json")

    expect(response.status).toBe(400)
    expect(response.body.error).toBe(true)
    expect(response.body.msg).toContain("Missing or invalid required fields")
  })
})
