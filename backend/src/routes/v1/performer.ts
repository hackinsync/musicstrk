import { Router, Request, Response } from "express"
import { validateJWT } from "../../middlewares"
import { createPerformer, findPerformerByWalletAndAudition } from "../../models/PerformerModel"
import { PerformerRegistrationPayload } from "../../types"

const PerformerRoutes = Router()

PerformerRoutes.post("/", validateJWT, async (req: Request<{}, {}, PerformerRegistrationPayload>, res: Response): Promise<void> => {
    try {
      const {
        walletAddress,
        seasonId,
        auditionId,
        stageName,
        bio,
        genre,
        country,
        tiktokAuditionUrl,
        tiktokProfileUrl,
        socialX,
      } = req.body
      
      console.log("Processing registration request:", req.body);
  
      // Check all required fields
      if (
        !walletAddress ||
        !seasonId ||
        !auditionId ||
        !stageName ||
        !bio ||
        !genre ||
        !country ||
        !tiktokAuditionUrl ||
        !tiktokProfileUrl ||
        !socialX
      ) {
        console.log("Missing required fields:", { 
          hasWallet: !!walletAddress,
          hasSeason: !!seasonId,
          hasAudition: !!auditionId, 
          hasStageName: !!stageName,
          hasBio: !!bio,
          hasGenre: !!genre,
          hasCountry: !!country,
          hasTiktokAudition: !!tiktokAuditionUrl,
          hasTiktokProfile: !!tiktokProfileUrl,
          hasSocialX: !!socialX
        });
        
        res.status(400).json({ error: true, msg: "Missing required fields" })
        return
      }
  
      // Validate URL formats - improved regex that accepts special chars in paths
      const urlRegex = /^https?:\/\/[A-Za-z0-9.-]+\.[A-Za-z]{2,}(\/[A-Za-z0-9@_.-~:/?#[\]@!$&'()*+,;=]*)*\/?$/
      
      if (
        !urlRegex.test(tiktokAuditionUrl) || 
        !urlRegex.test(tiktokProfileUrl) || 
        !urlRegex.test(socialX)
      ) {
        console.log("Invalid URL format detected:", {
          tiktokAuditionUrl,
          tiktokProfileUrl,
          socialX
        });
        
        res.status(400).json({ error: true, msg: "Invalid URL format" })
        return
      }
  
      // Check for duplicate registration
      const existing = await findPerformerByWalletAndAudition(walletAddress, auditionId)
      if (existing) {
        console.log("Duplicate registration detected:", { walletAddress, auditionId });
        
        res.status(409).json({ error: true, msg: "Wallet already registered for this audition" })
        return
      }
  
      // Create new performer record
      const performer = await createPerformer({
        walletAddress,
        seasonId,
        auditionId,
        stageName,
        bio,
        genre,
        country,
        tiktokAuditionUrl,
        tiktokProfileUrl,
        socialX,
      })
      
      console.log("Performer registered successfully:", { id: performer._id });
  
      res.status(201).json({ error: false, msg: "Performer registered successfully", performer })
    } catch (error) {
      console.error("Registration failed:", { body: req.body, error })
      res.status(500).json({ error: true, msg: "Server error" })
    }
  })
  
export default PerformerRoutes