export const MUSIC_GENRES = [
    "Pop",
    "Hip-Hop/Rap",
    "R&B",
    "Electronic/Dance",
    "Rock",
    "Alternative",
    "Jazz",
    "Classical",
    "Country",
    "Folk",
    "Reggae",
    "Metal",
    "Blues",
    "Soul",
    "Funk",
    "Punk",
    "Indie",
    "Ambient",
    "Afrobeats",
    "Latin",
    "K-Pop",
    "J-Pop",
    "Other",
  ]
  
  export const STEPS = {
    BASIC_INFO: 0,
    SOCIAL_MEDIA: 1,
    WALLET_CONNECTION: 2,
    SUCCESS: 3,
  }
  
  export const STEP_CONFIGS = {
    [STEPS.BASIC_INFO]: {
      title: "Basic Information",
      description: "Tell us about yourself and your music",
      icon: "Mic",
      iconColor: "#00f5d4",
    },
    [STEPS.SOCIAL_MEDIA]: {
      title: "Social Media Links",
      description: "Share your social media presence",
      icon: "Headphones",
      iconColor: "#ff6b6b",
    },
    [STEPS.WALLET_CONNECTION]: {
      title: "Connect Your Wallet",
      description: "Connect your wallet to complete registration",
      icon: "Wallet",
      iconColor: "#00f5d4",
    },
    [STEPS.SUCCESS]: {
      title: "Registration Complete",
      description: "Your audition has been submitted successfully",
      icon: "Check",
      iconColor: "#00f5d4",
    },
  }
  