import "dotenv/config"
import path from "path"
import mongoose from "mongoose"
import express, { urlencoded, json, type Request, type Response, type NextFunction } from "express"
import cors from "cors"
import cookieParser from "cookie-parser"
import { fileURLToPath } from "url"

import AuthRoutes from "./routes/v1/auth.js"
import UserRoutes from "./routes/v1/user.js"
import SubdomainRoutes from "./routes/v1/subdomain.js"
import { domainResolver } from "./middlewares/domainResolver.js"
import { logger } from "./utilities/utilities.js"

// Load environment variables
process.loadEnvFile(".env")
logger(`Environment: ${process.env.NODE_ENV}`)

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const testsDir = path.resolve(__dirname + "/../tests")
logger(`Tests directory: ${testsDir}`)

const app = express()

// setup necessary root-level middlewares & parsers
app.use(cors())
app.use(urlencoded({ extended: true }))
app.use(json())
app.use(cookieParser())

// Apply domain resolver middleware - fix the typing issue
app.use((req: Request, res: Response, next: NextFunction) => {
  domainResolver(req, res, next).catch(next)
})

const PORT = process.env.PORT || 8080
const MONGODB_URI = process.env.MONGODB_URI

if (!MONGODB_URI) {
  throw "Mongo URI not found in .env file"
}

if (!process.env.JWT_SECRET) {
  throw "JWT Secret not found in .env file"
}

if (!process.env.STARKNET_SEPOLIA_RPC_API_URL) {
  throw "Sepolia RPC URL not found in .env file"
}

if (!process.env.NEXT_APP_URL) {
  logger("NEXT_APP_URL not found in .env file, using default: http://localhost:3000")
}

// start test page if in dev mode
if (process.env.NODE_ENV === "development") {
  app.use(express.static(testsDir))
  app.get("/mode", (req, res) => {
    res.send("Debug mode")
  })
}

mongoose
  .connect(MONGODB_URI)
  .then(() => logger("MongoDB Connected"))
  .catch((err) => console.error("MongoDB Connection Error:", err))

// declare routes below
app.use("/api/v1/auth", AuthRoutes)
app.use("/api/v1/user", UserRoutes)
app.use("/api/v1/subdomain", SubdomainRoutes)

// Handle 404 for API routes
app.use("/api/*", (req, res) => {
  res.status(404).json({
    error: true,
    msg: "API endpoint not found",
  })
})

app.listen(PORT, () => {
  logger(`Server is running on port ${PORT}`)
  logger(`Main domain: http://musicstrk.fun:${PORT}`)
  logger(`Example subdomain: http://rebelwav.musicstrk.fun:${PORT}`)
})

