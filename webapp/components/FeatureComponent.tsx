'use client'

import { useCallback, useEffect, useState } from "react"
import useEmblaCarousel from "embla-carousel-react"
import { Card, CardContent } from "@/components/ui/card"
import { Users, Briefcase, FileText, DollarSign, Globe, ShoppingCart, Monitor, Settings } from "lucide-react"
import { Button } from "@/components/ui/button"
import { motion, AnimatePresence } from "framer-motion"

const features = [
    {
        icon: <Briefcase className="w-8 h-8 text-[#00f5d4]" />,
        title: "On-Chain Record Label",
        description: "Create and manage your personalized record label using smart contracts, setting your terms for collaboration and revenue sharing.",
        gradient: "from-[#00f5d4] to-[#ff6b6b]"
    },
    {
        icon: <FileText className="w-8 h-8 text-[#ff6b6b]" />,
        title: "Decentralized Whitepaper",
        description: "Define clear terms for share sales, budget allocation, and revenue distribution in a transparent, on-chain document.",
        gradient: "from-[#ff6b6b] to-[#00f5d4]"
    },
    {
        icon: <DollarSign className="w-8 h-8 text-[#00f5d4]" />,
        title: "Revenue Sharing",
        description: "Shareholders earn a percentage of revenue from ticket sales, royalties, and more based on their shares.",
        gradient: "from-[#00f5d4] to-[#ff6b6b]"
    },
    {
        icon: <Globe className="w-8 h-8 text-[#ff6b6b]" />,
        title: "Custom Webspace",
        description: "Get a personalized online platform to showcase music, sell tickets, merchandise, and interact with fans and investors.",
        gradient: "from-[#ff6b6b] to-[#00f5d4]"
    },
    {
        icon: <ShoppingCart className="w-8 h-8 text-[#00f5d4]" />,
        title: "Merch & Ticketing",
        description: "Sell your merchandise and tickets directly from your webspace, empowering fans to support your music journey.",
        gradient: "from-[#00f5d4] to-[#ff6b6b]"
    },
    {
        icon: <Users className="w-8 h-8 text-[#ff6b6b]" />,
        title: "Stakeholder Interaction",
        description: "Engage with shareholders through suggestion portals, proposal channels, and transparent updates on album progress.",
        gradient: "from-[#ff6b6b] to-[#00f5d4]"
    },
    {
        icon: <Monitor className="w-8 h-8 text-[#00f5d4]" />,
        title: "Budget Transparency",
        description: "Showcase clear usage of funds for studio sessions, promotions, and other music development expenses.",
        gradient: "from-[#00f5d4] to-[#ff6b6b]"
    },
    {
        icon: <Settings className="w-8 h-8 text-[#ff6b6b]" />,
        title: "Creative Autonomy",
        description: "Maintain full creative control while receiving constructive feedback from stakeholders without compromising your vision.",
        gradient: "from-[#ff6b6b] to-[#00f5d4]"
    },
]

export function FeatureCarousel() {
    const [emblaRef, emblaApi] = useEmblaCarousel({
        align: "center",
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
        <div className="relative w-full group">
            <div className="overflow-hidden" ref={emblaRef}>
                <div className="flex gap-6 py-4">
                    <AnimatePresence>
                        {features.map((feature, index) => (
                            <motion.div 
                                key={index} 
                                className="flex-[0_0_280px] min-w-0"
                                initial={{ opacity: 0, scale: 0.9 }}
                                animate={{ 
                                    opacity: index === selectedIndex ? 1 : 0.6, 
                                    scale: index === selectedIndex ? 1 : 0.9 
                                }}
                                transition={{ duration: 0.3 }}
                            >
                                <FeatureCard 
                                    {...feature} 
                                    isActive={index === selectedIndex} 
                                />
                            </motion.div>
                        ))}
                    </AnimatePresence>
                </div>
            </div>

            {/* Navigation Buttons with Neon Effect */}
            <div className="absolute inset-y-0 flex items-center justify-between w-full pointer-events-none">
                <Button
                    variant="ghost"
                    size="icon"
                    className="
                        pointer-events-auto 
                        opacity-0 group-hover:opacity-100 
                        transition-all duration-300 
                        bg-[#00f5d4]/20 
                        hover:bg-[#00f5d4]/40 
                        text-[#00f5d4] 
                        rounded-full 
                        shadow-neon 
                        hover:shadow-neon-intense"
                    onClick={scrollPrev}
                >
                    ←
                </Button>
                <Button
                    variant="ghost"
                    size="icon"
                    className="
                        pointer-events-auto 
                        opacity-0 group-hover:opacity-100 
                        transition-all duration-300 
                        bg-[#ff6b6b]/20 
                        hover:bg-[#ff6b6b]/40 
                        text-[#ff6b6b] 
                        rounded-full 
                        shadow-neon 
                        hover:shadow-neon-intense"
                    onClick={scrollNext}
                >
                    →
                </Button>
            </div>

            {/* Pagination Dots */}
            <div className="flex justify-center mt-4 space-x-2">
                {scrollSnaps.map((_, index) => (
                    <button
                        key={index}
                        className={`
                            w-2 h-2 rounded-full transition-all duration-300
                            ${index === selectedIndex 
                                ? 'bg-[#00f5d4] w-6' 
                                : 'bg-[#ff6b6b]/50 hover:bg-[#ff6b6b]/70'
                            }
                        `}
                        onClick={() => emblaApi?.scrollTo(index)}
                    />
                ))}
            </div>
        </div>
    )
}

function FeatureCard({
    icon,
    title,
    description,
    isActive = false,
}: {
    icon: React.ReactNode
    title: string
    description: string
    gradient: string
    isActive?: boolean
}) {
    return (
        <Card 
            className={`
                h-[200px]
                bg-white/5 
                backdrop-blur-sm
                bg-opacity-10 
                border-transparent 
                overflow-hidden 
                transition-all 
                duration-300 
                ${isActive 
                    ? 'scale-105 shadow-neon-intense' 
                    : 'scale-100 shadow-lg'}
                transform
            `}
        >
            <CardContent className="p-6 relative z-10">
                <div className="space-y-4">
                    <div className="flex items-center space-x-4">
                        {icon}
                        <h3 className="font-bold text-white text-lg">{title}</h3>
                    </div>
                    <p className="text-xs text-white/80">{description}</p>
                </div>
                
                {/* Subtle Pulse Effect */}
                <div 
                    className={`
                        absolute 
                        inset-0 
                        bg-white/5 
                        animate-pulse 
                        transition-opacity 
                        duration-300 
                        ${isActive ? 'opacity-10' : 'opacity-0'}
                    `}
                />
            </CardContent>
        </Card>
    )
}

export default FeatureCarousel