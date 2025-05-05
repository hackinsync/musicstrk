import { Wallet } from 'lucide-react'
import { Button } from '@/components/ui/button'

interface ConnectWalletButtonProps {
  onClick: () => void
}

export function ConnectWalletButton({ onClick }: ConnectWalletButtonProps) {
  return (
    <Button
      onClick={onClick}
      className='flex items-center space-x-2'
      variant='outline'
    >
      <Wallet className='h-4 w-4' />
      <span>Connect Wallet</span>
    </Button>
  )
}
