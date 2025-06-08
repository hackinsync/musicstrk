"use client";

import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from "recharts";
import { Vote } from "@/utils/types/votes";
import {
  calculateUniqueVoters,
  calculateVoteActivity,
} from "../../utils/mockVotes";

type VoterStatisticsProps = {
  votes: Vote[];
};

const formatHour = (hour: number) => {
  if (hour === 0) return "Now";
  if (hour === 1) return "1hr ago";
  if (hour % 6 === 0) return `${hour}hrs ago`;
  return "";
};

import type { TooltipProps } from "recharts";

const CustomTooltip = ({
  active,
  payload,
  label,
}: TooltipProps<number, string>) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-white p-3 border border-slate-200 rounded-md shadow-lg">
        <p className="text-sm text-slate-600">
          {label === 0 ? "Current hour" : `${label} hours ago`}
        </p>
        <p className="font-medium text-teal-600">{payload[0].value} votes</p>
      </div>
    );
  }
  return null;
};

const VoterStatistics = ({ votes }: VoterStatisticsProps) => {
  const uniqueVoters = calculateUniqueVoters(votes);
  const totalVotes = votes.length;
  const voteActivity = calculateVoteActivity(votes);

  const avgVotesPerVoter =
    uniqueVoters > 0 ? Math.round((totalVotes / uniqueVoters) * 10) / 10 : 0;

  const recentVotes = voteActivity
    .filter((activity) => activity.hour < 6)
    .reduce((sum, activity) => sum + activity.voteCount, 0);

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-purple-50 rounded-lg p-4">
          <p className="text-sm text-purple-600 font-medium">Total Votes</p>
          <p className="text-2xl font-bold text-purple-800">{totalVotes}</p>
        </div>

        <div className="bg-teal-50 rounded-lg p-4">
          <p className="text-sm text-teal-600 font-medium">Unique Voters</p>
          <p className="text-2xl font-bold text-teal-800">{uniqueVoters}</p>
        </div>

        <div className="bg-amber-50 rounded-lg p-4">
          <p className="text-sm text-amber-600 font-medium">Avg. Votes/Voter</p>
          <p className="text-2xl font-bold text-amber-800">
            {avgVotesPerVoter}
          </p>
        </div>

        <div className="bg-emerald-50 rounded-lg p-4">
          <p className="text-sm text-emerald-600 font-medium">Recent Votes</p>
          <p className="text-2xl font-bold text-emerald-800">{recentVotes}</p>
        </div>
      </div>

      <div>
        <h3 className="font-medium text-slate-100 mb-3">
          Vote Activity (Last 48hrs)
        </h3>

        <div className="w-full h-48">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart
              data={voteActivity}
              margin={{ top: 5, right: 5, left: 0, bottom: 5 }}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
              <XAxis
                dataKey="hour"
                tick={{ fill: "#64748B", fontSize: 10 }}
                tickFormatter={formatHour}
                reversed
              />
              <YAxis tick={{ fill: "#64748B", fontSize: 10 }} />
              <Tooltip content={<CustomTooltip />} />
              <defs>
                <linearGradient id="colorVotes" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#0EA5E9" stopOpacity={0.8} />
                  <stop offset="95%" stopColor="#0EA5E9" stopOpacity={0} />
                </linearGradient>
              </defs>
              <Area
                type="monotone"
                dataKey="voteCount"
                stroke="#0EA5E9"
                fillOpacity={1}
                fill="url(#colorVotes)"
                animationDuration={1000}
                animationEasing="ease-out"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
};

export default VoterStatistics;
