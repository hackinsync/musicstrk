"use client";

import { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';

function TikTokCallbackInner() {
  const searchParams = useSearchParams();
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');
  const [message, setMessage] = useState('Completing TikTok authentication...');

  useEffect(() => {
    const handleCallback = async () => {
      try {
        const code = searchParams?.get('code');
        const state = searchParams?.get('state');
        const error = searchParams?.get('error');
        const storedState = localStorage.getItem('tiktok_auth_state');

        if (error) {
          throw new Error(`TikTok authentication error: ${error}`);
        }

        if (!code || !state || state !== storedState) {
          throw new Error('Invalid authentication response');
        }

        setMessage('Exchanging code for access token...');

        // Exchange code for access token using your backend (FIXED URL)
        const response = await fetch(`${process.env.NEXT_PUBLIC_BACKEND_URL || 'http://localhost:8080'}/api/v1/auth/tiktok/token`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ code }),
        });

        const data = await response.json();
        
        if (!response.ok || !data.success) {
          throw new Error(data.error || 'Token exchange failed');
        }

        // Store result and close popup
        localStorage.setItem('tiktok_auth_result', JSON.stringify(data.authResult));
        localStorage.removeItem('tiktok_auth_state');
        
        setStatus('success');
        setMessage('Authentication successful! Closing window...');
        
        setTimeout(() => {
          window.close();
        }, 2000);

      } catch (error) {
        console.error('TikTok callback error:', error);
        const errorMessage = error instanceof Error ? error.message : 'Authentication failed';
        
        localStorage.setItem('tiktok_auth_error', errorMessage);
        localStorage.removeItem('tiktok_auth_state');
        
        setStatus('error');
        setMessage(errorMessage);
        
        setTimeout(() => {
          window.close();
        }, 3000);
      }
    };

    handleCallback();
  }, [searchParams]);

  return (
    <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-[#1a1a3a] to-[#0f0f1f]">
      <div className="text-center p-8 bg-[#1a1a3a]/50 rounded-lg border border-white/10 backdrop-blur-sm">
        {status === 'loading' && (
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-[#00f5d4] border-t-transparent mx-auto mb-4"></div>
        )}
        
        {status === 'success' && (
          <div className="w-8 h-8 mx-auto mb-4 text-green-500">
            <svg fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
            </svg>
          </div>
        )}
        
        {status === 'error' && (
          <div className="w-8 h-8 mx-auto mb-4 text-red-500">
            <svg fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
            </svg>
          </div>
        )}
        
        <p className={`text-lg ${status === 'error' ? 'text-red-400' : 'text-white'}`}>
          {message}
        </p>
      </div>
    </div>
  );
}

export default function TikTokCallback() {
  return (
    <Suspense>
      <TikTokCallbackInner />
    </Suspense>
  );
}