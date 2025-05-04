import React from "react"
import { Mic, Headphones, Wallet, Check, Music } from "lucide-react"
import { CardTitle, CardDescription } from "@/components/ui/card"
import { STEPS, STEP_CONFIGS } from "@/constants/formConstants"

interface FormHeaderProps {
  currentStep: number
}

export function FormHeader({ currentStep }: FormHeaderProps) {
  // Get icon for current step
  const getStepIcon = () => {
    switch (currentStep) {
      case STEPS.BASIC_INFO:
        return <Mic className="w-8 h-8 text-[#00f5d4]" />
      case STEPS.SOCIAL_MEDIA:
        return <Headphones className="w-8 h-8 text-[#ff6b6b]" />
      case STEPS.WALLET_CONNECTION:
        return <Wallet className="w-8 h-8 text-[#00f5d4]" />
      case STEPS.SUCCESS:
        return <Check className="w-8 h-8 text-[#00f5d4]" />
      default:
        return <Music className="w-8 h-8 text-[#00f5d4]" />
    }
  }

  const config = STEP_CONFIGS[currentStep]

  return (
    <div className="flex items-center space-x-4">
      {getStepIcon()}
      <div>
        <CardTitle className="text-xl text-white">{config.title}</CardTitle>
        <CardDescription className="text-white/70">{config.description}</CardDescription>
      </div>
    </div>
  )
}
