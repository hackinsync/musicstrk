import React from "react";
import { Button } from "@/components/ui/button";
import { Music, CheckCircle, AlertCircle, ExternalLink } from "lucide-react";
import { useTikTokAuth } from "@/hooks/useTikTokAuth";
import type { TikTokAuthResult } from "@/hooks/useTikTokAuth";
import Image from "next/image";

interface TikTokAuthStepProps {
  onAuthSuccess: (authData: TikTokAuthResult) => void;
  onNext: () => void;
  // Removed unused isAuthenticated prop
}

export function TikTokAuthStep({ onAuthSuccess, onNext }: Omit<TikTokAuthStepProps, 'isAuthenticated'>) {
  const { isAuthenticating, authResult, error, authenticateWithTikTok, reset } = useTikTokAuth();

  const handleTikTokAuth = async () => {
    const result = await authenticateWithTikTok();
    if (result) {
      onAuthSuccess(result);
    }
  };

  return (
    <div className="space-y-6 py-4">
      <div className="text-center space-y-4">
        <div className="relative">
          <Music className="w-16 h-16 mx-auto text-[#ff6b6b] animate-pulse" />
          <div className="absolute -top-1 -right-1 w-6 h-6 bg-pink-500 rounded-full flex items-center justify-center">
            <span className="text-xs font-bold text-white">♪</span>
          </div>
        </div>
        
        <h3 className="text-xl font-bold text-white">Verify Your TikTok Identity</h3>
        <p className="text-white/70 max-w-md mx-auto">
          Connect your TikTok account to prevent impersonation and verify your audition video. 
          This ensures authenticity in our audition process.
        </p>

        {error && (
          <div className="bg-red-500/20 border border-red-500/50 rounded-md p-4 text-center">
            <AlertCircle className="w-5 h-5 text-red-400 mx-auto mb-2" />
            <p className="text-red-400 text-sm">{error}</p>
            <Button
              onClick={reset}
              variant="outline"
              size="sm"
              className="mt-2 text-red-400 border-red-400/50 hover:bg-red-500/10"
            >
              Try Again
            </Button>
          </div>
        )}

        {!authResult && !error && (
          <div className="space-y-4">
            <Button
              onClick={handleTikTokAuth}
              disabled={isAuthenticating}
              className="bg-[#ff6b6b] text-white hover:bg-[#ff6b6b]/80 transition-colors px-8 py-3 text-lg"
            >
              {isAuthenticating ? (
                <>
                  <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent mr-3" />
                  Authenticating with TikTok...
                </>
              ) : (
                <>
                  <Music className="w-5 h-5 mr-3" />
                  Connect TikTok Account
                </>
              )}
            </Button>
            
            <p className="text-white/50 text-xs">
              A secure popup will open to authenticate with TikTok
            </p>
          </div>
        )}

        {authResult && (
          <div className="space-y-4">
            <div className="bg-[#1a1a3a] border border-green-500/50 rounded-md p-6 text-center">
              <CheckCircle className="w-8 h-8 text-green-500 mx-auto mb-3" />
              <p className="text-green-500 font-semibold text-lg mb-2">TikTok Account Verified!</p>
              
              <div className="bg-[#0f0f1f] border border-[#00f5d4]/30 rounded-md p-4 mt-4">
                <div className="flex items-center justify-center space-x-4">
                  <Image
                    src={authResult.userInfo.avatarUrl} 
                    alt="TikTok Avatar" 
                    className="w-12 h-12 rounded-full border-2 border-[#00f5d4]/50"
                  />
                  <div className="text-center">
                    <p className="text-white font-semibold text-lg">{authResult.userInfo.displayName}</p>
                    <p className="text-[#00f5d4] text-sm font-medium">@{authResult.userInfo.username}</p>
                  </div>
                </div>
              </div>

              <div className="mt-4 p-3 bg-green-500/10 border border-green-500/30 rounded-md">
                <p className="text-green-400 text-sm">
                  ✓ Identity verified • ✓ Ready for registration
                </p>
              </div>
            </div>
            
            <Button
              onClick={onNext}
              className="bg-[#00f5d4] text-black hover:bg-[#00f5d4]/80 px-8 py-3 text-lg font-semibold"
            >
              Continue to Registration
              <ExternalLink className="w-4 h-4 ml-2" />
            </Button>
          </div>
        )}

        <div className="mt-6 p-4 bg-[#1a1a3a]/50 border border-white/10 rounded-md">
          <h4 className="text-white font-semibold mb-2 flex items-center">
            <AlertCircle className="w-4 h-4 mr-2 text-yellow-400" />
            Why TikTok Verification?
          </h4>
          <ul className="text-white/70 text-sm space-y-1 text-left">
            <li>• Prevents fake registrations and impersonation</li>
            <li>• Ensures audition videos belong to the registrant</li>
            <li>• Maintains fair competition for all artists</li>
            <li>• Protects the integrity of our platform</li>
          </ul>
        </div>
      </div>
    </div>
  );
}