import React from "react"
import { Wallet, ArrowRight, ArrowLeft, Check, Loader2 } from "lucide-react"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { FormData, FormErrors } from "@/hooks/usePerformerForm"
import { STEPS, MUSIC_GENRES } from "@/constants/formConstants"

interface FormStepProps {
  currentStep: number
  formData: FormData
  errors: FormErrors
  handleChange: (e: React.ChangeEvent<HTMLInputElement>) => void
  handleSelectChange: (name: string, value: string) => void
  handleNext: () => void
  handlePrevious: () => void
  handleSubmit: () => void
  isSubmitting: boolean
  isConnecting: boolean
  connectWallet: () => Promise<string>
}

export function FormStepContent({ 
  currentStep, 
  formData, 
  errors, 
  handleChange, 
  handleSelectChange,
  handleNext,
  handlePrevious,
  handleSubmit,
  isSubmitting,
  isConnecting,
  connectWallet
}: FormStepProps) {
  const renderStepContent = () => {
    switch (currentStep) {
      case STEPS.BASIC_INFO:
        return <BasicInfoStep 
                 formData={formData} 
                 errors={errors} 
                 handleChange={handleChange} 
                 handleSelectChange={handleSelectChange} 
               />
      case STEPS.SOCIAL_MEDIA:
        return <SocialMediaStep 
                 formData={formData} 
                 errors={errors} 
                 handleChange={handleChange} 
               />
      case STEPS.WALLET_CONNECTION:
        return <WalletConnectionStep 
                 formData={formData} 
                 isConnecting={isConnecting} 
                 connectWallet={connectWallet} 
               />
      case STEPS.SUCCESS:
        return <SuccessStep />
      default:
        return null
    }
  }

  const renderFooterButtons = () => {
    if (currentStep === STEPS.SUCCESS) return null

    return (
      <div className="flex justify-between">
        {currentStep > STEPS.BASIC_INFO ? (
          <Button
            onClick={handlePrevious}
            variant="outline"
            className="border-[#00f5d4]/50 hover:bg-[#00f5d4]/20 transition-colors"
          >
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back
          </Button>
        ) : (
          <div></div>
        )}

        {currentStep < STEPS.WALLET_CONNECTION ? (
          <Button
            onClick={handleNext}
            className="bg-[#ff6b6b] text-black hover:bg-[#ff6b6b]/80 transition-colors"
          >
            Next
            <ArrowRight className="ml-2 h-4 w-4" />
          </Button>
        ) : currentStep === STEPS.WALLET_CONNECTION && formData.walletAddress ? (
          <Button
            onClick={handleSubmit}
            disabled={isSubmitting}
            className="bg-[#ff6b6b] text-black hover:bg-[#ff6b6b]/80 transition-colors"
          >
            {isSubmitting ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Submitting...
              </>
            ) : (
              <>
                Submit
                <ArrowRight className="ml-2 h-4 w-4" />
              </>
            )}
          </Button>
        ) : (
          <div></div>
        )}
      </div>
    )
  }

  return (
    <>
      <div className="space-y-4">
        {renderStepContent()}
      </div>
      {renderFooterButtons()}
    </>
  )
}

