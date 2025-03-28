
import { Router, Request } from 'express';
import { BigNumberish, constants, ec, Provider, } from 'starknet';

import { createUser } from 'models/UserModel';
import { AUTHENTICATION_SNIP12_MESSAGE } from 'constants/index';
import { createJWT } from 'utilities/jwt';
import { Role } from 'types';


const provider = new Provider({
  nodeUrl: process.env.NODE_ENV === "production" ? process.env.STARKNET_MAINNET_RPC_API_URL : process.env.STARKNET_SEPOLIA_RPC_API_URL,
  chainId: process.env.NODE_ENV === "production" ? constants.StarknetChainId.SN_MAIN : constants.StarknetChainId.SN_SEPOLIA
});


const AuthRoutes = Router();


type ReqBody_Authenticate = {
  walletAddress: BigNumberish;
  signature: string[];
}

AuthRoutes.post('/authenticate', async (req: Request<{}, {}, ReqBody_Authenticate>, res: any) => {
  const { walletAddress, signature } = req.body;
  // console.log("[/authenticate | ReqBody]: ", walletAddress, walletPubKey, msgHash);

  if (!walletAddress || !signature) {
    return res.status(401).json({
      error: true,
      msg: "Invalid payload received"
    });
  }

  try {
    // https://github.com/argentlabs/argent-contracts-starknet/blob/1352198956f36fb35fa544c4e46a3507a3ec20e3/docs/argent_account.md#Signatures
    // console.log("[/authenticate | Signature]:", signature);

    // https://docs.argent.xyz/aa-use-cases/verifying-signatures-and-cosigners#verifying-multi-signatures
    const normalizedSignature = new ec.starkCurve.Signature(BigInt(signature[3]), BigInt(signature[4]));
    console.log("[/authenticate | Normalized - Signature]:", normalizedSignature);

    const isSignatureValid = await provider.verifyMessageInStarknet(AUTHENTICATION_SNIP12_MESSAGE, normalizedSignature, walletAddress);
    console.log("[/authenticate | isValid]: ", isSignatureValid);

    if (isSignatureValid === false) {
      return res.status(401).json({
        error: true,
        msg: "Invalid Signature"
      });
    }

    // Stores wallet address in MongoDB (if not already stored).
    const user = await createUser({
      walletAddress: walletAddress.toString(),
      pubKey: walletAddress.toString(),
      email: "",
      name: "",
      role: Role.USER
    });
    const authToken = createJWT({ user });

    console.log("[/authenticate | JWT]: ", authToken);

    // We return a JWT token
    return res
      .status(200)
      .setHeader("Authorization", `Bearer ${authToken}`)
      // .cookie("AuthToken", authToken, { httpOnly: true, secure: true, sameSite: "strict" })
      .json({
        msg: "Wallet Authentication Successfull",
        token: authToken
      });


  } catch (err) {
    const error = err as Error;
    console.error("[/authenticate | Error]: ", error);

    if (error.message.toLowerCase().includes("contract not found", error.message.length - 30)) {
      return res.status(500).json({
        error: true,
        msg: "Contract not found (Not Deployed)"
      });
    }

    return res.status(500).json({
      error: true,
      msg: error.message
    });
  }

});

export default AuthRoutes;
