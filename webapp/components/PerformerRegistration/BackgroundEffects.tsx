import React from "react"
import { useMusicalIcons } from "@/hooks/useMusicalIcons"

export function BackgroundEffects() {
  useMusicalIcons("particles-container")

  return (
    <>
      {/* Synthwave Grid Background */}
      <div className="absolute inset-0 bg-grid-neon opacity-20 pointer-events-none" />

      {/* Dynamic Musical Icons Background */}
      <div className="absolute inset-0 pointer-events-none" id="particles-container"></div>

      {/* Neon Glow Effects */}
      <div className="absolute inset-0 bg-neon-gradient opacity-30 pointer-events-none" />
    </>
  )
}