"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Trophy, Users, Music, Calendar, Play } from "lucide-react";

// Mock data for ongoing auditions
const ongoingAuditions = [
  {
    id: "1",
    title: "Electronic Beat Battle",
    description: "Create the ultimate electronic track for our summer collection",
    preface: "This audition is open to all electronic music producers. Submissions must be original and not exceed 3 minutes.",
    image: "/images/audition1.jpg",
    deadline: "2025-10-15",
    participants: 1247,
    prize: "5000 STRK",
    genre: "Electronic"
  },
  {
    id: "2",
    title: "Jazz Fusion Jam",
    description: "Fuse traditional jazz with modern elements",
    preface: "Open to jazz musicians and fusion artists. Include at least one live instrument recording.",
    image: "/images/audition2.jpg",
    deadline: "2025-10-20",
    participants: 892,
    prize: "3000 STRK",
    genre: "Jazz"
  },
  // Add more as needed
];

// Mock data for past auditions
const pastAuditions = [
  {
    id: "past1",
    title: "Hip Hop Cypher 2025",
    description: "Quarterfinals recap - The best hip hop tracks of the year",
    preface: "This audition featured over 2000 submissions from around the world.",
    image: "/images/past1.jpg",
    endDate: "2025-09-01",
    winner: "MC Flow",
    participants: 2156,
    prize: "10000 STRK",
    genre: "Hip Hop",
    stats: {
      totalSubmissions: 2156,
      countries: 45,
      avgRating: 4.2
    }
  },
  {
    id: "past2",
    title: "Rock Anthem Contest",
    description: "Semifinals - Epic rock tracks that defined the season",
    preface: "A high-energy audition that brought together rock legends and newcomers.",
    image: "/images/past2.jpg",
    endDate: "2025-08-15",
    winner: "ThunderStrike",
    participants: 1843,
    prize: "7500 STRK",
    genre: "Rock",
    stats: {
      totalSubmissions: 1843,
      countries: 32,
      avgRating: 4.5
    }
  },
  // Add more as needed
];

