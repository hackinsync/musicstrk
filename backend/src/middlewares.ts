
import { Request, Response, NextFunction } from 'express';
import { JWTPayload } from 'types';
import { verifyJWT } from 'utilities/jwt';




/**
 * Middleware to validate JWT token.
 * Adds user JWT payload to `req.body.user`.
 */
export function validateJWT(req: Request, res: Response, next: NextFunction) {
    console.log(`[Request URL]: ${req.url}`);

    const authHeader = req.headers.authorization;
    if (!authHeader) {
        res.status(401).json({
            error: true,
            msg: "Authorization header not provided"
        });
        return;
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
        res.status(401).json({
            error: true,
            msg: "Token not provided"
        });
        return;
    }

    try {
        const payload = verifyJWT(token) as JWTPayload;
        console.log("[AuthToken-Payload]: ", payload);
        req.body.user = payload.user;
        next();
        
    } catch (error) {
        console.error("[AuthToken Verify Error]: ", error);
        res.status(401).json({
            error: true,
            msg: "Invalid token"
        });
        return;
    }

};