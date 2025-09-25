import { Router, Request, Response } from "express";

const TikTokAuthRoutes = Router();

interface TikTokTokenResponse {
  access_token: string;
  open_id: string;
  scope: string;
  expires_in: number;
}

interface TikTokUserInfo {
  open_id: string;
  username: string;
  display_name: string;
  avatar_url: string;
}

// Exchange authorization code for access token
TikTokAuthRoutes.post("/token", async (req: Request, res: Response): Promise<void> => {
  try {
    const { code } = req.body;

    if (!code) {
      res.status(400).json({ success: false, error: "Authorization code is required" });
      return;
    }

    const clientId = process.env.TIKTOK_CLIENT_ID;
    const clientSecret = process.env.TIKTOK_CLIENT_SECRET;
    const redirectUri = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/auth/tiktok/callback`;

    if (!clientId || !clientSecret) {
      res.status(500).json({ success: false, error: "TikTok configuration missing" });
      return;
    }

    console.log("Exchanging TikTok authorization code for token...");

    // Exchange code for access token
    const tokenResponse = await fetch("https://open-api.tiktok.com/oauth/access_token/", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        client_key: clientId,
        client_secret: clientSecret,
        code: code,
        grant_type: "authorization_code",
        redirect_uri: redirectUri,
      }),
    });

    const tokenData = await tokenResponse.json() as any;

    if (!tokenResponse.ok || tokenData.error) {
      console.error("Token exchange failed:", tokenData);
      res.status(400).json({ 
        success: false, 
        error: tokenData.error_description || "Failed to exchange authorization code" 
      });
      return;
    }

    const { access_token, open_id } = tokenData.data as TikTokTokenResponse;

    console.log("Token exchange successful, fetching user info...");

    // Get user information
    const userResponse = await fetch(`https://open-api.tiktok.com/user/info/?access_token=${access_token}&open_id=${open_id}`);
    const userData = await userResponse.json() as any;

    if (!userResponse.ok || userData.error) {
      console.error("User info fetch failed:", userData);
      res.status(400).json({ 
        success: false, 
        error: "Failed to fetch user information" 
      });
      return;
    }

    const userInfo = userData.data.user;

    const authResult = {
      accessToken: access_token,
      openId: open_id,
      userInfo: {
        openId: open_id,
        username: userInfo.username,
        displayName: userInfo.display_name,
        avatarUrl: userInfo.avatar_url,
      },
    };

    console.log("TikTok authentication successful for user:", userInfo.username);

    res.json({ success: true, authResult });
  } catch (error) {
    console.error("TikTok token exchange error:", error);
    res.status(500).json({ 
      success: false, 
      error: "Internal server error during token exchange" 
    });
  }
});

export default TikTokAuthRoutes;