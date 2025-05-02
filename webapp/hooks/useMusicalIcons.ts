import { useEffect } from "react"

export function useMusicalIcons(containerId: string) {
  useEffect(() => {
    // Create musical icons animation
    if (typeof window !== "undefined") {
      const container = document.getElementById(containerId)
      if (!container) return

      // Musical icons for background with colors
      const musicalIcons = [
        { icon: "♪", color: "#00f5d4" },
        { icon: "♫", color: "#ff6b6b" },
        { icon: "♩", color: "#00f5d4" },
        { icon: "♬", color: "#ff6b6b" },
        { icon: "🎵", color: "#00f5d4" },
      ]

      const createMusicalIcon = () => {
        const iconContainer = document.createElement("div")
        const randomIcon = musicalIcons[Math.floor(Math.random() * musicalIcons.length)]

        iconContainer.textContent = randomIcon.icon
        iconContainer.style.position = "absolute"
        iconContainer.style.left = `${Math.random() * 100}%`
        iconContainer.style.color = randomIcon.color
        iconContainer.style.fontSize = `${Math.random() * 2 + 1}rem`
        iconContainer.style.opacity = "0.5"
        iconContainer.style.pointerEvents = "none"

        // Animation
        iconContainer.style.animation = `musical-fall ${Math.random() * 10 + 5}s linear forwards`

        container.appendChild(iconContainer)

        // Remove after animation completes
        setTimeout(() => {
          iconContainer.remove()
        }, 15000)
      }

      // Generate icons at intervals
      const iconInterval = setInterval(createMusicalIcon, 1000)

      // Cleanup
      return () => clearInterval(iconInterval)
    }
  }, [containerId])
}
