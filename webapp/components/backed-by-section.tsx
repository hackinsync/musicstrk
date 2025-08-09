import { ArrowUpRight } from "lucide-react";
import Link from "next/link";
import { OnlyDustIcon, StarkNetIcon, StarkWareIcon } from "./icons";

const data = [
  {
    name: "OnlyDust",
    desc: "Developer Grants & Exposure",
    url: "https://onlydust.xyz",
    logo: "",
    svg: <OnlyDustIcon />,
  },
  {
    name: "Starkware",
    desc: "Scaling Infrastructure",
    url: "https://starkware.co",
    logo: "",
    svg: <StarkWareIcon />,
  },
  {
    name: "StarkNet",
    desc: "Layer 2 Network",
    url: "https://starknet.io",
    logo: "",
    svg: <StarkNetIcon />,
  },
];

export function BackedBySection() {
  return (
    <section className="pt-[4rem] px-6 max-w-7xl mx-auto relative ">
      <div className=" border-dashed border-slate-600 rounded-xl ">
        <div className="text-center mb-12">
          <div className="inline-block border-b border-dashed border-cyan-400 pb-2 mb-6">
            <h2 className="text-3xl font-bold text-white ">Backed By</h2>
          </div>
          <p className="text-gray-400">
            Supported by leading Web3 infrastructure partners
          </p>
        </div>
        <div className="grid md:grid-cols-3 gap-8 max-w-5xl mx-auto">
          {data.map((item, idx) => (
            <Link key={idx} href={item.url} target="_blank" className="group">
              <div className="border-2 border-solid border-slate-700 rounded-md p-8 bg-slate-800/50 hover:border-cyan-400 transition-all duration-300 hover:bg-slate-700/50">
                <div className="flex items-center justify-between mb-4">
                  <div className="text-2xl items-center gap-2 flex font-bold text-white group-hover:text-cyan-400 transition-colors ">
                    {item.svg}
                    {item.name}
                  </div>
                  <ArrowUpRight className="w-5 h-5 text-gray-400 group-hover:text-cyan-400 transition-colors" />
                </div>
                <p className="text-gray-400 text-sm ">{item.desc}</p>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}
