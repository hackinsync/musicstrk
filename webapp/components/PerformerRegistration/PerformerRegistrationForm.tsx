"use client"

import React from "react"
import { AnimatePresence } from "framer-motion"
import { Card, CardContent, CardFooter, CardHeader } from "@/components/ui/card"

// Import our custom components and hooks
import { usePerformerForm } from "@/hooks/usePerformerForm"
import { useWalletConnection } from "@/hooks/useWalletConnection"
import { BackgroundEffects } from "./BackgroundEffects"
import { AnimatedCard } from "./AnimatedCard"
import { StepIndicator } from "./StepIndicator"
import { FormHeader } from "./FormHeader"
import { FormStepContent } from "./FormSteps"
import { STEPS } from "@/constants/formConstants"

export default function PerformerRegistrationForm() {
  const {
    currentStep,
    formData,
    setFormData,
    errors,
    isSubmitting,
    handleChange,
    handleSelectChange,
    handleNext,
    handlePrevious,
    handleSubmit,
  } = usePerformerForm()

  const { isConnecting, connectWallet } = useWalletConnection((address) => {
    setFormData((prev) => ({ ...prev, walletAddress: address }))
    
    // Move to next step after wallet connection
    setTimeout(() => {
      handleNext()
    }, 1000)
  })

  return (
    <div className="min-h-screen w-full flex items-center justify-center p-4 relative bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a] overflow-hidden">
      <BackgroundEffects />

      <AnimatePresence mode="wait">
        <AnimatedCard step={currentStep}>
          <Card className="border-[#00f5d4]/20 bg-[#1a1a3a]/90 backdrop-blur-sm shadow-xl overflow-hidden">
            <CardHeader className="relative">
              <StepIndicator currentStep={currentStep} totalSteps={4} />
              <FormHeader currentStep={currentStep} />
            </CardHeader>

            <CardContent className="space-y-4">
              <FormStepContent
                currentStep={currentStep}
                formData={formData}
                errors={errors}
                handleChange={handleChange}
                handleSelectChange={handleSelectChange}
                handleNext={handleNext}
                handlePrevious={handlePrevious}
                handleSubmit={handleSubmit}
                isSubmitting={isSubmitting}
                isConnecting={isConnecting}
                connectWallet={connectWallet}
              />
            </CardContent>

            {currentStep !== STEPS.SUCCESS && (
              <CardFooter>
                {/* Footer buttons are rendered inside FormStepContent */}
              </CardFooter>
            )}
          </Card>
        </AnimatedCard>
      </AnimatePresence>
    </div>
  )
}