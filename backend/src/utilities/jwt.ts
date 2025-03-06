
// https://www.npmjs.com/package/fast-jwt?activeTab=readme

import { createSigner, createVerifier } from "fast-jwt";
import { JWTPayload } from "types";

const sign = createSigner({
    key: process.env.JWT_SECRET,
    iss: "MusicStrk",
    aud: "MusicStrk-API-v1",
    algorithm: "HS512",
    expiresIn: "24h",
});


const verify = createVerifier({
    key: process.env.JWT_SECRET,
    algorithms: ["HS512", "HS256"],
    allowedIss: ["MusicStrk"],
    allowedAud: ["MusicStrk-API-v1"],
    cache: 5000,    // 5000 items
});

export function verifyJWT(token: string) {
    return verify(token);
}


export function signJWT(payload: JWTPayload) {
    return sign(payload);
}