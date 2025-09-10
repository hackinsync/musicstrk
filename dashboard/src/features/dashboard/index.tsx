import { useEffect, useState } from 'react'
import { useAuth } from '@/context/auth-context'
import { Button } from '@/components/ui/button'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { ThemeSwitch } from '@/components/theme-switch'
import { ConnectWalletButton } from './components/connect-wallet-button'
import { WalletModal } from './components/wallet-modal'
import { Check, Copy } from "lucide-react";
import { useAccount } from '@starknet-react/core'

function CopyAddressButton() {
  const { address } = useAccount()
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    const timeout = setTimeout(() => {
      if (copied) setCopied(false)
    }, 1000)
    return () => clearTimeout(timeout)
  }, [copied, setCopied])

  async function handleCopy() {
    setCopied(true)
    await navigator.clipboard.writeText(address!)
  }

  return (
    <button className='text-muted-foreground' onClick={handleCopy}>
      {copied ? (
        <Check className='size-4' strokeWidth={4} />
      ) : (
        <Copy className='size-4' strokeWidth={4} />
      )}
    </button>
  )
}

export default function Dashboard() {
  const [isWalletModalOpen, setIsWalletModalOpen] = useState(false)
  const { isAuthenticated, walletAddress, signOut } = useAuth()

  return (
    <>
      <Header>
        <div className='ml-auto flex items-center space-x-4'>
          {!isAuthenticated && (
            <ConnectWalletButton onClick={() => setIsWalletModalOpen(true)} />
          )}
          {isAuthenticated && walletAddress && (
            <>
              <div className='flex size-24 items-center justify-center'>
                <img
                  className='rounded-full'
                  src={`https://avatar.vercel.sh/${walletAddress}?size=150`}
                  alt='User gradient avatar'
                />
              </div>
              <h1
                className='flex items-center space-x-2'
              >
                <div className='text-sm font-medium'>
                  {walletAddress.slice(0, 6)}...{walletAddress.slice(-4)}
                </div>
                <CopyAddressButton />
              </h1>
              <Button className='w-full rounded-xl px-0' onClick={signOut}>
                Disconnect
              </Button>
            </>
          )}
          <ThemeSwitch />
          <ProfileDropdown />
        </div>
      </Header>

      <Main>{/* Main content */}</Main>

      <WalletModal
        isOpen={isWalletModalOpen}
        onClose={() => setIsWalletModalOpen(false)}
      />
    </>
  )
}
