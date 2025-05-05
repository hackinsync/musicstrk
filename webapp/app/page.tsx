import { FeaturedAuditionsSection } from "@/components/featured-auditions-section";
import Hero from "../components/Hero";

export default function Home() {
  return (
    <main className="w-screen h-screen custom-scrollbar overflow-x-hidden">
      <Hero />
      <FeaturedAuditionsSection />
    </main>
  );
}
