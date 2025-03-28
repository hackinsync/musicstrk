
import { Router, Request, Response, NextFunction } from "express";
import { validateJWT } from "middlewares";


const UserRoutes = Router();


UserRoutes.post("/me", validateJWT, (req: Request, res: Response) => {
    res.status(200).json({
        walletAddress: req.body.user.walletAddress,
    });
});

export default UserRoutes;