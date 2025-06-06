"use client";

import React from "react";
import {
  ResponsiveContainer,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar,
  Tooltip,
  Legend,
} from "recharts";
import { Vote } from "@/utils/types/votes";
import { calculatePerformerData } from "@/utils/mockVotes";

type PerformanceCriteriaChartProps = {
  votes: Vote[];
  selectedPerformerId: string | null;
};

type TooltipProps = {
  active?: boolean;
  payload?: Array<{ name: string; value: number }>;
};

const criteriaMap = {
  "Vocal Power": "vocalPower",
  Diction: "diction",
  Confidence: "confidence",
  Timing: "timing",
  "Stage Presence": "stagePresence",
  "Musical Expression": "musicalExpression",
} as const;

const CustomTooltip: React.FC<TooltipProps> = ({ active, payload }) => {
  if (active && payload?.length) {
    return (
      <div className="bg-white p-3 border border-slate-200 rounded-md shadow-lg">
        <p className="font-medium text-slate-300">{payload[0].name}</p>
        <p className="text-sm text-slate-200">
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

const PerformanceCriteriaChart: React.FC<PerformanceCriteriaChartProps> = ({
  votes,
  selectedPerformerId,
}) => {
  const performerData = calculatePerformerData(votes);

  const displayedPerformers = selectedPerformerId
    ? performerData.filter((p) => p.performer.id === selectedPerformerId)
    : performerData.slice(0, 5);

  const radarData = Object.entries(criteriaMap).map(([label, key]) => {
    const entry: Record<string, number | string> = {
      name: label,
      fullMark: 10,
    };

    displayedPerformers.forEach((p) => {
      entry[p.performer.name] = p.criteriaAverages[key];
    });

    return entry;
  });

  const chartColors = [
    "#7C3AED", // Purple
    "#0EA5E9", // Blue
    "#F59E0B", // Amber
    "#10B981", // Emerald
    "#EF4444", // Red
  ];

  return (
    <div className="w-full h-96">
      {displayedPerformers.length ? (
        <ResponsiveContainer width="100%" height="100%">
          <RadarChart cx="50%" cy="50%" outerRadius="80%" data={radarData}>
            <PolarGrid stroke="#CBD5E1" />
            <PolarAngleAxis
              dataKey="name"
              tick={{ fill: "#64748B", fontSize: 12 }}
            />
            <PolarRadiusAxis
              angle={90}
              domain={[0, 10]}
              tick={{ fill: "#64748B" }}
            />
            {displayedPerformers.map((p, idx) => (
              <Radar
                key={p.performer.id}
                name={p.performer.name}
                dataKey={p.performer.name}
                stroke={chartColors[idx % chartColors.length]}
                fill={chartColors[idx % chartColors.length]}
                fillOpacity={0.2}
                animationDuration={500}
                animationEasing="ease-out"
              />
            ))}
            <Tooltip content={<CustomTooltip />} />
            <Legend
              formatter={(val) => (
                <span className="text-sm font-medium">{val}</span>
              )}
            />
          </RadarChart>
        </ResponsiveContainer>
      ) : (
        <div className="h-full flex items-center justify-center">
          <p className="text-slate-500">No performance data available</p>
        </div>
      )}
    </div>
  );
};

export default PerformanceCriteriaChart;
