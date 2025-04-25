import { useState } from 'react'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { ThemeSwitch } from '@/components/theme-switch'
import { ConnectWalletButton } from './components/connect-wallet-button'
import { WalletModal } from './components/wallet-modal'
import { useAuth } from '@/context/auth-context'
import { Button } from '@/components/ui/button'

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
            <Button
              variant="ghost"
              className="flex items-center space-x-2"
              onClick={signOut}
            >
              <div className="text-sm font-medium">
                {walletAddress.slice(0, 6)}...{walletAddress.slice(-4)}
              </div>
            </Button>
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