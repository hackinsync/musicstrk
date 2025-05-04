import { useState } from "react"
import { useToast } from "@/hooks/use-toast"
import { STEPS } from "@/constants/formConstants"

export interface FormData {
  stageName: string
  genre: string
  tiktokAuditionUrl: string
  tiktokProfileUrl: string
  socialX: string
  walletAddress: string
}

export interface FormErrors {
  stageName: string
  genre: string
  tiktokAuditionUrl: string
  tiktokProfileUrl: string
  socialX: string
}

export function usePerformerForm() {
  const { toast } = useToast()
  const [currentStep, setCurrentStep] = useState(STEPS.BASIC_INFO)
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Form state
  const [formData, setFormData] = useState<FormData>({
    stageName: "",
    genre: "",
    tiktokAuditionUrl: "",
    tiktokProfileUrl: "",
    socialX: "",
    walletAddress: "",
  })

  // Form validation state
  const [errors, setErrors] = useState<FormErrors>({
    stageName: "",
    genre: "",
    tiktokAuditionUrl: "",
    tiktokProfileUrl: "",
    socialX: "",
  })

  // Handle input changes
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target
    setFormData((prev) => ({ ...prev, [name]: value }))

    // Clear error when user types
    if (errors[name as keyof typeof errors]) {
      setErrors((prev) => ({ ...prev, [name]: "" }))
    }
  }

  // Handle select changes
  const handleSelectChange = (name: string, value: string) => {
    setFormData((prev) => ({ ...prev, [name]: value }))

    // Clear error when user selects
    if (errors[name as keyof typeof errors]) {
      setErrors((prev) => ({ ...prev, [name]: "" }))
    }
  }

  // Validate current step
  const validateStep = () => {
    let isValid = true
    const newErrors = { ...errors }

    if (currentStep === STEPS.BASIC_INFO) {
      if (!formData.stageName.trim()) {
        newErrors.stageName = "Stage name is required"
        isValid = false
      }

      if (!formData.genre) {
        newErrors.genre = "Please select a genre"
        isValid = false
      }
    }

    if (currentStep === STEPS.SOCIAL_MEDIA) {
      if (!formData.tiktokAuditionUrl.trim()) {
        newErrors.tiktokAuditionUrl = "TikTok audition URL is required"
        isValid = false
      } else if (!formData.tiktokAuditionUrl.includes("tiktok.com")) {
        newErrors.tiktokAuditionUrl = "Please enter a valid TikTok URL"
        isValid = false
      }

      if (!formData.tiktokProfileUrl.trim()) {
        newErrors.tiktokProfileUrl = "TikTok profile URL is required"
        isValid = false
      } else if (!formData.tiktokProfileUrl.includes("tiktok.com/@")) {
        newErrors.tiktokProfileUrl = "Please enter a valid TikTok profile URL"
        isValid = false
      }

      if (formData.socialX && !formData.socialX.includes("twitter.com/") && !formData.socialX.includes("x.com/")) {
        newErrors.socialX = "Please enter a valid Twitter/X profile URL"
        isValid = false
      }
    }

    setErrors(newErrors)
    return isValid
  }

  // Handle next step
  const handleNext = () => {
    if (validateStep()) {
      setCurrentStep((prev) => prev + 1)
    } else {
      toast({
        variant: "destructive",
        title: "Validation Error",
        description: "Please check the form for errors",
      })
    }
  }

  // Handle previous step
  const handlePrevious = () => {
    setCurrentStep((prev) => prev - 1)
  }

  // Handle form submission
  const handleSubmit = async () => {
    if (currentStep !== STEPS.WALLET_CONNECTION) return

    setIsSubmitting(true)

    // Simulate API call
    await new Promise((resolve) => setTimeout(resolve, 2000))

    setIsSubmitting(false)
    setCurrentStep(STEPS.SUCCESS)

    toast({
      title: "Registration Complete! 🚀",
      description: "Your audition has been submitted successfully.",
    })
  }

  return {
    currentStep,
    setCurrentStep,
    formData,
    setFormData,
    errors,
    isSubmitting,
    handleChange,
    handleSelectChange,
    handleNext,
    handlePrevious,
    handleSubmit,
  }
}
