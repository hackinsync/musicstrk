"use client"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import Image from "next/image"
import Link from "next/link"
import { useState, useEffect, useRef, useMemo } from "react"
import { createRoot } from "react-dom/client"
import GitHubButton from "react-github-btn"
import { FileText, Mail, Zap, Music, Headphones, Disc, Guitar, Mic, type LucideIcon } from "lucide-react"

import { useToast } from "@/hooks/use-toast"
import { FeatureCarousel } from "./FeatureComponent"
import Telegram from "./icons/Telegram"
import logo from "../app/assets/images/LogoText.png"

// Type definition for musical icons
type MusicalIconEntry = {
    Icon: LucideIcon
    color: string
}

export default function HeroSection() {
    const { toast } = useToast()
    const [email, setEmail] = useState("")
    const [loading, setLoading] = useState(false)
    const [glitchEffect, setGlitchEffect] = useState(false)
    const particlesRef = useRef<HTMLDivElement>(null)

    // Musical icons configuration with synthwave colors
    const musicalIcons: MusicalIconEntry[] = useMemo(() => [
        { Icon: Music, color: "text-[#00f5d4]" },
        { Icon: Headphones, color: "text-[#ff6b6b]" },
        { Icon: Disc, color: "text-[#00f5d4]" },
        { Icon: Guitar, color: "text-[#ff6b6b]" },
        { Icon: Mic, color: "text-[#00f5d4]" },
    ], [])

    // Enhanced email validation
    const validateEmail = (email: string): boolean => {
        const regex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
        return regex.test(email)
    }

    // Dynamic musical icon animation effect
        useEffect(() => {
            if (typeof window !== "undefined" && particlesRef.current) {
                const createMusicalIcon = () => {
                    const iconContainer = document.createElement("div")
                    const { Icon, color } = musicalIcons[Math.floor(Math.random() * musicalIcons.length)]

                    // Configure icon container with dynamic properties
                    iconContainer.classList.add(
                        "absolute",
                        "musical-icon",
                        "animate-musical-fall",
                        "opacity-50",
                        "hover:opacity-100",
                        "transition-opacity",
                        "pointer-events-none",
                        color,
                    )

                    // Randomize position and animation
                    iconContainer.style.left = `${Math.random() * 100}%`
                    iconContainer.style.fontSize = `${Math.random() * 2 + 1}rem`
                    iconContainer.style.animationDuration = `${Math.random() * 10 + 5}s`

                    // Create React wrapper for icon
                    const iconWrapper = document.createElement("div")
                    const root = createRoot(iconWrapper)
                    root.render(<Icon className="w-full h-full" />)

                    iconContainer.appendChild(iconWrapper)
                    particlesRef.current?.appendChild(iconContainer)

                    // Clean up after animation
                    setTimeout(() => {
                        iconContainer.remove()
                    }, 15000)
                }

                const iconInterval = setInterval(createMusicalIcon, 1000)
                return () => clearInterval(iconInterval)
            }
        }, [musicalIcons])

    // Handle waitlist form submission
    const handleSubmit = async () => {
        if (!validateEmail(email)) {
            setGlitchEffect(true)
            setTimeout(() => setGlitchEffect(false), 500)

            toast({
                variant: "destructive",
                title: "Invalid Transmission 🚨",
                description: "Email coordinates not recognized. Recalibrate and retry.",
            })
            return
        }

        setLoading(true)

        try {
            const response = await fetch("https://apis.musicstrk.fun/api/waitlist", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({ email }),
            })

            if (response.ok) {
                toast({
                    title: "Warp Sequence Initiated! 🚀",
                    description: "You've been encoded into the MusicStrk matrix.",
                })
                setEmail("")
            } else {
                throw new Error("Network response was not ok")
            }
        } catch (error) {
            console.error("Submission error:", error)
            toast({
                variant: "destructive",
                title: "Quantum Entanglement Disrupted",
                description: "Connection lost. Check your interdimensional signal.",
            })
        } finally {
            setLoading(false)
        }
    }

    return (
        <div
            className={`
      min-h-screen relative overflow-hidden text-white
      bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a]
      ${glitchEffect ? "animate-glitch" : ""}
    `}
        >
            {/* Background Effects */}
            <div className="absolute inset-0 bg-grid-neon opacity-20 pointer-events-none" />
            <div className="absolute inset-0 bg-neon-gradient opacity-30 pointer-events-none" />

            {/* Dynamic Musical Icons Background */}
            <div ref={particlesRef} className="absolute inset-0 pointer-events-none" />

            {/* Main Content */}
            <div className="relative container mx-auto px-4 py-20 z-10">
                <div className="text-center max-w-4xl mx-auto space-y-8">
                    {/* Header with Logo and Social Links */}
                    <header className="flex items-center justify-between w-full mb-8">
                        <div className="flex-1" />

                        <Image
                            src={logo || "/placeholder.svg"}
                            className="mx-auto transform hover:rotate-3 transition-transform duration-300"
                            alt="MusicStrk Logo"
                            width={250}
                            priority
                        />

                        <div className="flex-1 flex items-center justify-end space-x-4">
                            <Link
                                href="https://t.me/+2tMYFpOpU-1jYmY0"
                                className="text-[#00f5d4] hover:text-[#ff6b6b] hover:scale-125 transition-all duration-300"
                                target="_blank"
                                rel="noopener noreferrer"
                            >
                                <Telegram />
                            </Link>

                            <div className="relative group">
                                <GitHubButton
                                    href="https://github.com/hackinsync/musicstrk"
                                    data-color-scheme="no-preference: light; light: light; dark: dark;"
                                    data-icon="octicon-star"
                                    data-size="large"
                                    aria-label="Star MusicStrk on GitHub"
                                >
                                    Star Us
                                </GitHubButton>
                            </div>
                        </div>
                    </header>

                    {/* Hero Headline */}
                    <section className="space-y-6">
                        <h1 className="text-3xl md:text-4xl leading-tight">
                            <div className="leading-[1.3] space-y-2">
                                <span className="inline-block bg-[#00E5FF] text-black font-bold px-2 py-1 text-2xl md:text-3xl transition-all duration-300 hover:bg-[#00E5FF]/80 hover:shadow-[0_0_15px_rgba(0,229,255,0.5)]">
                                    MusicStrk
                                </span>{" "}
                                is the foundational music tech stack for the{" "}
                                <span className="inline-block bg-[#00E5FF] text-black font-bold px-2 py-1 text-2xl md:text-3xl transition-all duration-300 hover:bg-[#00E5FF]/80 hover:shadow-[0_0_15px_rgba(0,229,255,0.5)]">
                                    decentralized
                                </span>{" "}
                                artist, connecting talent with{" "}
                                <span className="inline-block bg-[#00E5FF] text-black font-bold px-2 py-1 text-2xl md:text-3xl transition-all duration-300 hover:bg-[#00E5FF]/80 hover:shadow-[0_0_15px_rgba(0,229,255,0.5)]">
                                    degens
                                </span>{" "}
                                ready to fund and own a stake, all on the artist&apos;s{" "}
                                <span className="inline-block bg-[#00E5FF] text-black font-bold px-2 py-1 text-2xl md:text-3xl transition-all duration-300 hover:bg-[#00E5FF]/80 hover:shadow-[0_0_15px_rgba(0,229,255,0.5)]">
                                    terms
                                </span>
                                .
                            </div>

                            <div className="mt-6 text-white">
                                <span className="text-2xl font-bold">Ready to </span>
                                <span className="text-[#00f5d4] text-2xl font-bold bg-gradient-to-r from-[#00f5d4] to-[#ff6b6b] bg-clip-text text-transparent animate-pulse">
                                    Revolutionize
                                </span>
                                <span className="text-2xl font-bold"> Music?</span>
                            </div>
                        </h1>
                    </section>

                    {/* Features Section */}
                    <section className="mt-16 space-y-6">
                        <FeatureCarousel />
                    </section>

                    {/* Email Subscription */}
                    <section className="mt-12 space-y-6">
                        <div className="flex items-center justify-center text-[#00f5d4] mb-4">
                            <Zap className="mr-2 w-5 h-5" />
                            <span className="text-lg font-medium">Get Early Access</span>
                        </div>

                        <div className="max-w-md mx-auto relative">
                            <div className="flex gap-2">
                                <Input
                                    type="email"
                                    placeholder="Enter your email coordinates..."
                                    value={email}
                                    onChange={(e) => setEmail(e.target.value)}
                                    onKeyPress={(e) => e.key === "Enter" && handleSubmit()}
                                    className="
                    bg-[#1a1a3a]/80 border-[#00f5d4]/50 text-white h-12
                    focus:ring-2 focus:ring-[#ff6b6b] focus:border-[#ff6b6b]
                    transition-all duration-300
                    placeholder-[#00f5d4]/50
                    backdrop-blur-sm
                  "
                                    disabled={loading}
                                />
                                <Button
                                    onClick={handleSubmit}
                                    disabled={loading || !email}
                                    className="
                    h-12 px-6
                    bg-gradient-to-r from-[#ff6b6b] to-[#ff8e8e]
                    hover:from-[#00f5d4] hover:to-[#00d4aa]
                    text-black font-semibold
                    transition-all duration-300
                    disabled:opacity-50 disabled:cursor-not-allowed
                    shadow-lg hover:shadow-xl
                  "
                                >
                                    {loading ? "Warping..." : "Join Waitlist"}
                                </Button>
                            </div>
                        </div>
                    </section>

                    {/* Footer Links */}
                    <footer className="mt-12 space-y-4">
                        <div className="flex flex-col md:flex-row items-center justify-center gap-6 md:gap-8">
                            <Link
                                href="https://github.com/hackinsync/musicstrk/"
                                className="
                  flex items-center text-[#00f5d4] hover:text-[#ff6b6b] 
                  text-sm transition-colors duration-300
                  hover:underline underline-offset-4
                "
                                target="_blank"
                                rel="noopener noreferrer"
                            >
                                <FileText className="w-4 h-4 mr-2" />
                                Decode Our Litepaper
                            </Link>

                            <div className="flex items-center">
                                <Mail className="w-4 h-4 mr-2 text-[#ff6b6b]" />
                                <a
                                    href="mailto:buidl@musicstrk.fun"
                                    className="
                    text-[#00f5d4] text-sm hover:text-[#ff6b6b] 
                    transition-colors duration-300
                    hover:underline underline-offset-4
                  "
                                >
                                    buidl@musicstrk.fun
                                </a>
                            </div>
                        </div>
                    </footer>
                </div>
            </div>
        </div>
    )
}
