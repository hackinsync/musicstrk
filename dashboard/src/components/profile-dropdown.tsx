import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { useTheme } from '@/context/theme-context'
import { Bell } from 'lucide-react'

export function ProfileDropdown() {
  const { theme } = useTheme()
  const themeColor = theme === 'dark' ? '#fff' : '#000'
  return (
    <DropdownMenu modal={false}>
      <DropdownMenuTrigger asChild>
        <Button variant='ghost' className='relative h-8 w-8 rounded-full'>
          <Bell size={24} color={themeColor} />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent className='w-56 p-2 min-h-24 ' align='end' forceMount>
        <DropdownMenuLabel>
          <p> Notification</p>
        </DropdownMenuLabel>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
