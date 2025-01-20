/* eslint-disable @typescript-eslint/no-unused-vars */
'use client'
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import Image from "next/image"
import logo from '../assets/images/LogoText-W.png'
import { FeatureCarousel } from "./FeatureComponent"
import Link from "next/link"
import { FileText, Mail } from "lucide-react"
import { SocialIcon } from "react-social-icons"
import { useState } from "react"
import { useToast } from "@/hooks/use-toast"


export default function Hero() {
    const { toast } = useToast();
    const [email, setEmail] = useState("") // State for email input
    const [loading, setLoading] = useState(false) // State for button loading

    // Function to validate email
    const validateEmail = (email: string) => {
        const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        return regex.test(email)
    }

    // Function to handle form submission
    const handleSubmit = async () => {
        if (!validateEmail(email)) {
            toast({
            variant: "destructive",
            title: "Invalid email address. Please try again."
            })
            return
        }

        setLoading(true)
        try {
            const response = await fetch("http://156.232.88.143:5000/api/waitlist", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({ email }),
            })

            if (response.ok) {
                toast({
                    title: "You've been added to the waitlist! 🚀"
                });
                setEmail("") // Clear input after successful submission
            } else {
                toast({
                    variant: "destructive",
                    title: "Something went wrong. Please try again later."
                })
            }
        } catch (error) {
            toast({
                variant: "destructive",
                title: "Failed to connect. Check your network and try again."
            })
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className="min-h-screen rethink-400 relative bg-black overflow-hidden">
            {/* Particle effect background */}
            <div className="absolute aurora inset-0 opacity-50" />

            <div className="relative container mx-auto px-4 py-20">
                <div className="text-center max-w-3xl mx-auto space-y-8">
                    {/* Logo */}
                    <div className="flex justify-between w-full items-center mb-8">
                        <Image src={logo} className="mx-auto" alt="Logo" width={283} />
                        <div className="flex space-x-4">
                                <SocialIcon url="https://t.me/jedshock" />
                                <SocialIcon url="https://github.com/hackinsync/musicstrk" />
                        </div>
                    </div>

                    {/* Hero Text */}
                    <h1 className="text-4xl md:text-5xl rowdies-bold text-white">
                        We&apos;re BUIDLING a <del>Pump.Fun</del> for musical talents on Starknet
                        <span className="block">
                            Joining The Pack{' '}
                            <span className="baskervville-regular-italic text-blue-500">Waitlist!</span>
                        </span>
                    </h1>

                    {/* Feature Cards */}
                    <div className="mt-16">
                        <p className="text-gray-400 mb-4">Some features to expect from MusicStrk🐺</p>
                        <FeatureCarousel />
                    </div>

                    {/* Email Form */}
                    <div className="mt-12">
                        <p className="text-gray-400 mb-4">Get notified when we ship 🚀</p>
                        <div className="flex gap-4 max-w-md mx-auto">
                            <Input
                                type="email"
                                placeholder="Enter your Email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                className="bg-gray-900 border-gray-800 text-white"
                            />
                            <Button
                                className="bg-blue-600 hover:bg-blue-700 text-white px-8"
                                onClick={handleSubmit}
                                disabled={loading}
                            >
                                {loading ? "Submitting..." : "Join Waitlist"}
                            </Button>
                        </div>
                    </div>
                    <div className="mt-8 flex justify-center items-center space-x-8">
                        <Link
                            href="https://github.com/hackinsync/musicstrk/"
                            className="flex items-center text-blue-500 hover:text-blue-400 transition-colors"
                            target="_blank"
                            rel="noopener noreferrer"
                        >
                            <FileText className="w-5 h-5 mr-2" />
                            Read our Litepaper
                        </Link>
                        <div className="flex items-center text-white">
                            <Mail className="w-5 h-5 mr-2 text-blue-500" />
                            <a href="mailto:buidl@musicstrk.com" className="hover:text-blue-500 transition-colors">
                                buidl@musicstrk.com
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}
