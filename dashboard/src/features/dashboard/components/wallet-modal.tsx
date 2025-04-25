import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { useState } from "react"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { AlertCircle } from "lucide-react"
import { useAuth } from "@/context/auth-context"
import { useConnect } from "@starknet-react/core"

interface WalletModalProps {
  isOpen: boolean
  onClose: () => void
}

export function WalletModal({ isOpen, onClose }: WalletModalProps) {
  const { signIn, error: authError } = useAuth()
  const { connectors } = useConnect()
  const [connecting, setConnecting] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const handleConnect = async (connectorId: string) => {
    try {
      setConnecting(connectorId)
      setError(null)
      await signIn(connectorId)
      onClose()
    } catch (err) {
      setError(authError || "Failed to connect wallet")
    } finally {
      setConnecting(null)
    }
  }

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
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

        <div className="grid gap-4 py-4">
          {connectors.map((connector) => (
            <Button
              key={connector.id}
              variant="outline"
              className="flex items-center justify-between p-6 hover:border-primary w-full"
              onClick={() => handleConnect(connector.id)}
              disabled={!connector.available() || !!connecting}
            >
              <div className="flex items-center space-x-3">
                <span className="text-lg font-medium">
                  {connector.id === "argentX" ? "Argent X" : "Braavos"}
                </span>
              </div>
              {connecting === connector.id && (
                <div className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
              )}
            </Button>
          ))}
        </div>
      </DialogContent>
    </Dialog>
  )
}