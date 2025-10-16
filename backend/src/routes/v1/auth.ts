import { Router, Request } from "express";
import { BigNumberish, constants, ec, Provider } from "starknet";
import TikTokAuthRoutes from "./auth/tiktok";

import { createUser, findUserByaddress } from "models/UserModel";
import { AUTHENTICATION_SNIP12_MESSAGE } from "constants/index";
import { createJWT } from "utilities/jwt";
import { Role } from "types";

const provider = new Provider({
  nodeUrl:
    process.env.NODE_ENV === "production"
      ? process.env.STARKNET_MAINNET_RPC_API_URL
      : process.env.STARKNET_SEPOLIA_RPC_API_URL,
  chainId:
    process.env.NODE_ENV === "production"
      ? constants.StarknetChainId.SN_MAIN
      : constants.StarknetChainId.SN_SEPOLIA,
});

const AuthRoutes = Router();

type ReqBody_Authenticate = {
  walletAddress: BigNumberish;
  signature: string[];
};

AuthRoutes.use("/tiktok", TikTokAuthRoutes)

AuthRoutes.post(
  "/authenticate",
  async (req: Request<{}, {}, ReqBody_Authenticate>, res: any) => {
    const { walletAddress, signature } = req.body;
    // console.log("[/authenticate | ReqBody]: ", walletAddress, walletPubKey, msgHash);

    if (!walletAddress || !signature) {
      return res.status(401).json({
        error: true,
        msg: "Invalid payload received",
      });
    }

    try {
      // https://github.com/argentlabs/argent-contracts-starknet/blob/1352198956f36fb35fa544c4e46a3507a3ec20e3/docs/argent_account.md#Signatures
      // console.log("[/authenticate | Signature]:", signature);

      // https://docs.argent.xyz/aa-use-cases/verifying-signatures-and-cosigners#verifying-multi-signatures
      let rIndex, sIndex;
      if (signature.length === 3) {
        rIndex = 1;
        sIndex = 2;
      } else if (signature.length === 5) {
        rIndex = 3;
        sIndex = 4;
      } else {
        throw new Error("Invalid signature length: expected 3 or 5 elements");
      }

      const normalizedSignature = new ec.starkCurve.Signature(
        BigInt(signature[rIndex]),
        BigInt(signature[sIndex])
      );
      console.log(
        "[/authenticate | Normalized - Signature]:",
        normalizedSignature
      );

      const isSignatureValid = await provider.verifyMessageInStarknet(
        AUTHENTICATION_SNIP12_MESSAGE,
        normalizedSignature,
        walletAddress
      );
      console.log("[/authenticate | isValid]: ", isSignatureValid);

      if (isSignatureValid === false) {
        return res.status(401).json({
          error: true,
          msg: "Invalid Signature",
        });
      }

      let user = await findUserByaddress(walletAddress);
      // Stores wallet address in MongoDB (if not already stored).
      if (!user) {
        user = await createUser({
          walletAddress: walletAddress.toString(),
          pubKey: walletAddress.toString(),
          name: "",
          role: Role.USER,
        });
      }
      const authToken = createJWT({ user });

      console.log("[/authenticate | JWT]: ", authToken);

      // We return a JWT token
      return (
        res
          .status(200)
          .setHeader("Authorization", `Bearer ${authToken}`)
          // .cookie("AuthToken", authToken, { httpOnly: true, secure: true, sameSite: "strict" })
          .json({
            msg: "Wallet Authentication Successfull",
            token: authToken,
          })
      );
    } catch (err) {
      const error = err as Error;
      console.error("[/authenticate | Error]: ", error);

      if (
        error.message
          .toLowerCase()
          .includes("contract not found", error.message.length - 30)
      ) {
        return res.status(500).json({
          error: true,
          msg: "Contract not found (Not Deployed)",
        });
      }

      return res.status(500).json({
        error: true,
        msg: error.message,
      });
    }
})

type ReqBody_VerifyWallet = {
  walletAddress: string
  message: string
  signature: string[]
}

/**
 * POST /api/v1/auth/verify-wallet
 * Verify wallet ownership through message signature
 * Reusable for performer registration and voting authentication
 */
