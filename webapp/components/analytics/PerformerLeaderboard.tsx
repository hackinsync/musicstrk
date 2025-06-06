"use client";

import { useState } from "react";
import { Vote } from "@/utils/types/votes";
import { calculatePerformerData } from "../../utils/mockVotes";

type PerformerLeaderboardProps = {
  votes: Vote[];
  onPerformerSelect: (performerId: string) => void;
  selectedPerformerId: string | null;
};

export default function PerformerLeaderboard({
  votes,
  onPerformerSelect,
  selectedPerformerId,
}: PerformerLeaderboardProps) {
  const [sortCriteria, setSortCriteria] = useState<string>("aggregateScore");

  const performerData = calculatePerformerData(votes);

  const sortedPerformers = [...performerData].sort((a, b) => {
    if (sortCriteria === "aggregateScore") {
      return b.aggregateScore - a.aggregateScore;
    } else if (sortCriteria === "voteCount") {
      return b.voteCount - a.voteCount;
    } else {
      const criteriaKey = sortCriteria as keyof typeof a.criteriaAverages;
      return b.criteriaAverages[criteriaKey] - a.criteriaAverages[criteriaKey];
    }
  });

  return (
    <div className="space-y-4 text-slate-100">
      {/* Sort Dropdown */}
      <div className="flex justify-between items-center">
        <h3 className="font-medium text-slate-200">Sort by</h3>
        <div className="relative">
          <select
            className="appearance-none text-sm bg-[#2a2a4a] text-slate-100 border border-slate-500 rounded-md px-3 py-2 pr-8 focus:outline-none focus:ring-2 focus:ring-purple-600 transition-all duration-200"
            value={sortCriteria}
            onChange={(e) => setSortCriteria(e.target.value)}
          >
            <option value="aggregateScore">Overall Score</option>
            <option value="voteCount">Vote Count</option>
            <option value="vocalPower">Vocal Power</option>
            <option value="diction">Diction</option>
            <option value="confidence">Confidence</option>
            <option value="timing">Timing</option>
            <option value="stagePresence">Stage Presence</option>
            <option value="musicalExpression">Musical Expression</option>
          </select>

          {/* Custom dropdown icon */}
          <div className="pointer-events-none absolute inset-y-0 right-2 flex items-center text-slate-400">
            <svg
              className="h-4 w-4"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M19 9l-7 7-7-7"
              />
            </svg>
          </div>
        </div>
      </div>

      {/* Performer List */}
      <div className="overflow-y-auto max-h-[400px] pr-1 -mr-1">
        <ul className="space-y-2">
          {sortedPerformers.map((performer, index) => (
            <li
              key={performer.performer.id}
              className={`rounded-lg transition-all cursor-pointer ${
                selectedPerformerId === performer.performer.id
                  ? "bg-purple-200/10 border-l-4 border-purple-500"
                  : "bg-[#1f1f3a] hover:bg-[#2b2b4d]"
              }`}
              onClick={() => onPerformerSelect(performer.performer.id)}
            >
              <div className="p-3 flex items-center space-x-3">
                <div className="flex-shrink-0 w-8 h-8 flex items-center justify-center rounded-full bg-slate-600 text-white font-semibold text-sm">
                  {index + 1}
                </div>

                <div className="min-w-0 flex-1">
                  <div className="flex justify-between">
                    <p className="text-sm font-medium text-white truncate">
                      {performer.performer.name}
                    </p>
                    <div className="flex items-center">
                      <span
                        className={`px-2 py-0.5 rounded-full text-xs font-medium 
                    ${
                      sortCriteria === "voteCount"
                        ? "bg-blue-200 text-blue-800"
                        : "bg-purple-200 text-purple-800"
                    }`}
                      >
                        {sortCriteria === "voteCount"
                          ? `${performer.voteCount} votes`
                          : sortCriteria === "aggregateScore"
                          ? `${performer.aggregateScore}`
                          : `${
                              performer.criteriaAverages[
                                sortCriteria as keyof typeof performer.criteriaAverages
                              ]
                            }`}
                      </span>
                    </div>
                  </div>

                  <div className="mt-1 w-full h-1.5 bg-slate-700 rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full ${
                        sortCriteria === "voteCount"
                          ? "bg-blue-500"
                          : "bg-gradient-to-r from-purple-500 to-purple-700"
                      }`}
                      style={{
                        width: `${
                          sortCriteria === "voteCount"
                            ? (performer.voteCount /
                                sortedPerformers[0].voteCount) *
                              100
                            : sortCriteria === "aggregateScore"
                            ? (performer.aggregateScore / 10) * 100
                            : (performer.criteriaAverages[
                                sortCriteria as keyof typeof performer.criteriaAverages
                              ] /
                                10) *
                              100
                        }%`,
                        transition: "width 0.5s ease",
                      }}
                    />
                  </div>
                </div>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
