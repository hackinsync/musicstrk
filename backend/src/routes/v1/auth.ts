import { Router, Request, Response } from "express";
import { TypedData, BigNumberish, constants, ec, Provider } from "starknet";
import rateLimit from 'express-rate-limit';

import UserModel, { createUser, findUserByaddress } from "../models/UserModel";
import { AUTHENTICATION_SNIP12_MESSAGE } from "../constants/index";
import { createJWT } from "../utilities/jwt";
import { Role } from "../types";
import { verifyStarknetSignature } from '../utilities/verifySignature';
import { nonceManager } from '../utilities/nonceManager';

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

//Rate Limiter for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15*60*1000, //15 min
  max: 10, //10 request per ip-windowMs
  message: {success: false, message: 'Too many authentication attempts, please try again later'}
});

AuthRoutes.get('/nonce', authLimiter, (req: Request, res: Response) => {
  try {
    const { walletAddress } = req.query;
    
    //input validation
    if (!walletAddress || typeof walletAddress != 'string'){
      return res.status(401).json({ success: false, message: 'Valid wallet address is required'});
    }

    //checks wallet add and validates
    const isStarknetAddress = walletAddress.match(/^0x[a-fA-F0-9]{64}$/);

    if (!isEthereumAddress && !isStarknetAddress) {
      return res.status(400).json({ success: false, message: 'Invalid wallet address format' });
    }
    
let nonce: string;
    
    try {
      // Generate a dynamic nonce for this wallet address
      nonce = nonceManager.generateNonce(walletAddress);
    } catch (error) {
      console.error('Nonce generation error:', error);
      return res.status(500).json({ success: false, message: 'Error generating secure nonce' });
    }
    
    return res.status(200).json({ 
      success: true, 
      message: AUTHENTICATION_SNIP12_MESSAGE, 
      nonce,
      walletType: 'starknet'
    });
  } catch (error) {
    console.error('Nonce generation error:', error);
    return res.status(500).json({ success: false, message: 'Server error during nonce generation' });
  }
});

interface AuthenticateRequestBody {
  walletAddress: string;
  signature: any; //Can be string[] for different wallet formats
  nonce: string;
}

AuthRoutes.post(
  "/authenticate", "/verify-wallet",
  authLimiter, async (req: Request<{}, {}, ReqBody_Authenticate>, res: Response) => {
    const { walletAddress, message, signature, nonce } = req.body;
    // console.log("[/authenticate | ReqBody]: ", walletAddress, walletPubKey, msgHash);

    if (!walletAddress || !signature || !nonce) {
      return res.status(401).json({
        error: true,
        msg: "Invalid payload received",
      });
    }

    //Validate wallet address format based on type
    const isStarknetAddress = /^0x[a-fA-F0-9]{64}$/.test(walletAddress);
    
    if (!isStarknetAddress) {
      return res.status(401).json({ success: false, message: 'Invalid Starknet wallet address format' });
    }

    const isNonceValid = nonceManager.verifyNonce(walletAddress, nonce);

    //Verify the nonce is valid and hasn't expired
    if (!isNonceValid.verifyNonce(walletAddress, nonce)) {
      return res.status(401).json({ success: false, message: 'Invalid or expired nonce' });
    }
    
    let isVerified = false;
    
    try {
      // https://github.com/argentlabs/argent-contracts-starknet/blob/1352198956f36fb35fa544c4e46a3507a3ec20e3/docs/argent_account.md#Signatures
      // console.log("[/authenticate | Signature]:", signature);

      // https://docs.argent.xyz/aa-use-cases/verifying-signatures-and-cosigners#verifying-multi-signatures
      let rIndex, sIndex;
      if (sigArray.length === 3) {
        rIndex = 1;
        sIndex = 2;
      } else if (sigArray.length === 5) {
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

      //Prevents replay attacks
      nonceManager.invalidateNonce(walletAddress);


      let user = await findUserByaddress(walletAddress);
      //Stores wallet address in MongoDB (if not already stored).
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
            walletAddress,
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
  }
);

export default AuthRoutes;
