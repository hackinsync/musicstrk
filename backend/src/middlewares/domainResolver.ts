import type { Request, Response, NextFunction } from "express"
import { createProxyMiddleware, type Options } from "http-proxy-middleware"
import type { IncomingMessage, ServerResponse } from "http"
import path from "path"
import { fileURLToPath } from "url"
import { getSubdomainByName } from "../models/SubdomainModel"
import { logger } from "../utilities/utilities"

// List of reserved subdomains
const RESERVED_SUBDOMAINS = ["api", "admin", "www", "app", "dashboard"]

// Get the directory path
const __dirname = path.dirname(fileURLToPath(import.meta.url))
const rootDir = path.resolve(__dirname, "../../../")

// Next.js app URL - pointing to the artiste_sites directory
const NEXT_APP_URL = process.env.NEXT_APP_URL || `http://localhost:3000`
const NEXT_APP_PATH = path.join(rootDir, "artiste_sites")

logger(`Next.js app path: ${NEXT_APP_PATH}`)
logger(`Next.js app URL: ${NEXT_APP_URL}`)

// Extract subdomain from hostname
export const extractSubdomain = (hostname: string): string | null => {
  // For localhost testing
  if (hostname.includes("localhost")) {
    return null
  }

  // For actual domain
  const parts = hostname.split(".")
  if (parts.length > 2) {
    return parts[0].toLowerCase()
  }

  return null
}

// Check if subdomain is reserved
export const isReservedSubdomain = (subdomain: string): boolean => {
  return RESERVED_SUBDOMAINS.includes(subdomain.toLowerCase())
}

// Create proxy middleware for Next.js app
const nextJsProxy = createProxyMiddleware({
  target: NEXT_APP_URL,
  changeOrigin: true,
  ws: true,
  pathRewrite: {
    "^/api/v1": "/api/v1", // Keep API routes
    "^/": "/", // Rewrite all other paths
  },
  // Add custom headers to pass subdomain information to Next.js
  onProxyReq: (proxyReq: any, req: Request, res: Response) => {
    // Pass the subdomain as a header to the Next.js app
    if (req.headers["x-subdomain"]) {
      proxyReq.setHeader("x-subdomain", req.headers["x-subdomain"])
    }
  },
  // Use proper typing for the proxy options
  onError: (err: Error, req: IncomingMessage, res: ServerResponse) => {
    logger(`Proxy error: ${err.message}`)
    res.writeHead(500, {
      "Content-Type": "text/plain",
    })
    res.end("Proxy error")
  },
  logLevel: process.env.NODE_ENV === "development" ? "debug" : "error",
} as Options)

// Domain resolver middleware
export const domainResolver = async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Extract hostname and subdomain
    const hostname = req.hostname || req.headers.host?.split(":")[0] || ""
    const subdomain = extractSubdomain(hostname)

    logger(`Processing request for hostname: ${hostname}, subdomain: ${subdomain}`)

    // No subdomain, continue to main app
    if (!subdomain) {
      next()
      return
    }

    // Set subdomain in request for later use
    req.headers["x-subdomain"] = subdomain

    // Handle reserved subdomains
    if (isReservedSubdomain(subdomain)) {
      logger(`Reserved subdomain detected: ${subdomain}`)

      // Special handling for API subdomain
      if (subdomain === "api") {
        next()
        return
      }

      // Special handling for admin subdomain
      if (subdomain === "admin") {
        // You can implement admin-specific logic here
        next()
        return
      }

      // For other reserved subdomains, continue to main app
      next()
      return
    }

    // Check if subdomain exists in database
    const subdomainDoc = await getSubdomainByName(subdomain)

    if (!subdomainDoc) {
      logger(`Subdomain not found: ${subdomain}`)
      res.status(404).json({
        error: true,
        msg: "Subdomain not found",
      })
      return
    }

    logger(`Valid subdomain found: ${subdomain}`)

    // Proxy request to Next.js app
    nextJsProxy(req, res, next)
  } catch (error) {
    logger(`Error in domain resolver: ${(error as Error).message}`)
    next(error)
  }
}

