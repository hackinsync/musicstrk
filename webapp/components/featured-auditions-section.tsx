"use client";

import { useRef } from "react";
import { motion } from "framer-motion";
import { ArrowDown, Zap } from "lucide-react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { ReelBannerEffect } from "./reel-banner-effect";

export function FeaturedAuditionsSection() {
  const sectionRef = useRef<HTMLDivElement>(null);

  const handleScrollDown = () => {
    if (sectionRef.current) {
      const sectionBottom =
        sectionRef.current.offsetTop + sectionRef.current.offsetHeight;
      window.scrollTo({
        top: sectionBottom,
        behavior: "smooth",
      });
    }
  };

  return (
    <section
      ref={sectionRef}
      className="relative min-h-screen w-full bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a]  overflow-hidden"
    >
      {/* Background elements */}
      <div className="absolute inset-0 bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a] ">
        <div className="absolute top-0 left-0 w-full h-full opacity-10">
          <div className="absolute top-[10%] left-[15%] w-32 h-32 rounded-full bg-[#00E5FF] blur-[80px]"></div>
          <div className="absolute bottom-[20%] right-[10%] w-40 h-40 rounded-full bg-[#FF3D71] blur-[100px]"></div>
          <div className="absolute top-[40%] right-[30%] w-24 h-24 rounded-full bg-[#FFE700] blur-[70px]"></div>
        </div>
      </div>

  

      {/* Content overlay gradient */}
      <div className="absolute inset-0 bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a]  pointer-events-none z-10"></div>

      <div className="relative z-20 container mx-auto px-4 pt-20 pb-32">
        {/* Header content */}
        <div className="flex flex-col items-center text-center mb-12">
          <h2 className="text-4xl md:text-6xl font-bold bg-gradient-to-r from-[#00E5FF] to-[#FF3D71] bg-clip-text text-transparent mb-4 leading-normal">
            BUIDLing Music Auditions on Starknet
          </h2>

          <p className="text-lg md:text-xl text-gray-300 max-w-3xl mb-8">
            On-chain. Transparent. Open to All Genres. <br />Powered by Starknet.
          </p>

          <Button
            asChild
            className="bg-[#00E5FF] hover:bg-[#00E5FF]/80 text-black font-bold px-8 py-6 text-lg rounded-full transition-all duration-300 hover:shadow-[0_0_15px_rgba(0,229,255,0.5)]"
          >
            <Link href="/audition">Explore Auditions →</Link>
          </Button>
        </div>

        {/* Scroll indicator - Properly placed below the fold (after header, before visual content) */}
        <div className="flex flex-col items-center my-12">
          <button
            onClick={handleScrollDown}
            className="group flex flex-col items-center gap-2 text-gray-400 hover:text-[#00E5FF] transition-colors duration-300 mb-10"
          >
            <span className="text-sm uppercase tracking-wider">
              Scroll Down
            </span>
            <motion.div
              animate={{ y: [0, 10, 0] }}
              transition={{
                duration: 2,
                repeat: Number.POSITIVE_INFINITY,
                ease: "easeInOut",
              }}
            >
              <ArrowDown className="w-6 h-6 group-hover:text-[#00E5FF]" />
            </motion.div>
          </button>
        </div>

        {/* Reel Banner Effect Component - Increased padding on both sides for better visibility */}
        <div className="h-[50vh] md:h-[60vh] w-full relative px-12 md:px-16 lg:px-20 overflow-visible mb-[30rem]">
          <ReelBannerEffect />
        </div>
      </div>

      {/* Decorative elements */}
      <div className="absolute top-0 left-0 w-full h-full pointer-events-none">
        <div className="absolute top-[10%] left-[5%] text-[#00E5FF] opacity-20">
          <Zap className="w-12 h-12" />
        </div>
        <div className="absolute bottom-[20%] right-[8%] text-[#FF3D71] opacity-20">
          <Zap className="w-16 h-16" />
        </div>
      </div>
    </section>
  );
}