AuthRoutes.post("/verify-wallet", async (req: Request<{}, {}, ReqBody_VerifyWallet>, res: any) => {
  const startTime = Date.now()
  const { walletAddress, message, signature } = req.body

  console.log("[/verify-wallet | Request]:", {
    walletAddress,
    messageLength: message?.length,
    signatureLength: signature?.length,
    timestamp: new Date().toISOString(),
  })

  // Input validation
  if (!walletAddress || !message || !signature) {
    console.log("[/verify-wallet | Validation Error]: Missing required fields")
    return res.status(400).json({
      error: true,
      msg: "Missing required fields: walletAddress, message, and signature are required",
      code: "MISSING_FIELDS",
    })
  }

  // Validate wallet address format
  if (!walletAddress.startsWith("0x") || walletAddress.length < 10) {
    console.log("[/verify-wallet | Validation Error]: Invalid wallet address format")
    return res.status(400).json({
      error: true,
      msg: "Invalid wallet address format",
      code: "INVALID_WALLET_FORMAT",
    })
  }

  // Validate signature array
  if (!Array.isArray(signature) || signature.length === 0) {
    console.log("[/verify-wallet | Validation Error]: Invalid signature format")
    return res.status(400).json({
      error: true,
      msg: "Signature must be a non-empty array",
      code: "INVALID_SIGNATURE_FORMAT",
    })
  }

  try {
    // Normalize wallet address
    const normalizedWalletAddress = walletAddress.toLowerCase()

    console.log("[/verify-wallet | Processing]:", {
      normalizedWalletAddress,
      signatureElements: signature.length,
      chainId: await provider.getChainId(),
    })

    // Create typed data structure for the message
    const typedData = {
      domain: {
        name: "MusicStrk Wallet Verification",
        chainId:
          process.env.NODE_ENV === "production"
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

    // Handle different signature formats (Argent vs other wallets)
    let rIndex: number, sIndex: number

    if (signature.length === 2) {
      // Standard signature format [r, s]
      rIndex = 0
      sIndex = 1
    } else if (signature.length === 3) {
      // Argent signature format [signer_type, r, s]
      rIndex = 1
      sIndex = 2
    } else if (signature.length === 5) {
      // Multi-sig Argent format [signer_type, signer_1, r, s, signer_2]
      rIndex = 2
      sIndex = 3
    } else {
      throw new Error(`Unsupported signature format: expected 2, 3, or 5 elements, got ${signature.length}`)
    }

    // Create normalized signature object
    const normalizedSignature = new ec.starkCurve.Signature(BigInt(signature[rIndex]), BigInt(signature[sIndex]))

    console.log("[/verify-wallet | Signature Analysis]:", {
      originalLength: signature.length,
      rIndex,
      sIndex,
      r: signature[rIndex],
      s: signature[sIndex],
      normalizedR: normalizedSignature.r.toString(16),
      normalizedS: normalizedSignature.s.toString(16),
    })

    // Verify the signature against the typed data
    const isSignatureValid = await provider.verifyMessageInStarknet(
      typedData,
      normalizedSignature,
      normalizedWalletAddress,
    )

    const processingTime = Date.now() - startTime

    console.log("[/verify-wallet | Verification Result]:", {
      isValid: isSignatureValid,
      walletAddress: normalizedWalletAddress,
      processingTimeMs: processingTime,
      timestamp: new Date().toISOString(),
    })

    if (!isSignatureValid) {
      return res.status(401).json({
        error: true,
        msg: "Signature verification failed: signature does not match the provided wallet address",
        code: "SIGNATURE_MISMATCH",
        details: {
          walletAddress: normalizedWalletAddress,
          verified: false,
        },
      })
    }

    // Successful verification
    return res.status(200).json({
      error: false,
      msg: "Wallet verification successful",
      data: {
        walletAddress: normalizedWalletAddress,
        verified: true,
        timestamp: new Date().toISOString(),
        processingTimeMs: processingTime,
      },
    })
  } catch (error: any) {
    const processingTime = Date.now() - startTime

    console.error("[/verify-wallet | Error]:", {
      error: error.message,
      stack: error.stack,
      walletAddress,
      processingTimeMs: processingTime,
      timestamp: new Date().toISOString(),
    })

    // Handle specific error types
    if (error.message.toLowerCase().includes("contract not found")) {
      return res.status(400).json({
        error: true,
        msg: "Wallet contract not found or not deployed on this network",
        code: "CONTRACT_NOT_FOUND",
        details: {
          walletAddress,
          network: process.env.NODE_ENV === "production" ? "mainnet" : "sepolia",
        },
      })
    }

    if (error.message.toLowerCase().includes("invalid signature")) {
      return res.status(400).json({
        error: true,
        msg: "Invalid signature format or corrupted signature data",
        code: "INVALID_SIGNATURE",
        details: {
          signatureLength: signature?.length,
          walletAddress,
        },
      })
    }

    if (error.message.toLowerCase().includes("network") || error.message.toLowerCase().includes("rpc")) {
      return res.status(503).json({
        error: true,
        msg: "Network connectivity issue: unable to verify signature",
        code: "NETWORK_ERROR",
        details: {
          retryable: true,
        },
      })
    }

    // Generic server error
    return res.status(500).json({
      error: true,
      msg: "Internal server error during wallet verification",
      code: "INTERNAL_ERROR",
      details: {
        timestamp: new Date().toISOString(),
        processingTimeMs: processingTime,
      },
    })
  }
})

export default AuthRoutes

