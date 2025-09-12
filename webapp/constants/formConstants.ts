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
    BASIC_INFO: 1,
    TIKTOK_AUTH: 2,
    SOCIAL_MEDIA: 3,
    WALLET_CONNECTION: 4,
    SUCCESS: 5,
  }
  
  export const STEP_CONFIGS = {
    [STEPS.BASIC_INFO]: {
      title: "Basic Information",
      description: "Tell us about yourself and your music",
      icon: "Mic",
      iconColor: "#00f5d4",
    },
    [STEPS.TIKTOK_AUTH]: {
      title: "TikTok Verification",
      description: "Verify your TikTok identity to prevent impersonation",
      icon: "Music",
      iconColor: "#ff6b6b",
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
  