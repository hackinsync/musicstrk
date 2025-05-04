import { useState } from "react"
import { useToast } from "@/hooks/use-toast"

export function useWalletConnection(onConnected: (address: string) => void) {
  const [isConnecting, setIsConnecting] = useState(false)
  const { toast } = useToast()

  const connectWallet = async () => {
    setIsConnecting(true)

    // Simulate wallet connection delay
    await new Promise((resolve) => setTimeout(resolve, 2000))

    // Mock wallet address
    const mockAddress = "0x" + Math.random().toString(16).slice(2, 12) + "..." + Math.random().toString(16).slice(2, 6)

    setIsConnecting(false)

    toast({
      title: "Wallet Connected",
      description: `Successfully connected to ${mockAddress}`,
    })

    // Call the callback with the new address
    onConnected(mockAddress)

    // Return the address for convenience
    return mockAddress
  }

  return {
    isConnecting,
    connectWallet,
  }
}
