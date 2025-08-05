import { useState } from "react"
import { useToast } from "@/hooks/use-toast"
import { STEPS } from "@/constants/formConstants"

export interface FormData {
  stageName: string
  genre: string
  email: string
  tiktokAuditionUrl: string
  tiktokProfileUrl: string
  socialX: string
  walletAddress: string
  tiktokAuthData?: any
}

export interface FormErrors {
  stageName: string
  genre: string
  email: string
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
    email: "",
    tiktokAuditionUrl: "",
    tiktokProfileUrl: "",
    socialX: "",
    walletAddress: "",
    tiktokAuthData: null,
  })

  // Form validation state
  const [errors, setErrors] = useState<FormErrors>({
    stageName: "",
    genre: "",
    email: "",
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

  // Handle TikTok auth success
  const handleTikTokAuthSuccess = (authData: any) => {
    setFormData((prev) => ({ 
      ...prev, 
      tiktokAuthData: authData,
      tiktokProfileUrl: `https://www.tiktok.com/@${authData.userInfo.username}`
    }))
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

      // Email validation
      if (!formData.email.trim()) {
        newErrors.email = "Email is required"
        isValid = false
      } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
        newErrors.email = "Please enter a valid email address"
        isValid = false
      }
    }

    if (currentStep === STEPS.TIKTOK_AUTH) {
      // TikTok auth validation
      if (!formData.tiktokAuthData) {
        toast({
          variant: "destructive",
          title: "TikTok Authentication Required",
          description: "Please authenticate with your TikTok account to continue",
        })
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

      // Verify TikTok profile matches authenticated account
      if (formData.tiktokAuthData && formData.tiktokProfileUrl) {
        const expectedProfileUrl = `https://www.tiktok.com/@${formData.tiktokAuthData.userInfo.username}`
        if (formData.tiktokProfileUrl !== expectedProfileUrl) {
          newErrors.tiktokProfileUrl = "Profile URL must match your authenticated TikTok account"
          isValid = false
        }
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

    try {
      // Prepare submission data
      const submissionData = {
        stageName: formData.stageName,
        genre: formData.genre,
        email: formData.email,
        tiktokAuditionUrl: formData.tiktokAuditionUrl,
        tiktokProfileUrl: formData.tiktokProfileUrl,
        socialX: formData.socialX,
        walletAddress: formData.walletAddress,
        tiktokAuthData: formData.tiktokAuthData,
      }

      // Get auth token (you'll need to implement this based on your auth system)
      const token = localStorage.getItem('auth_token') || 'dummy_token_for_testing'

      const response = await fetch('/api/performers/register', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify(submissionData),
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.message || 'Registration failed')
      }

      setCurrentStep(STEPS.SUCCESS)

      toast({
        title: "Registration Complete! 🚀",
        description: "Your audition has been submitted successfully.",
      })
    } catch (error) {
      console.error('Registration error:', error)
      toast({
        variant: "destructive",
        title: "Registration Failed",
        description: error instanceof Error ? error.message : "There was an error submitting your registration. Please try again.",
      })
    } finally {
      setIsSubmitting(false)
    }
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
    handleTikTokAuthSuccess,
    handleNext,
    handlePrevious,
    handleSubmit,
  }
}
