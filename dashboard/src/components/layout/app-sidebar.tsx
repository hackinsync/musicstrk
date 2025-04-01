import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarRail,
} from '@/components/ui/sidebar'
import { NavGroup } from '@/components/layout/nav-group'
import { NavUser } from '@/components/layout/nav-user'
import logoDarkMode from "@/assets/LogoText-Dark.png"
import logoLightMode from "@/assets/LogoText-Light.png"
import { sidebarData } from './data/sidebar-data'
import { useTheme } from '@/context/theme-context'

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {

  const { theme } = useTheme()
  const logoImage = theme === "light" ? logoDarkMode : logoLightMode
  return (
    <Sidebar collapsible='icon' variant='floating' {...props}>
      <SidebarHeader>
        {/* <TeamSwitcher teams={sidebarData.teams} /> */}

        <img src={logoImage} alt='logo' className='w-24 my-4 object-contain' />
      </SidebarHeader>
      <SidebarContent>
        {sidebarData.navGroups.map((props) => (
          <NavGroup key={Math.random()} {...props} />
        ))}
      </SidebarContent>
      <SidebarFooter>
        <NavUser user={sidebarData.user} />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
