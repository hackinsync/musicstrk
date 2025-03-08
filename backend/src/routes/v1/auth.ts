
import { Router, Request, Response } from 'express';
import { BigNumberish, ec, num, stark, typedData } from 'starknet';

import { AUTHENTICATION_SNIP12_MESSAGE, AUTHENTICATION_SNIP12_MESSAGE_HASH } from 'constants/index';
import { createUser } from 'models/UserModel';
import { Role } from 'types';
import { createJWT } from 'utilities/jwt';


const AuthRoutes = Router();


type ReqBody_Authenticate = {
  walletAddress: BigNumberish;
  walletPubKey: string;
  signature: string[];
  msgHash: string;
}
AuthRoutes.post('/authenticate', async (req: Request<{}, {}, ReqBody_Authenticate>, res: any) => {
  const { walletPubKey, walletAddress, signature, msgHash } = req.body;
  console.log("[/authenticate | ReqBody]: ", walletAddress, walletPubKey, msgHash);

  if (!walletPubKey || !walletAddress || !signature) {
    return res.status(401).json({
      error: true,
      msg: "Invalid payload received"
    });
  }

  try {

    console.log("[Signature]:", signature);
    
    const sig = [num.getHexString(signature[3]), num.getHexString(signature[4])];
    console.log("[Sig]:", sig,  num.getHexString(walletPubKey));



    const isSignatureValid = typedData.verifyMessage(typedData.getMessageHash(AUTHENTICATION_SNIP12_MESSAGE, walletAddress), sig, num.getHexString(walletPubKey));
    // const isSignatureValid = ec.starkCurve.verify(sig, msgHash, walletPubKey);
    // const isSignatureValid = ec.starkCurve.verify(signature, msgHash, walletPubKey);
    // console.log("[/authenticate | isValid]: ", isSignatureValid);

    if (isSignatureValid === false) {
      return res.status(401).json({
        error: true,
        msg: "Invalid Signature"
      });
    }

    throw new Error("Signature verification not implemented");

    // Stores wallet address in MongoDB (if not already stored).
    const user = await createUser({
      walletAddress: walletAddress.toString(),
      pubKey: walletPubKey,
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
        msg: "Wallet Authentication Successfull"
      });


  } catch (err) {
    const error = err as Error;
    console.error("[/authenticate | Error]: ", error);
    return res.status(500).json({
      error: true,
      msg: error.message
    });
  }
});

export default AuthRoutes;