function BasicInfoStep({ 
  formData, 
  errors, 
  handleChange, 
  handleSelectChange 
}: Pick<FormStepProps, 'formData' | 'errors' | 'handleChange' | 'handleSelectChange'>) {
  return (
    <>
      <div className="space-y-2">
        <Label htmlFor="stageName" className="text-[#00f5d4] font-semibold">
          Stage Name
        </Label>
        <Input
          id="stageName"
          name="stageName"
          value={formData.stageName}
          onChange={handleChange}
          placeholder="Your artistic identity"
          className={`bg-[#1a1a3a] border-[#00f5d4]/50 text-white focus:ring-2 focus:ring-[#ff6b6b] transition-all duration-300 ${
            errors.stageName ? "border-red-500" : ""
          }`}
        />
        {errors.stageName && <p className="text-red-500 text-xs mt-1">{errors.stageName}</p>}
      </div>

      <div className="space-y-2">
        <Label htmlFor="genre" className="text-[#00f5d4] font-semibold">
          Music Genre
        </Label>
        <Select value={formData.genre} onValueChange={(value) => handleSelectChange("genre", value)}>
          <SelectTrigger
            id="genre"
            className={`bg-[#1a1a3a] border-[#00f5d4]/50 text-white focus:ring-2 focus:ring-[#ff6b6b] transition-all duration-300 ${
              errors.genre ? "border-red-500" : ""
            }`}
          >
            <SelectValue placeholder="Select your primary genre" />
          </SelectTrigger>
          <SelectContent className="bg-[#1a1a3a] border-[#00f5d4]/50 text-white max-h-80">
            {MUSIC_GENRES.map((genre) => (
              <SelectItem key={genre} value={genre} className="focus:bg-[#00f5d4]/20 focus:text-white">
                {genre}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        {errors.genre && <p className="text-red-500 text-xs mt-1">{errors.genre}</p>}
      </div>
    </>
  )
}

function SocialMediaStep({ 
  formData, 
  errors, 
  handleChange 
}: Pick<FormStepProps, 'formData' | 'errors' | 'handleChange'>) {
  return (
    <>
      <div className="space-y-2">
        <Label htmlFor="tiktokAuditionUrl" className="text-[#00f5d4] font-semibold">
          TikTok Audition URL
        </Label>
        <Input
          id="tiktokAuditionUrl"
          name="tiktokAuditionUrl"
          value={formData.tiktokAuditionUrl}
          onChange={handleChange}
          placeholder="https://www.tiktok.com/@username/video/1234567890"
          className={`bg-[#1a1a3a] border-[#00f5d4]/50 text-white focus:ring-2 focus:ring-[#ff6b6b] transition-all duration-300 ${
            errors.tiktokAuditionUrl ? "border-red-500" : ""
          }`}
        />
        {errors.tiktokAuditionUrl && (
          <p className="text-red-500 text-xs mt-1">{errors.tiktokAuditionUrl}</p>
        )}
        <p className="text-xs text-white/50">Link to your TikTok video audition</p>
      </div>

      <div className="space-y-2">
        <Label htmlFor="tiktokProfileUrl" className="text-[#00f5d4] font-semibold">
          TikTok Profile URL
        </Label>
        <Input
          id="tiktokProfileUrl"
          name="tiktokProfileUrl"
          value={formData.tiktokProfileUrl}
          onChange={handleChange}
          placeholder="https://www.tiktok.com/@username"
          className={`bg-[#1a1a3a] border-[#00f5d4]/50 text-white focus:ring-2 focus:ring-[#ff6b6b] transition-all duration-300 ${
            errors.tiktokProfileUrl ? "border-red-500" : ""
          }`}
        />
        {errors.tiktokProfileUrl && <p className="text-red-500 text-xs mt-1">{errors.tiktokProfileUrl}</p>}
      </div>

      <div className="space-y-2">
        <Label htmlFor="socialX" className="text-[#00f5d4] font-semibold">
          Twitter/X Profile URL (Optional)
        </Label>
        <Input
          id="socialX"
          name="socialX"
          value={formData.socialX}
          onChange={handleChange}
          placeholder="https://twitter.com/username or https://x.com/username"
          className={`bg-[#1a1a3a] border-[#00f5d4]/50 text-white focus:ring-2 focus:ring-[#ff6b6b] transition-all duration-300 ${
            errors.socialX ? "border-red-500" : ""
          }`}
        />
        {errors.socialX && <p className="text-red-500 text-xs mt-1">{errors.socialX}</p>}
      </div>
    </>
  )
}

function WalletConnectionStep({ 
  formData, 
  isConnecting, 
  connectWallet 
}: Pick<FormStepProps, 'formData' | 'isConnecting' | 'connectWallet'>) {
  return (
    <div className="space-y-6 py-4">
      <div className="text-center space-y-4">
        <Wallet className="w-16 h-16 mx-auto text-[#00f5d4] animate-pulse" />
        <p className="text-white">
          Connect your wallet to verify your identity and complete your registration
        </p>

        {formData.walletAddress ? (
          <div className="bg-[#1a1a3a] border border-[#00f5d4]/50 rounded-md p-4 text-center">
            <p className="text-white/70 text-sm">Connected Wallet</p>
            <p className="text-[#00f5d4] font-mono">{formData.walletAddress}</p>
          </div>
        ) : (
          <Button
            onClick={connectWallet}
            disabled={isConnecting}
            className="bg-[#00f5d4] text-black hover:bg-[#00f5d4]/80 transition-colors w-full"
          >
            {isConnecting ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Connecting...
              </>
            ) : (
              "Connect Wallet"
            )}
          </Button>
        )}
      </div>
    </div>
  )
}

function SuccessStep() {
  return (
    <div className="text-center space-y-6 py-8">
      <div className="relative">
        <div className="absolute inset-0 rounded-full bg-[#00f5d4]/20 animate-ping"></div>
        <div className="relative bg-[#00f5d4]/30 p-4 rounded-full inline-block">
          <Check className="w-12 h-12 text-[#00f5d4]" />
        </div>
      </div>

      <div className="space-y-2">
        <h3 className="text-xl font-bold text-white">Welcome to MusicStrk!</h3>
        <p className="text-white/70">
          Your audition has been submitted successfully. We&apos;ll review your application and get back to you
          soon.
        </p>
      </div>

      <Button
        onClick={() => (window.location.href = "/")}
        className="bg-[#ff6b6b] text-black hover:bg-[#ff6b6b]/80 transition-colors"
      >
        Return to Home
      </Button>
    </div>
  )
}
