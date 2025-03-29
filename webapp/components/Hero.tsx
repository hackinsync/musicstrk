'use client'
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import Image from "next/image"
import logo from '../app/assets/images/LogoText-W.png'
import { FeatureCarousel } from "./FeatureComponent"
import Link from "next/link"
import { FileText, Mail, Zap, Music, Headphones, Disc, Guitar, Mic, LucideIcon } from "lucide-react"
import React, { useState, useEffect, useRef, } from "react"
import { useToast } from "@/hooks/use-toast"
import Telegram from "./icons/Telegram"
import Github from "./icons/Github"
import { createRoot } from "react-dom/client"

// Type definition for musical icon
type MusicalIconEntry = {
    Icon: LucideIcon;
    color: string;
}
export default function HeroSection() {
    const { toast } = useToast();
    const [email, setEmail] = useState("")
    const [loading, setLoading] = useState(false)
    const [glitchEffect, setGlitchEffect] = useState(false)
    const particlesRef = useRef<HTMLDivElement>(null)

    // Musical icons for background with colors
    const musicalIcons: MusicalIconEntry[] = [
        {
            Icon: Music,
            color: 'text-[#00f5d4]'
        },
        {
            Icon: Headphones,
            color: 'text-[#ff6b6b]'
        },
        {
            Icon: Disc,
            color: 'text-[#00f5d4]'
        },
        {
            Icon: Guitar,
            color: 'text-[#ff6b6b]'
        },
        {
            Icon: Mic,
            color: 'text-[#00f5d4]'
        }
    ]


    // Advanced email validation
    const validateEmail = (email: string) => {
        const regex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
        return regex.test(email)
    }

    // Musical icon generation effect
    useEffect(() => {
        // Ensure we're on the client side and ref is available
        if (typeof window !== 'undefined' && particlesRef.current) {
            // Create a function to generate musical icons
            const createMusicalIcon = () => {
                // Create a container for the icon
                const iconContainer = document.createElement('div')

                // Randomly select an icon
                const { Icon, color } = musicalIcons[
                    Math.floor(Math.random() * musicalIcons.length)
                ]

                // Set up the container with dynamic properties
                iconContainer.classList.add(
                    'absolute', 'musical-icon',
                    'animate-musical-fall',
                    'opacity-50',
                    'hover:opacity-100',
                    'transition-opacity',
                    color
                )

                // Randomize position, size, and animation
                iconContainer.style.left = `${Math.random() * 100}%`
                iconContainer.style.fontSize = `${Math.random() * 2 + 1}rem`
                iconContainer.style.animationDuration = `${Math.random() * 10 + 5}s`

                // Create a wrapper for the icon that allows React rendering
                const iconWrapper = document.createElement('div')

                // Use createRoot for modern React rendering
                const root = createRoot(iconWrapper)
                root.render(<Icon className="w-full h-full" />)

                // Append the icon wrapper to the container
                iconContainer.appendChild(iconWrapper)

                // Add to the particles container
                particlesRef.current?.appendChild(iconContainer)

                // Remove icon after animation
                setTimeout(() => {
                    iconContainer.remove()
                }, 15000)
            }

            // Generate icons at intervals
            const iconInterval = setInterval(createMusicalIcon, 1000)

            // Cleanup interval on unmount
            return () => clearInterval(iconInterval)
        }
    },)

    // Handle form submission
    const handleSubmit = async () => {
        if (!validateEmail(email)) {
            // Trigger glitch effect on error
            setGlitchEffect(true)
            setTimeout(() => setGlitchEffect(false), 500)

            toast({
                variant: "destructive",
                title: "Invalid Transmission 🚨",
                description: "Email coordinates not recognized. Recalibrate and retry."
            })
            return
        }

        setLoading(true)
        try {
            const response = await fetch("https://vm-71179753.truehost.dev/musicstrk-api/api/waitlist", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({ email }),
            })

            if (response.ok) {
                toast({
                    title: "Warp Sequence Initiated! 🚀",
                    description: "You've been encoded into the MusicStrk matrix."
                });
                setEmail("")
            } else {
                throw new Error("Network response was not ok")
            }
        } catch (error) {
            console.log(error)
            toast({
                variant: "destructive",
                title: "Quantum Entanglement Disrupted",
                description: "Connection lost. Check your interdimensional signal."
            })
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className={`min-h-screen relative bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a] 
            overflow-hidden text-white ${glitchEffect ? 'animate-glitch' : ''}`}>
            {/* Synthwave Grid Background */}
            <div className="absolute inset-0 bg-grid-neon opacity-20 pointer-events-none" />

            {/* Dynamic Musical Icons Background */}
            <div ref={particlesRef} className="absolute inset-0 pointer-events-none" />

            {/* Neon Glow Effects */}
            <div className="absolute inset-0 bg-neon-gradient opacity-30 pointer-events-none" />

            <div className="relative container mx-auto px-4 py-20 z-10">
                <div className="text-center max-w-3xl mx-auto space-y-8">
                    {/* Header with Social Links */}
                    <div className="flex items-center justify-between w-full mb-8">
                        <Image
                            src={logo}
                            className="mx-auto transform hover:rotate-3 transition-transform"
                            alt="MusicStrk Logo"
                            width={250}
                        />
                        <div className="flex items-center space-x-4 transform transition-transform">
                            <Link
                                href="https://t.me/+2tMYFpOpU-1jYmY0"
                                className="text-[#00f5d4] px-3 py-2 hover:text-[#ff6b6b] hover:scale-125 my-auto transition-colors"
                            >
                                <div className="mt-[20px]">

                                    <Telegram />
                                </div>
                            </Link>
                            <div className="mt-6 flex justify-center relative group">
                                {/* Button with ripple effect */}
                                <Link
                                    href="https://github.com/hackinsync/musicstrk"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="relative px-3 py-2 rounded-lg flex items-center hover:scale-110 space-x-2 
                                     text-black bg-[#ff6b6b] transition-all
                                    animate-pulse before:absolute before:inset-0 before:rounded-lg 
                                     before:bg-[#ff6b6b]/30 before:scale-125 before:opacity-50 
                                    before:animate-ripple"
                                >
                                    <Github />
                                </Link>

                                {/* Tooltip on hover */}
                                <div className="absolute top-10 scale-0 group-hover:scale-100 opacity-0 group-hover:opacity-100 bg-[#1a1a3a] text-white text-sm px-3 py-1 rounded-lg transition-all">
                                    ⭐ Support MusicStrk by starring our repo!
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Hero Headline with Synthwave Styling */}
                    <h1 className="text-4xl md:text-5xl text-transparent bg-clip-text 
                        bg-gradient-to-r from-[#00f5d4] to-[#ff6b6b] 
                        drop-shadow-neon animate-pulse">
                        We&apos;re BUIDLING a <del>Pump.Fun</del> for musical talents on Starknet
                        <span className="block mt-4 text-white">
                            Join The
                            <span className="text-[#00f5d4] ml-2 italic">Pack!</span>
                        </span>
                    </h1>

                    {/* Feature Section */}
                    <div className="mt-16">
                        <p className="text-[#00f5d4] mb-4 flex items-center justify-center">
                            <Zap className="mr-2" />
                            Sonic Features from the MusicStrk Universe
                        </p>
                        <FeatureCarousel />
                    </div>

                    {/* Email Subscription */}
                    <div className="mt-12 relative">
                        <p className="text-[#00f5d4] mb-4 flex items-center justify-center">
                            <Zap className="mr-2" />
                            Initiate Warp Sequence 🚀
                        </p>
                        <div className="max-w-md mx-auto relative">
                            <Input
                                type="email"
                                placeholder="Transmit Your Coordinates"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                className="bg-[#1a1a3a] border-[#00f5d4]/50 text-white h-14
                                    focus:ring-2 focus:ring-[#ff6b6b] 
                                    transition-all duration-300 
                                    placeholder-[#00f5d4]/50"
                            />
                            <Button
                                className="absolute right-1 my-auto top-0 bottom-0 h-11
                                    bg-[#ff6b6b] text-black 
                                    hover:bg-[#00f5d4] 
                                    transition-colors"
                                onClick={handleSubmit}
                                disabled={loading}
                            >
                                {loading ? "Warping..." : "Join Waitlist"}
                            </Button>
                        </div>
                    </div>

                    {/* Additional Links */}
                    <div className="mt-8 flex flex-col md:flex-row md:justify-center justify-center items-center md:items-center md:space-x-8">
                        <Link
                            href="https://github.com/hackinsync/musicstrk/"
                            className="flex items-center text-[#00f5d4] 
                                hover:text-[#ff6b6b] transition-colors"
                            target="_blank"
                            rel="noopener noreferrer"
                        >
                            <FileText className="w-5 h-5 mr-2" />
                            Decode Our Litepaper
                        </Link>
                        <div className="flex items-center">
                            <Mail className="w-5 h-5 mr-2 text-[#ff6b6b]" />
                            <a
                                href="mailto:buidl@musicstrk.fun"
                                className="text-[#00f5d4] hover:text-[#ff6b6b] transition-colors"
                            >
                                buidl@musicstrk.fun
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}