export default function AuditionPage() {
  const [ongoing, setOngoing] = useState(ongoingAuditions);
  const [past, setPast] = useState(pastAuditions);

  // In a real app, fetch from API
  // useEffect(() => {
  //   fetch('/api/auditions/current').then(res => res.json()).then(setOngoing);
  //   fetch('/api/auditions/past').then(res => res.json()).then(setPast);
  // }, []);

  return (
    <main className="min-h-screen bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a] text-white">
      {/* Background effects */}
      <div className="absolute inset-0 bg-grid-neon opacity-20 pointer-events-none" />
      <div className="absolute inset-0 bg-neon-gradient opacity-30 pointer-events-none" />

      <div className="relative z-10 container mx-auto px-4 py-8">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-12"
        >
          <h1 className="text-5xl md:text-7xl font-bold bg-gradient-to-r from-[#00E5FF] to-[#FF3D71] bg-clip-text text-transparent mb-4">
            Music Auditions
          </h1>
          <p className="text-xl text-gray-300 max-w-2xl mx-auto">
            Discover, compete, and showcase your musical talent on Starknet
          </p>
        </motion.div>

        {/* Ongoing Auditions Section */}
        <section className="mb-16">
          <h2 className="text-3xl font-bold mb-8 text-center">Ongoing Auditions</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {ongoing.map((audition, index) => (
              <motion.div
                key={audition.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.1 }}
              >
                <Card className="bg-black/50 border-gray-700 hover:border-[#00E5FF] transition-all duration-300 group">
                  <CardHeader className="pb-4">
                    <div className="relative aspect-video bg-gradient-to-br from-[#00E5FF]/20 to-[#FF3D71]/20 rounded-lg mb-4 overflow-hidden">
                      <div className="absolute inset-0 flex items-center justify-center">
                        <Play className="w-12 h-12 text-white/70 group-hover:text-white transition-colors" />
                      </div>
                      <Badge className="absolute top-2 left-2 bg-[#00E5FF] text-black">
                        {audition.genre}
                      </Badge>
                    </div>
                    <CardTitle className="text-xl text-[#00E5FF]">{audition.title}</CardTitle>
                    <CardDescription className="text-gray-300">
                      {audition.description}
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <p className="text-sm text-gray-400 mb-4 italic">
                      "{audition.preface}"
                    </p>
                    <div className="space-y-2 text-sm">
                      <div className="flex justify-between">
                        <span className="text-gray-400">Deadline:</span>
                        <span className="text-white">{audition.deadline}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Participants:</span>
                        <span className="text-white">{audition.participants}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Prize:</span>
                        <span className="text-[#FFE700] font-bold">{audition.prize}</span>
                      </div>
                    </div>
                    <Button asChild className="w-full mt-4 bg-[#00E5FF] hover:bg-[#00E5FF]/80 text-black">
                      <Link href={`/audition/${audition.id}`}>
                        Enter Audition
                      </Link>
                    </Button>
                  </CardContent>
                </Card>
              </motion.div>
            ))}
          </div>
        </section>

        <Separator className="my-16 bg-gray-700" />

        {/* Past Auditions Section */}
        <section>
          <h2 className="text-3xl font-bold mb-8 text-center">Past Auditions</h2>
          <div className="space-y-8">
            {past.map((audition, index) => (
              <motion.div
                key={audition.id}
                initial={{ opacity: 0, x: index % 2 === 0 ? -20 : 20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.1 }}
                className="bg-black/30 rounded-lg p-6 border border-gray-700"
              >
                <div className="flex flex-col lg:flex-row gap-6">
                  <div className="lg:w-1/3">
                    <div className="aspect-video bg-gradient-to-br from-[#FF3D71]/20 to-[#FFE700]/20 rounded-lg flex items-center justify-center">
                      <Trophy className="w-16 h-16 text-[#FFE700]" />
                    </div>
                  </div>
                  <div className="lg:w-2/3">
                    <div className="flex items-start justify-between mb-4">
                      <div>
                        <h3 className="text-2xl font-bold text-[#FF3D71] mb-2">{audition.title}</h3>
                        <p className="text-gray-300 mb-2">{audition.description}</p>
                        <p className="text-sm text-gray-400 italic">
                          "{audition.preface}"
                        </p>
                      </div>
                      <Badge variant="outline" className="border-[#FFE700] text-[#FFE700]">
                        {audition.genre}
                      </Badge>
                    </div>
                    
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
                      <div className="text-center">
                        <Users className="w-6 h-6 mx-auto mb-1 text-[#00E5FF]" />
                        <div className="text-2xl font-bold text-[#00E5FF]">{audition.participants}</div>
                        <div className="text-xs text-gray-400">Participants</div>
                      </div>
                      <div className="text-center">
                        <Trophy className="w-6 h-6 mx-auto mb-1 text-[#FFE700]" />
                        <div className="text-2xl font-bold text-[#FFE700]">{audition.winner}</div>
                        <div className="text-xs text-gray-400">Winner</div>
                      </div>
                      <div className="text-center">
                        <Music className="w-6 h-6 mx-auto mb-1 text-[#FF3D71]" />
                        <div className="text-2xl font-bold text-[#FF3D71]">{audition.prize}</div>
                        <div className="text-xs text-gray-400">Prize</div>
                      </div>
                      <div className="text-center">
                        <Calendar className="w-6 h-6 mx-auto mb-1 text-gray-400" />
                        <div className="text-2xl font-bold text-white">{audition.endDate}</div>
                        <div className="text-xs text-gray-400">Ended</div>
                      </div>
                    </div>

                    <div className="flex flex-wrap gap-4 text-sm">
                      <div className="bg-gray-800 px-3 py-1 rounded">
                        <span className="text-gray-400">Total Submissions:</span> <span className="text-white">{audition.stats.totalSubmissions}</span>
                      </div>
                      <div className="bg-gray-800 px-3 py-1 rounded">
                        <span className="text-gray-400">Countries:</span> <span className="text-white">{audition.stats.countries}</span>
                      </div>
                      <div className="bg-gray-800 px-3 py-1 rounded">
                        <span className="text-gray-400">Avg Rating:</span> <span className="text-[#00D68F]">{audition.stats.avgRating}/5</span>
                      </div>
                    </div>

                    <Button asChild variant="outline" className="mt-4 border-[#FF3D71] text-[#FF3D71] hover:bg-[#FF3D71] hover:text-white">
                      <Link href={`/audition/${audition.id}`}>
                        View Recap
                      </Link>
                    </Button>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </section>
      </div>
    </main>
  );
}