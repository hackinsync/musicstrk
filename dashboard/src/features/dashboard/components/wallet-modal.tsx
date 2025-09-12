import { useEffect, useState } from 'react';
import { useConnect } from '@starknet-react/core';
import { AlertCircle } from 'lucide-react';
import { useAuth } from '@/context/auth-context';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

interface WalletModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function WalletModal({ isOpen, onClose }: WalletModalProps) {
  const { signIn, error: authError, isAuthenticated } = useAuth();
  const { connectors } = useConnect();
  const [connecting, setConnecting] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Clear error when modal opens
  useEffect(() => {
    if (isOpen) {
      setError(null);
      setConnecting(null);
    }
  }, [isOpen]);

  // Close modal when authentication completes successfully
  useEffect(() => {
    if (isAuthenticated && connecting) {
      setConnecting(null);
      onClose();
    }
  }, [isAuthenticated, connecting, onClose]);

  // Update error state when auth error changes
  useEffect(() => {
    if (authError) {
      setError(authError);
      setConnecting(null);
    }
  }, [authError]);

  const handleConnect = async (connectorId: string) => {
    try {
      setConnecting(connectorId);
      setError(null);
      await signIn(connectorId);
    } catch (err) {
      const errorMessage =
        err instanceof Error && err.message === 'Wallet connection was cancelled'
          ? 'Connection cancelled. Please try again.'
          : err instanceof Error
            ? err.message
            : 'Failed to connect wallet';
      setError(errorMessage);
      setConnecting(null);
    }
  };

  // Prevent closing the modal while connecting
  const handleOpenChange = (open: boolean) => {
    if (!open && !connecting) {
      onClose();
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle className="text-center text-xl font-semibold">
            Connect Your Wallet
          </DialogTitle>
        </DialogHeader>

        {error && (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}

        {connectors.length === 0 && (
          <Alert variant="default">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              No wallets detected. Please install Argent X or Braavos.
            </AlertDescription>
          </Alert>
        )}

        <div className="grid gap-4 py-4">
          {connectors.map((connector) => (
            <Button
              key={connector.id}
              variant="outline"
              className="flex w-full items-center justify-between p-6 hover:border"
              onClick={() => handleConnect(connector.id)}
              disabled={!connector.available() || !!connecting}
            >
              <div className="flex items-center space-x-3">
              <div className="relative h-8 w-8">
                  <img
                    src={typeof connector.icon === 'string' ? connector.icon : connector.icon.light}
                    alt={connector.name}
                    className="rounded-full object-contain"
                  />
                </div>
                <span className="text-lg font-medium">
                  {connector.id === 'argentX' ? 'Argent X' : 'Braavos'}
                </span>
              </div>
              {connecting === connector.id && (
                <div className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
              )}
            </Button>
          ))}
        </div>

        {connecting && (
          <div className="mt-2 text-center text-sm text-gray-500">
            Please check your wallet and confirm the connection request...
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}