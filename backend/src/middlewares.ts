
import { Request, Response, NextFunction } from 'express';
import { verifyJWT } from 'utilities/jwt';



export const validateJWT = (req: Request, res: Response, next: NextFunction) => {
    console.log(`[Request URL]: ${req.url}`);

    const authHeader = req.headers.authorization;
    if (!authHeader) {
        return res.status(401).json({
            error: true,
            msg: "Authorization header not provided"
        });
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
        return res.status(401).json({
            error: true,
            msg: "Token not provided"
        });
    }

    try {
        const payload = verifyJWT(token);
        console.log("[Payload]: ", payload);
        next();
    } catch (error) {
        console.error("[Error]: ", error);
        return res.status(401).json({
            error: true,
            msg: "Invalid token"
        });
    }
    
    next();
};