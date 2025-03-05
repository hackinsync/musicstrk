import { Router, Request } from 'express';


type ReqBody_Authenticate = {
  walletAddress: string;
  signedMessage: string;
  signature: string[];
}

const router = Router();

router.post('/authenticate', (req: Request<{}, {}, ReqBody_Authenticate>, res: any) => {
  const { walletAddress, signedMessage, signature } = req.body;
  if (!walletAddress || !signedMessage || !Array.isArray(signature) || signature.length != 5) {
    // TODO: "signature.length != 5" needs to be confirmed
    return res.status(401).json({
      error: true,
      msg: "Invalid payload received"
    });
  }
  return res.status(200).json({
    msg: "Wallet Authentication Successfull"
  });
});

export default router;
