import { Button } from "@/components/ui/button";
import { ArrowRight, Wallet, Music, Trophy } from "lucide-react";

export function AuditionsOnChainSection() {
  return (
    <section className="py-20 px-6 max-w-7xl mx-auto">
      <div className="text-center mb-16">
        <div className="w-fit mx-auto flex justify-center items-center border border-dashed border-cyan-400 p-2 rounded-md mb-8 bg-cyan-400/10">
          <span className="text-cyan-400 text-xs">Go-to-Market Mechanism</span>
        </div>
        <h2 className="text-4xl font-bold text-white mb-8 tracking-tight">
          Auditions On-Chain
        </h2>
        <p className="text-lg text-gray-300 max-w-3xl mx-auto mb-12">
          Our innovative approach to onboarding artists into Web3. Connect your
          wallet, showcase your talent, and compete for funding and prizes.
        </p>
      </div>

      <div className="grid md:grid-cols-3 gap-8 mb-12">
        <div className="border-2 border-solid border-cyan-700/50 rounded-lg p-8 bg-cyan-400/5 hover:bg-cyan-400/10 transition-colors">
          <div className="flex items-center justify-between mb-6">
            <div className="border border-solid border-cyan-600 rounded-full p-4">
              <Wallet className="w-8 h-8 text-cyan-400" />
            </div>
            <div className="text-xs font-poppins text-gray-500 border border-solid border-gray-600 rounded px-2 py-1">
              STEP 01
            </div>
          </div>
          <h3 className="text-xl font-bold text-white mb-4 font-poppins">
            CONNECT WALLET
          </h3>
          <p className="text-gray-300 leading-relaxed font-poppins text-sm">
            Artists sign in with their Web3 wallet to access the audition
            platform and showcase their musical talents.
          </p>
        </div>

        <div className="border-2 border-solid border-purple-400/50 rounded-lg p-8 bg-purple-400/5 hover:bg-purple-400/10 transition-colors">
          <div className="flex items-center justify-between mb-6">
            <div className="border border-solid border-purple-400 rounded-full p-4">
              <Music className="w-8 h-8 text-purple-400" />
            </div>
            <div className="text-xs font-poppins text-gray-500 border border-solid border-gray-600 rounded px-2 py-1">
              STEP 02
            </div>
          </div>
          <h3 className="text-xl font-bold text-white mb-4 font-poppins">
            PERFORM & COMPETE
          </h3>
          <p className="text-gray-300 leading-relaxed font-poppins text-sm">
            Submit your music, participate in genre-specific competitions, and
            let the community discover your unique sound.
          </p>
        </div>

        <div className="border-2 border-solid border-green-400/50 rounded-lg p-8 bg-green-400/5 hover:bg-green-400/10 transition-colors">
          <div className="flex items-center justify-between mb-6">
            <div className="border border-solid border-green-400 rounded-full p-4">
              <Trophy className="w-8 h-8 text-green-400" />
            </div>
            <div className="text-xs font-poppins text-gray-500 border border-solid border-gray-600 rounded px-2 py-1">
              STEP 03
            </div>
          </div>
          <h3 className="text-xl font-bold text-white mb-4 font-poppins">
            WIN FUNDING
          </h3>
          <p className="text-gray-300 leading-relaxed font-poppins text-sm">
            Winners receive direct funding or raffle-based prizes, creating
            engagement farms for Web3 music creation.
          </p>
        </div>
      </div>

      <div className="text-center">
        <Button className="bg-cyan-500 hover:bg-cyan-600 text-black p-8 rounded-lg border border-solid border-cyan-600 text-lg">
          Start Your Audition
          <ArrowRight className="w-5 h-5 ml-2" />
        </Button>
      </div>
    </section>
  );
}
