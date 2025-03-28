import { Router, type Request, type Response } from "express"
import { validateJWT } from "../../middlewares"
import { createSubdomain, getSubdomainByName, updateSubdomain, deleteSubdomain } from "../../models/SubdomainModel"
import { isReservedSubdomain } from "../../middlewares/domainResolver"
import { logger } from "../../utilities/utilities"

const SubdomainRoutes = Router()

// Get subdomain by name
SubdomainRoutes.get("/:name", validateJWT, async (req: Request, res: Response) => {
  try {
    const { name } = req.params
    const subdomain = await getSubdomainByName(name)

    if (!subdomain) {
      res.status(404).json({
        error: true,
        msg: "Subdomain not found",
      })
      return
    }

    res.status(200).json(subdomain)
  } catch (error) {
    logger(`Error getting subdomain: ${(error as Error).message}`)
    res.status(500).json({
      error: true,
      msg: "Server error",
    })
  }
})

// Create new subdomain
SubdomainRoutes.post("/", validateJWT, async (req: Request, res: Response) => {
  try {
    const { name } = req.body
    const userId = req.body.user._id

    if (!name) {
      res.status(400).json({
        error: true,
        msg: "Subdomain name is required",
      })
      return
    }

    // Check if subdomain is reserved
    if (isReservedSubdomain(name)) {
      res.status(400).json({
        error: true,
        msg: "This subdomain is reserved",
      })
      return
    }

    // Check if subdomain already exists
    const existingSubdomain = await getSubdomainByName(name)
    if (existingSubdomain) {
      res.status(409).json({
        error: true,
        msg: "Subdomain already exists",
      })
      return
    }

    // Create subdomain
    const subdomain = await createSubdomain({
      name,
      userId,
      isActive: true,
    })

    res.status(201).json(subdomain)
  } catch (error) {
    logger(`Error creating subdomain: ${(error as Error).message}`)
    res.status(500).json({
      error: true,
      msg: "Server error",
    })
  }
})

// Update subdomain
SubdomainRoutes.put("/:name", validateJWT, async (req: Request, res: Response) => {
  try {
    const { name } = req.params
    const { isActive } = req.body
    const userId = req.body.user._id

    // Check if subdomain exists
    const existingSubdomain = await getSubdomainByName(name)
    if (!existingSubdomain) {
      res.status(404).json({
        error: true,
        msg: "Subdomain not found",
      })
      return
    }

    // Check if user owns the subdomain
    if (existingSubdomain.userId.toString() !== userId.toString()) {
      res.status(403).json({
        error: true,
        msg: "You don't have permission to update this subdomain",
      })
      return
    }

    // Update subdomain
    const updatedSubdomain = await updateSubdomain(name, {
      isActive,
    })

    res.status(200).json(updatedSubdomain)
  } catch (error) {
    logger(`Error updating subdomain: ${(error as Error).message}`)
    res.status(500).json({
      error: true,
      msg: "Server error",
    })
  }
})

// Delete subdomain
SubdomainRoutes.delete("/:name", validateJWT, async (req: Request, res: Response) => {
  try {
    const { name } = req.params
    const userId = req.body.user._id

    // Check if subdomain exists
    const existingSubdomain = await getSubdomainByName(name)
    if (!existingSubdomain) {
      res.status(404).json({
        error: true,
        msg: "Subdomain not found",
      })
      return
    }

    // Check if user owns the subdomain
    if (existingSubdomain.userId.toString() !== userId.toString()) {
      res.status(403).json({
        error: true,
        msg: "You don't have permission to delete this subdomain",
      })
      return
    }

    // Delete subdomain (soft delete)
    await deleteSubdomain(name)

    res.status(200).json({
      error: false,
      msg: "Subdomain deleted successfully",
    })
  } catch (error) {
    logger(`Error deleting subdomain: ${(error as Error).message}`)
    res.status(500).json({
      error: true,
      msg: "Server error",
    })
  }
})

export default SubdomainRoutes

