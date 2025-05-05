"use client";

import { useState, useCallback } from "react";
import Image from "next/image";
import { Play, Volume2 } from "lucide-react";
import { motion } from "framer-motion";
import React from "react";

interface ReelThumbnailProps {
  title: string;
  artist: string;
  image: string;
  color: string;
}

export function ReelThumbnail({
  title,
  artist,
  image,
  color,
}: ReelThumbnailProps) {
  const [isHovered, setIsHovered] = useState(false);

  const handleHoverStart = useCallback(() => setIsHovered(true), []);
  const handleHoverEnd = useCallback(() => setIsHovered(false), []);

  return (
    <motion.div
      className="group relative cursor-pointer w-[280px] h-[400px] rounded-lg overflow-hidden"
      whileHover={{
        scale: 1.05,
        boxShadow: `0 0 20px 2px ${color}40`,
      }}
      transition={{
        duration: 0.3,
        type: "spring",
        stiffness: 300,
        damping: 20,
      }}
      onHoverStart={handleHoverStart}
      onHoverEnd={handleHoverEnd}
      style={{ willChange: "transform" }}
    >
      {/* Thumbnail image */}
      <div className="absolute inset-0 w-full h-full">
        <Image
          src={
            image.startsWith("/")
              ? image
              : `/placeholder.svg?height=400&width=280`
          }
          alt={title}
          fill
          className="object-cover"
          priority
          sizes="280px"
          loading="eager"
        />

        {/* Overlay gradient */}
        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/40 to-transparent" />
      </div>

      {/* Waveform overlay */}
      <div className="absolute inset-0 opacity-40 mix-blend-screen">
        <WaveformOverlay color={color} />
      </div>

      {/* Play button */}
      <motion.div
        className="absolute inset-0 flex items-center justify-center"
        initial={{ opacity: 0 }}
        animate={{ opacity: isHovered ? 1 : 0 }}
        transition={{ duration: 0.2 }}
      >
        <motion.div
          className="flex items-center justify-center w-16 h-16 rounded-full bg-black/60 backdrop-blur-sm border-2"
          style={{ borderColor: color }}
          whileHover={{ scale: 1.1 }}
          transition={{ type: "spring", stiffness: 400, damping: 10 }}
        >
          <Play className="w-6 h-6 text-white fill-white" />
        </motion.div>
      </motion.div>

      {/* Content */}
      <div className="absolute bottom-0 left-0 w-full p-4 z-10">
        {/* Audio visualizer bar (animated on hover) */}
        <motion.div
          className="flex gap-1 mb-3 h-6 items-end"
          initial="hidden"
          animate={isHovered ? "visible" : "hidden"}
        >
          {[...Array(12)].map((_, i) => (
            <motion.div
              key={i}
              className="w-1 bg-white"
              style={{ backgroundColor: color }}
              variants={{
                hidden: { height: 3 },
                visible: {
                  height: Math.random() * 20 + 5,
                  transition: {
                    repeat: Number.POSITIVE_INFINITY,
                    repeatType: "reverse",
                    duration: 0.4,
                    delay: i * 0.05,
                  },
                },
              }}
            />
          ))}
          <Volume2 className="w-4 h-4 ml-2 text-white" />
        </motion.div>

        {/* Title and artist */}
        <h3 className="text-white font-bold text-lg leading-tight">{title}</h3>
        <p className="text-gray-300 text-sm">{artist}</p>

        {/* Accent line */}
        <div
          className="h-1 w-16 mt-2 rounded-full"
          style={{ backgroundColor: color }}
        />
      </div>

      {/* Border glow on hover */}
      <motion.div
        className="absolute inset-0 rounded-lg pointer-events-none"
        initial={{ boxShadow: `0 0 0 1px ${color}00` }}
        animate={{
          boxShadow: isHovered
            ? `0 0 0 2px ${color}, 0 0 20px 2px ${color}80`
            : `0 0 0 1px ${color}40`,
        }}
        transition={{ duration: 0.3 }}
      />
    </motion.div>
  );
}

// Waveform overlay component - Memoized to prevent unnecessary re-renders
const WaveformOverlay = React.memo(({ color }: { color: string }) => {
  return (
    <svg
      width="100%"
      height="100%"
      viewBox="0 0 280 400"
      preserveAspectRatio="none"
    >
      {/* Horizontal lines */}
      {[...Array(20)].map((_, i) => (
        <line
          key={`h-${i}`}
          x1="0"
          y1={20 + i * 20}
          x2="280"
          y2={20 + i * 20}
          stroke={color}
          strokeWidth="0.5"
          strokeOpacity="0.2"
        />
      ))}

      {/* Vertical time markers */}
      {[...Array(14)].map((_, i) => (
        <line
          key={`v-${i}`}
          x1={20 + i * 20}
          y1="0"
          x2={20 + i * 20}
          y2="400"
          stroke={color}
          strokeWidth="0.5"
          strokeOpacity="0.2"
        />
      ))}

      {/* Waveform path */}
      <path
        d="M0,200 Q35,150 70,200 T140,200 T210,200 T280,200"
        fill="none"
        stroke={color}
        strokeWidth="2"
        strokeOpacity="0.6"
      />

      {/* Secondary waveform path */}
      <path
        d="M0,200 Q45,240 90,200 T180,200 T270,200"
        fill="none"
        stroke={color}
        strokeWidth="1.5"
        strokeOpacity="0.4"
      />
    </svg>
  );
});

WaveformOverlay.displayName = "WaveformOverlay";
