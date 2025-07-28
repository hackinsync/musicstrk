import { FeaturedAuditionsSection } from "@/components/featured-auditions-section";
import Hero from "../components/Hero";
import { BackedBySection } from "@/components/backed-by-section";
import { BigIncCaseStudySection } from "@/components/case-study-section";
import { WhatIsMusicStrkSection } from "@/components/what-is-musicstrk-section";
import { AuditionsOnChainSection } from "@/components/auditions-on-chain-section";

export default function Home() {
  return (
    <main className="w-screen h-screen custom-scrollbar overflow-x-hidden">
      <Hero />
      <div className="
      bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a]">
        <div className="absolute inset-0 bg-grid-neon opacity-20 pointer-events-none" />
        <div className="absolute inset-0 bg-neon-gradient opacity-30 pointer-events-none" />
        <BackedBySection />
        <WhatIsMusicStrkSection />
        <BigIncCaseStudySection />
        <AuditionsOnChainSection/>
      </div>
        <FeaturedAuditionsSection />
    </main>
  );
}
