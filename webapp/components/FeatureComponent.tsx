/* eslint-disable @typescript-eslint/no-unused-vars */
"use client"

import { useCallback, useEffect, useState } from "react"
import useEmblaCarousel from "embla-carousel-react"
import { Card, CardContent } from "@/components/ui/card"
import { Users, Briefcase, FileText, DollarSign, Globe, ShoppingCart, Monitor, Settings } from "lucide-react"
import { Button } from "@/components/ui/button"

const features = [
    {
        icon: <Briefcase className="w-6 h-6 text-blue-500" />,
        title: "On-Chain Record Label",
        description: "Create and manage your personalized record label using smart contracts, setting your terms for collaboration and revenue sharing.",
    },
    {
        icon: <FileText className="w-6 h-6 text-blue-500" />,
        title: "Decentralized Whitepaper",
        description: "Define clear terms for share sales, budget allocation, and revenue distribution in a transparent, on-chain document.",
    },
    {
        icon: <DollarSign className="w-6 h-6 text-blue-500" />,
        title: "Revenue Sharing",
        description: "Shareholders earn a percentage of revenue from ticket sales, royalties, and more based on their shares.",
    },
    {
        icon: <Globe className="w-6 h-6 text-blue-500" />,
        title: "Custom Webspace",
        description: "Get a personalized online platform to showcase music, sell tickets, merchandise, and interact with fans and investors.",
    },
    {
        icon: <ShoppingCart className="w-6 h-6 text-blue-500" />,
        title: "Merch & Ticketing",
        description: "Sell your merchandise and tickets directly from your webspace, empowering fans to support your music journey.",
    },
    {
        icon: <Users className="w-6 h-6 text-blue-500" />,
        title: "Stakeholder Interaction",
        description: "Engage with shareholders through suggestion portals, proposal channels, and transparent updates on album progress.",
    },
    {
        icon: <Monitor className="w-6 h-6 text-blue-500" />,
        title: "Budget Transparency",
        description: "Showcase clear usage of funds for studio sessions, promotions, and other music development expenses.",
    },
    {
        icon: <Settings className="w-6 h-6 text-blue-500" />,
        title: "Creative Autonomy",
        description: "Maintain full creative control while receiving constructive feedback from stakeholders without compromising your vision.",
    },
]


export function FeatureCarousel() {
    const [emblaRef, emblaApi] = useEmblaCarousel({
        align: "start",
        loop: true,
        skipSnaps: false,
        dragFree: true,
    })

    const [selectedIndex, setSelectedIndex] = useState(0)
    const [scrollSnaps, setScrollSnaps] = useState<number[]>([])

    const scrollPrev = useCallback(() => {
        if (emblaApi) emblaApi.scrollPrev()
    }, [emblaApi])

    const scrollNext = useCallback(() => {
        if (emblaApi) emblaApi.scrollNext()
    }, [emblaApi])

    const onSelect = useCallback(() => {
        if (!emblaApi) return
        setSelectedIndex(emblaApi.selectedScrollSnap())
    }, [emblaApi])

    useEffect(() => {
        if (!emblaApi) return

        onSelect()
        setScrollSnaps(emblaApi.scrollSnapList())
        emblaApi.on("select", onSelect)

        // Auto-play setup
        let intervalId: NodeJS.Timeout

        const startAutoplay = () => {
            intervalId = setInterval(() => {
                if (!emblaApi.canScrollNext()) {
                    emblaApi.scrollTo(0)
                } else {
                    emblaApi.scrollNext()
                }
            }, 3000) // Change slide every 3 seconds
        }

        startAutoplay()

        // Pause on hover/touch
        const stopAutoplay = () => clearInterval(intervalId)
        const rootNode = emblaApi.rootNode()
        rootNode.addEventListener("mouseenter", stopAutoplay)
        rootNode.addEventListener("mouseleave", startAutoplay)
        rootNode.addEventListener("touchstart", stopAutoplay)
        rootNode.addEventListener("touchend", startAutoplay)

        return () => {
            clearInterval(intervalId)
            emblaApi.off("select", onSelect)
            rootNode.removeEventListener("mouseenter", stopAutoplay)
            rootNode.removeEventListener("mouseleave", startAutoplay)
            rootNode.removeEventListener("touchstart", stopAutoplay)
            rootNode.removeEventListener("touchend", startAutoplay)
        }
    }, [emblaApi, onSelect])

    return (
        <div className="relative w-full">
            <div className="overflow-hidden" ref={emblaRef}>
                <div className="flex gap-6">
                    {features.map((feature, index) => (
                        <div key={index} className="flex-[0_0_280px] min-w-0">
                            <FeatureCard {...feature} />
                        </div>
                    ))}
                </div>
            </div>

            {/* Navigation Buttons */}
            <Button
                variant="ghost"
                size="icon"
                className="absolute left-0 top-1/2 hover:bg-transparent -translate-y-1/2 z-10 bg-transparent h-full"
                onClick={scrollPrev}
            />
            <Button
                variant="ghost"
                size="icon"
                className="absolute right-0 top-1/2 hover:bg-transparent -translate-y-1/2 z-10 bg-transparent h-full"
                onClick={scrollNext}
            />
            {/* Fade edges */}
            <div className="absolute inset-y-0 left-0 w-32 bg-gradient-to-r from-[#112c71] to-transparent pointer-events-none" />
            <div className="absolute inset-y-0 right-0 w-32 bg-gradient-to-l from-[#112c71] to-transparent pointer-events-none" />
        </div>
    )
}

function FeatureCard({
    icon,
    title,
    description,
}: {
    icon: React.ReactNode
    title: string
    description: string
}) {
    return (
        <Card className="bg-gray-900/50 h-48 border-gray-800">
            <CardContent className="p-6">
                <div className="space-y-2">
                    {icon}
                    <h3 className="font-semibold text-white">{title}</h3>
                    <p className="text-sm text-gray-400">{description}</p>
                </div>
            </CardContent>
        </Card>
    )
}

