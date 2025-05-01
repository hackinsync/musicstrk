import React from "react"

interface StepIndicatorProps {
  currentStep: number
  totalSteps: number
}

export function StepIndicator({ currentStep, totalSteps }: StepIndicatorProps) {
  return (
    <div className="absolute top-0 right-0 p-4 flex space-x-2">
      {Array.from({ length: totalSteps }).map((_, i) => (
        <div
          key={i}
          className={`w-2 h-2 rounded-full ${
            i === currentStep
              ? "bg-[#00f5d4] animate-pulse"
              : i < currentStep
                ? "bg-[#ff6b6b]"
                : "bg-white/20"
          }`}
        />
      ))}
    </div>
  )
}
