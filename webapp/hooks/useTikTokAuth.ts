import { useState, useCallback } from 'react';

export interface TikTokAuthResult {
  accessToken: string;
  openId: string;
  userInfo: {
    openId: string;
    username: string;
    displayName: string;
    avatarUrl: string;
  };
}

export const useTikTokAuth = () => {
  const [isAuthenticating, setIsAuthenticating] = useState(false);
  const [authResult, setAuthResult] = useState<TikTokAuthResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const authenticateWithTikTok = useCallback(async (): Promise<TikTokAuthResult | null> => {
    setIsAuthenticating(true);
    setError(null);
    
    try {
      const clientId = process.env.NEXT_PUBLIC_TIKTOK_CLIENT_ID;
      const redirectUri = process.env.NEXT_PUBLIC_TIKTOK_REDIRECT_URI;
      
      if (!clientId || !redirectUri) {
        throw new Error('TikTok configuration missing');
      }

      const state = Math.random().toString(36).substring(7);
      const scope = 'user.info.basic';
      
      // Store state for verification
      localStorage.setItem('tiktok_auth_state', state);
      
      const authUrl = `https://www.tiktok.com/auth/authorize/?client_key=${clientId}&response_type=code&redirect_uri=${encodeURIComponent(redirectUri)}&state=${state}&scope=${scope}`;
      
      // Open popup for OAuth
      const popup = window.open(
        authUrl,
        'tiktok-auth',
        'width=500,height=600,scrollbars=yes,resizable=yes'
      );

      if (!popup) {
        throw new Error('Popup blocked. Please allow popups for this site.');
      }

      return new Promise((resolve, reject) => {
        const checkClosed = setInterval(() => {
          if (popup.closed) {
            clearInterval(checkClosed);
            const result = localStorage.getItem('tiktok_auth_result');
            const authError = localStorage.getItem('tiktok_auth_error');
            
            if (result) {
              const parsedResult = JSON.parse(result);
              localStorage.removeItem('tiktok_auth_result');
              localStorage.removeItem('tiktok_auth_state');
              setAuthResult(parsedResult);
              resolve(parsedResult);
            } else if (authError) {
              localStorage.removeItem('tiktok_auth_error');
              localStorage.removeItem('tiktok_auth_state');
              reject(new Error(authError));
            } else {
              reject(new Error('Authentication cancelled'));
            }
          }
        }, 1000);
      });
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Authentication failed';
      setError(errorMessage);
      console.error('TikTok authentication error:', error);
      return null;
    } finally {
      setIsAuthenticating(false);
    }
  }, []);

  const verifyTikTokProfile = useCallback(async (profileUrl: string): Promise<boolean> => {
    if (!authResult?.userInfo.username) return false;
    
    try {
      // Extract username from profile URL
      const usernameMatch = profileUrl.match(/tiktok\.com\/@([^\/\?]+)/);
      if (!usernameMatch) return false;
      
      const profileUsername = usernameMatch[1];
      return profileUsername === authResult.userInfo.username;
    } catch (error) {
      console.error('Profile verification error:', error);
      return false;
    }
  }, [authResult]);

  const reset = useCallback(() => {
    setAuthResult(null);
    setError(null);
    localStorage.removeItem('tiktok_auth_result');
    localStorage.removeItem('tiktok_auth_state');
  }, []);

  return {
    isAuthenticating,
    authResult,
    error,
    authenticateWithTikTok,
    verifyTikTokProfile,
    reset,
  };
};