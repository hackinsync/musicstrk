"use client";

import {
  Zap,
  Users,
  LinkIcon,
  Check,
  Code,
  DollarSign,
  Infinity,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Line,
  LineChart,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import { ChartContainer, ChartTooltipContent } from "@/components/ui/chart";

// Dummy data for the chart
const chartData = [
  { month: "Jan", "Artist Share": 2000, "Fan Share": 5000 },
  { month: "Feb", "Artist Share": 3500, "Fan Share": 8000 },
  { month: "Mar", "Artist Share": 5000, "Fan Share": 12000 },
  { month: "Apr", "Artist Share": 4500, "Fan Share": 10000 },
  { month: "May", "Artist Share": 6000, "Fan Share": 15000 },
  { month: "Jun", "Artist Share": 8000, "Fan Share": 22000 },
  { month: "Jul", "Artist Share": 7500, "Fan Share": 18000 },
  { month: "Aug", "Artist Share": 10000, "Fan Share": 25000 },
  { month: "Sep", "Artist Share": 9000, "Fan Share": 20000 },
  { month: "Oct", "Artist Share": 12000, "Fan Share": 28000 },
  { month: "Nov", "Artist Share": 11000, "Fan Share": 24000 },
  { month: "Dec", "Artist Share": 13000, "Fan Share": 30000 },
];

export function WhatIsMusicStrkSection() {
  return (
    <section className="py-32 px-6 max-w-7xl mx-auto">
      <div className="text-center mb-12">
        <div className="inline-block border-b border-dashed border-cyan-400 pb-2 mb-6">
          <h2 className="text-3xl font-bold text-white ">What Is MusicStrk?</h2>
        </div>
        <p className="text-gray-400">
          Powering the future of artist-owned music.
        </p>
      </div>
      {/* Top Grid: Web3-Native Factory & Fan Governance */}
      <div className="grid lg:grid-cols-2 gap-0">
        {/* Web3-Native Factory Card */}
        <div className="border-2 border-r-0 border-solid border-slate-700 rounded-b-none  rounded-xl rounded-r-none p-8 bg-slate-800/30">
          <div className="flex items-center gap-3 mb-6">
            <div className="border border-solid border-cyan-600 rounded-lg p-2 bg-cyan-400/10">
              <Zap className="w-6 h-6 text-cyan-400" />
            </div>
            <h3 className="text-2xl font-bold text-white font-poppins">
              Web3-Native Factory
            </h3>
          </div>
          <p className="text-gray-300 leading-relaxed mb-6">
            Spin up self-owned artist ecosystems using smart contracts, not
            corporations.
          </p>
          <div className="bg-slate-900 border border-solid border-slate-800 rounded-lg p-4 font-poppins text-sm text-gray-300 h-48 overflow-auto">
            <pre>
              <span className="text-green-400">$</span> musicstrk deploy
              ecosystem --name MyArtistLabel
              <br />
              <span className="text-green-400">✓</span> Initializing smart
              contracts...
              <br />
              <span className="text-green-400">✓</span> Deploying to on-chain
              network...
              <br />
              <span className="text-green-400">✓</span> Ecosystem MyArtistLabel
              launched!
              <br />
              <br />
              <span className="text-cyan-400">What will you create?</span>
            </pre>
          </div>
        </div>

        {/* Fan Governance Card */}
        <div className="border-2 border-solid border-slate-700  rounded-xl rounded-l-none  p-8 bg-slate-800/30">
          <div className="flex items-center gap-3 mb-6">
            <div className="border border-solid border-purple-400 rounded-lg p-2 bg-purple-400/10">
              <Users className="w-6 h-6 text-purple-400" />
            </div>
            <h3 className="text-2xl font-bold text-white font-poppins">
              Fan Governance
            </h3>
          </div>
          <p className="text-gray-300 leading-relaxed mb-6">
            Collaborate with your community on real, on-chain decisions, not
            just ideas.
          </p>
          <div className="space-y-4">
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 rounded-full flex-shrink-0 bg-gradient-to-br from-blue-500 to-purple-500"></div>
              <div className="bg-slate-700 rounded-lg p-3 text-white max-w-[80%]">
                Hey team! Lets vote on the next album cover.
              </div>
            </div>
            <div className="flex justify-end gap-2">
              <Button
                variant="outline"
                className="border-dashed border-cyan-400 text-cyan-400 hover:bg-cyan-400 hover:text-black bg-transparent rounded-lg font-poppins text-xs px-4 py-2"
              >
                Option A: Abstract Art
              </Button>
              <Button
                variant="outline"
                className="border-dashed border-purple-400 text-purple-400 hover:bg-purple-400 hover:text-black bg-transparent rounded-lg font-poppins text-xs px-4 py-2"
              >
                Option B: Minimalist Design
              </Button>
            </div>
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 rounded-full flex-shrink-0 bg-gradient-to-br from-green-500 to-emerald-500"></div>
              <div className="bg-slate-700 rounded-lg p-3 text-white max-w-[80%]">
                I like Option B. This works with the brand.
              </div>
            </div>
            <div className="flex justify-end">
              <div className="inline-flex items-center gap-2 bg-green-600/20 text-green-400 border border-dashed border-green-500 rounded-lg px-4 py-2 text-sm font-poppins">
                This looks great! <Check className="w-4 h-4" />
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Middle Section: Transparent Transactions (Chart) */}
      <div className="border-2 border-t-0 rounded-t-none border-solid border-slate-700 rounded-xl p-8 bg-slate-800/30 mb-8">
        <div className="flex items-center gap-3 mb-6">
          <div className="border border-dashed border-green-400 rounded-lg p-2 bg-green-400/10">
            <DollarSign className="w-6 h-6 text-green-400" />
          </div>
          <h3 className="text-2xl font-bold text-white font-poppins">
            Transparent Transactions
          </h3>
        </div>
        <p className="text-gray-300 leading-relaxed mb-6">
          Monitor and analyze transparent transactions and royalty flows
          on-chain.
        </p>
        <div className="flex justify-end gap-4 mb-4 text-sm font-poppins text-gray-400">
          <div className="flex items-center gap-2">
            <span className="w-3 h-3 rounded-full bg-cyan-400"></span> Artist
            Share: <span className="text-white font-bold">25,380</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="w-3 h-3 rounded-full bg-orange-400"></span> Fan
            Share: <span className="text-white font-bold">60,134</span>
          </div>
        </div>
        <ChartContainer
          config={{
            "Artist Share": {
              label: "Artist Share",
              color: "hsl(var(--chart-1))", // Cyan
            },
            "Fan Share": {
              label: "Fan Share",
              color: "hsl(var(--chart-2))", // Orange
            },
          }}
          className="h-[300px] w-full"
        >
          <ResponsiveContainer width="100%" height="100%">
            <LineChart
              data={chartData}
              margin={{ top: 5, right: 30, left: 20, bottom: 5 }}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
              <XAxis
                dataKey="month"
                stroke="#64748B"
                tickLine={false}
                axisLine={false}
              />
              <YAxis
                stroke="#64748B"
                tickLine={false}
                axisLine={false}
                tickFormatter={(value) => `${value / 1000}K`}
              />
              <Tooltip content={<ChartTooltipContent />} />
              <Line
                type="monotone"
                dataKey="Artist Share"
                stroke="var(--color-Artist-Share)"
                strokeWidth={2}
                dot={{ r: 6 }}
                activeDot={{ r: 6 }}
              />
              <Line
                type="monotone"
                dataKey="Fan Share"
                stroke="var(--color-Fan-Share)"
                strokeWidth={2}
                dot={{ r: 6 }}
                activeDot={{ r: 6 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </ChartContainer>
        <div className="flex gap-4 mt-6 justify-center">
          <Button
            variant="outline"
            className="border-solid border-slate-700 text-gray-400 hover:bg-slate-700/50 hover:text-white bg-transparent rounded-lg font-poppins text-sm"
          >
            <Code className="w-4 h-4 mr-2" /> Smart Contracts
          </Button>
          <Button
            variant="outline"
            className="border-solid border-slate-700 text-gray-400 hover:bg-slate-700/50 hover:text-white bg-transparent rounded-lg font-poppins text-sm"
          >
            <LinkIcon className="w-4 h-4 mr-2" /> On-Chain Data
          </Button>
        </div>
      </div>

      {/* Bottom Grid: On-Chain Ownership & Unlimited Creative Freedom */}
      <div className="grid md:grid-cols-2 gap-8">
        {/* On-Chain Ownership Card */}
        <div className="border-2 border-solid border-slate-700 rounded-xl p-8 bg-slate-800/30">
          <div className="flex items-center gap-3 mb-4">
            <div className="border border-dashed border-purple-400 rounded-lg p-2 bg-purple-400/10">
              <LinkIcon className="w-6 h-6 text-purple-400" />
            </div>
            <h3 className="text-2xl font-bold text-white font-poppins">
              On-Chain Ownership
            </h3>
          </div>
          <p className="text-gray-300 leading-relaxed">
            Access your record labels through on-chain shares, fan governance,
            and treasury-backed growth.
          </p>
        </div>

        {/* Unlimited Creative Freedom Card */}
        <div className="border-2 border-solid border-slate-700 rounded-xl p-8 bg-slate-800/30">
          <div className="flex items-center gap-3 mb-4">
            <div className="border border-dashed border-green-400 rounded-lg p-2 bg-green-400/10">
              <Infinity className="w-6 h-6 text-green-400" />
            </div>
            <h3 className="text-2xl font-bold text-white font-poppins">
              Unlimited Creative Freedom
            </h3>
          </div>
          <p className="text-gray-300 leading-relaxed">
            Go ahead, create without limits. Self-owned labels and direct
            artist-to-fan connections.
          </p>
        </div>
      </div>
    </section>
  );
}
