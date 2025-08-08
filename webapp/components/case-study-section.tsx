import { Trophy, Globe, Zap, Users, ExternalLink } from "lucide-react";
import Link from "next/link";

const caseStudyCards = [
  {
    id: "01",
    icon: Trophy,
    title: "FIRST ECOSYSTEM",
    description: "Pioneering artist-owned record label model",
    borderColor: "border-purple-700/50",
    bgColor: "bg-purple-400/5",
    hoverBgColor: "hover:bg-purple-400/10",
    link: null,
  },
  {
    id: "02",
    icon: Globe,
    title: "LIVE DAPP",
    description: "Active at bigincognito.com",
    borderColor: "border-cyan-400/50",
    bgColor: "bg-cyan-400/5",
    hoverBgColor: "hover:bg-cyan-400/10",
    link: "https://bigincognito.com",
  },
  {
    id: "03",
    icon: Zap,
    title: "PORTING TO STARKNET",
    description: "Migrating from Polygon for better scalability",
    borderColor: "border-green-400/50",
    bgColor: "bg-green-400/5",
    hoverBgColor: "hover:bg-green-400/10",
    link: null,
  },
  {
    id: "04",
    icon: Users,
    title: "FAN GOVERNANCE",
    description: "Community-driven treasury decisions",
    borderColor: "border-orange-400/50",
    bgColor: "bg-orange-400/5",
    hoverBgColor: "hover:bg-orange-400/10",
    link: null,
  },
];
export function BigIncCaseStudySection() {
  return (
    <section className="pt-5 px-6 max-w-7xl mx-auto">
      <div className="border-2 border-solid border-slate-700/30 rounded-xl p-16 bg-slate-900/20">
        <div className="text-center mb-16">
          <div className="inline-block border border-dashed border-purple-400 px-3 py-1 rounded-md mb-8 bg-purple-400/10">
            <span className="text-purple-400 text-xs font-normal">
              First Artist Ecosystem
            </span>
          </div>
          <h2 className="text-4xl md:text-5xl font-bold text-white mb-8 tracking-tight">
            Meet Big Inc
          </h2>
          <p className="text-xl text-gray-300 max-w-3xl mx-auto">
            Big Incognito is our first artist ecosystem, showcasing
            fan-governed, treasury-backed music creation.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6 mb-12">
          {caseStudyCards.map((card) => {
            const CardContent = (
              <div
                key={card.id}
                className={`border-2 border-solid ${card.borderColor} rounded-lg p-6 ${card.bgColor} ${card.hoverBgColor} transition-colors h-full flex flex-col justify-between`}
              >
                <div className="flex items-center justify-between mb-4">
                  <card.icon
                    className={`w-8 h-8 text-${
                      card.borderColor.split("-")[1]
                    }-400`}
                  />
                  <div className="text-xs font-mono text-gray-500 border border-solid border-gray-600 rounded px-2 py-1">
                    {card.id}
                  </div>
                </div>
                <h3 className="text-white font-mono font-semibold mb-3 text-sm flex items-center">
                  {card.title}{" "}
                  {card.link && (
                    <ExternalLink
                      className={`w-4 h-4 ml-2 text-gray-400 group-hover:text-${
                        card.borderColor.split("-")[1]
                      }-400 transition-colors`}
                    />
                  )}
                </h3>
                <p className="text-gray-400 text-xs font-mono leading-relaxed">
                  {card.description}
                </p>
              </div>
            );

            return card.link ? (
              <Link
                href={card.link}
                target="_blank"
                className="group"
                key={card.id}
              >
                {CardContent}
              </Link>
            ) : (
              CardContent
            );
          })}
        </div>
      </div>
    </section>
  );
}
