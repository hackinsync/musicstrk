"use client";

import React, { useState } from "react";
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
} from "recharts";
import { Vote, VoteCriteria } from "@/utils/types/votes";
import { calculatePerformerData } from "@/utils/mockVotes";

type CriteriaBreakdownProps = {
  votes: Vote[];
  selectedPerformerId: string | null;
};

import type { TooltipProps } from "recharts";

const CustomTooltip: React.FC<TooltipProps<number, string>> = ({
  active,
  payload,
  label,
}) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-white p-3 border border-slate-200 rounded-md shadow-lg">
        <p className="font-medium text-slate-800">{label}</p>
        <p className="text-sm text-slate-600">
          Score:{" "}
          <span className="font-medium text-purple-600">
            {payload[0].value}
          </span>
        </p>
      </div>
    );
  }
  return null;
};

const criteriaOptions = [
  { key: "vocalPower", label: "Vocal Power" },
  { key: "diction", label: "Diction" },
  { key: "confidence", label: "Confidence" },
  { key: "timing", label: "Timing" },
  { key: "stagePresence", label: "Stage Presence" },
  { key: "musicalExpression", label: "Musical Expression" },
];

const CriteriaBreakdown: React.FC<CriteriaBreakdownProps> = ({
  votes,
  selectedPerformerId,
}) => {
  const [selectedCriteria, setSelectedCriteria] =
    useState<keyof VoteCriteria>("vocalPower");

  const performerData = calculatePerformerData(votes);

  const chartData = performerData
    .filter((data) =>
      selectedPerformerId ? data.performer.id === selectedPerformerId : true
    )
    .slice(0, selectedPerformerId ? undefined : 10)
    .map((data) => ({
      name: data.performer.name,
      score: data.criteriaAverages[selectedCriteria],
      voteCount: data.voteCount,
    }))
    .sort((a, b) => b.score - a.score);

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        {criteriaOptions.map((option) => (
          <button
            key={option.key}
            onClick={() =>
              setSelectedCriteria(option.key as keyof VoteCriteria)
            }
            className={`px-3 py-1.5 text-sm rounded-full transition-all ${
              selectedCriteria === option.key
                ? "bg-purple-600 text-white shadow-md"
                : "bg-slate-100 text-slate-700 hover:bg-slate-200"
            }`}
          >
            {option.label}
          </button>
        ))}
      </div>

      <div className="w-full h-80">
        {chartData.length > 0 ? (
          <ResponsiveContainer width="100%" height="100%">
            <BarChart
              data={chartData}
              margin={{ top: 10, right: 10, left: 10, bottom: 50 }}
            >
              <XAxis
                dataKey="name"
                angle={-45}
                textAnchor="end"
                height={80}
                tick={{ fontSize: 12 }}
              />
              <YAxis domain={[0, 10]} tick={{}} tickCount={11} />
              <Tooltip content={<CustomTooltip />} />
              <Bar
                dataKey="score"
                fill="#7C3AED"
                radius={[4, 4, 0, 0]}
                animationDuration={1000}
                animationEasing="ease-out"
              />
            </BarChart>
          </ResponsiveContainer>
        ) : (
          <div className="h-full flex items-center justify-center">
            <p className="text-slate-500">No performance data available</p>
          </div>
        )}
      </div>

      {selectedPerformerId &&
        performerData.some(
          (data) => data.performer.id === selectedPerformerId
        ) && (
          <div className="mt-8 space-y-4">
            <h3 className="font-medium text-white">Performance Breakdown</h3>

            {criteriaOptions.map((criteria) => {
              const performer = performerData.find(
                (data) => data.performer.id === selectedPerformerId
              );
              const score =
                performer?.criteriaAverages[
                  criteria.key as keyof VoteCriteria
                ] || 0;

              return (
                <div key={criteria.key} className="space-y-1">
                  <div className="flex justify-between items-center">
                    <span className="text-sm text-slate-100">
                      {criteria.label}
                    </span>
                    <span className="text-sm font-medium text-purple-600">
                      {score}
                    </span>
                  </div>
                  <div className="h-3 bg-slate-200 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-gradient-to-r from-purple-500 to-purple-700 rounded-full"
                      style={{
                        width: `${score * 10}%`,
                        transition: "width 0.5s ease",
                      }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        )}
    </div>
  );
};

export default CriteriaBreakdown;
