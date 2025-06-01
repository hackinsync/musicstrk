"use client";

import { useState } from "react";
import { useParams } from "next/navigation";

import PerformanceCriteriaChart from "@/components/analytics/PerformanceCriteriaChart";
import PerformerLeaderboard from "@/components/analytics/PerformerLeaderboard";
import VoterStatistics from "@/components/analytics/VoterStatistics";
import CriteriaBreakdown from "@/components/analytics/CriteriaBreakdown";
import { getMockVotes } from "@/utils/mockVotes";

export default function AnalyticsPage() {
  const params = useParams();
  const auditionId = decodeURIComponent(params?.auditionId as string);

  const [selectedPerformerId, setSelectedPerformerId] = useState<string | null>(
    null
  );

  const votes = getMockVotes(auditionId || "1");

  const handlePerformerSelect = (performerId: string) => {
    setSelectedPerformerId(
      performerId === selectedPerformerId ? null : performerId
    );
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a] text-slate-100">
      <div className="max-w-7xl mx-auto px-4 py-8 sm:px-6 lg:px-8">
        <header className="mb-8">
          <h1 className="text-2xl font-bold text-white">Audition Analytics</h1>
          <p className="mt-2 text-lg text-slate-300">
            Detailed voting analysis for audition #[auditionId]
          </p>
        </header>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2 space-y-8">
            <div className="bg-[#1a1a3a]/80 backdrop-blur-md rounded-lg shadow-md p-6 transition-all duration-300 hover:shadow-lg">
              <h2 className="text-xl font-semibold text-white mb-4">
                Performance by Criteria
              </h2>
              <PerformanceCriteriaChart
                votes={votes}
                selectedPerformerId={selectedPerformerId}
              />
            </div>

            <div className="bg-[#1a1a3a]/80 backdrop-blur-md rounded-lg shadow-md p-6 transition-all duration-300 hover:shadow-lg">
              <h2 className="text-xl font-semibold text-white mb-4">
                Criteria Breakdown
              </h2>
              <CriteriaBreakdown
                votes={votes}
                selectedPerformerId={selectedPerformerId}
              />
            </div>
          </div>

          <div className="space-y-8">
            <div className="bg-[#1a1a3a]/80 backdrop-blur-md rounded-lg shadow-md p-6 transition-all duration-300 hover:shadow-lg">
              <h2 className="text-xl font-semibold text-white mb-4">
                Performer Leaderboard
              </h2>
              <PerformerLeaderboard
                votes={votes}
                onPerformerSelect={handlePerformerSelect}
                selectedPerformerId={selectedPerformerId}
              />
            </div>

            <div className="bg-[#1a1a3a]/80 backdrop-blur-md rounded-lg shadow-md p-6 transition-all duration-300 hover:shadow-lg">
              <h2 className="text-xl font-semibold text-white mb-4">
                Voter Statistics
              </h2>
              <VoterStatistics votes={votes} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
