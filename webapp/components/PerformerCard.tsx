"use client";

import React, { useState } from "react";
import Link from "next/link";
import { cn } from "@/lib/utils";
import { X, Play, Mic2, Music, Headphones } from "lucide-react";
import { motion } from "framer-motion";
import Image from "next/image";

// Types for the performer data
export interface PerformerCardProps {
  id: string;
  stageName: string;
  genre: string;
  tiktokEmbedUrl?: string;
  tiktokThumbnailUrl?: string;
  twitterUsername?: string;
  performanceScores?: {
    name: string;
    score: number;
  }[];
  variant?: "reels" | "grid" | "detail";
  size?: "sm" | "md" | "lg";
  className?: string;
  onClick?: () => void;
}

const PerformerCard = ({
  stageName,
  genre,
  tiktokEmbedUrl,
  tiktokThumbnailUrl,
  twitterUsername,
  performanceScores,
  variant = "grid",
  size = "md",
  className,
  onClick,
}: PerformerCardProps) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [isHovered, setIsHovered] = useState(false);
  const hasVideo = Boolean(tiktokEmbedUrl);
  const hasScores = performanceScores && performanceScores.length > 0;

  // Format TikTok embed URL
  const formatTikTokEmbedUrl = (url: string) => {
    if (!url) return "";
    
    // Make sure it uses the embed format from TikTok
    if (url.includes("/video/")) {
      // Extract the video ID
      const matches = url.match(/\/video\/(\d+)/);
      if (matches && matches[1]) {
        return `https://www.tiktok.com/embed/v2/${matches[1]}`;
      }
    }
    return url;
  };

  // Get genre icon based on the genre string
  const getGenreIcon = (genre: string) => {
    const lowerGenre = genre.toLowerCase();
    if (lowerGenre.includes("rock") || lowerGenre.includes("metal") || lowerGenre.includes("punk")) {
      return <Music size={16} />;
    } else if (lowerGenre.includes("pop") || lowerGenre.includes("r&b") || lowerGenre.includes("soul")) {
      return <Mic2 size={16} />;
    } else {
      return <Headphones size={16} />;
    }
  };

  // Determine appropriate classes based on variant and size
  const containerClasses = cn(
    "group relative overflow-hidden bg-gradient-to-br from-gray-900 to-gray-800 text-white rounded-xl transition-all duration-300",
    {
      // Variant-specific styles
      "aspect-[9/16]": variant === "reels",
      "flex flex-col h-full": variant === "grid",
      "flex flex-col md:flex-row md:h-72": variant === "detail",
      
      // Size-specific styles
      "max-w-xs": variant === "reels" && size === "sm",
      "max-w-sm": variant === "reels" && size === "md",
      "max-w-md": variant === "reels" && size === "lg",
      
      // Hover state
      "hover:shadow-lg hover:shadow-indigo-500/20": true,
    },
    className
  );

  const handlePlayVideo = (e: React.MouseEvent) => {
    e.stopPropagation();
    setIsPlaying(true);
  };

  const handleCardClick = () => {
    if (onClick) onClick();
  };

  // Use a placeholder image if the TikTok thumbnail URL doesn't work
  const thumbnailUrl = tiktokThumbnailUrl && !tiktokThumbnailUrl.includes("pexels.com") 
    ? tiktokThumbnailUrl 
    : "/api/placeholder/400/600";

  // Format the TikTok embed URL
  const formattedEmbedUrl = tiktokEmbedUrl ? formatTikTokEmbedUrl(tiktokEmbedUrl) : "";

  return (
    <motion.div
      className={containerClasses}
      whileHover={{ scale: variant === "detail" ? 1 : 1.03 }}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      onClick={handleCardClick}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {/* Decorative musical note overlay */}
      <div className="absolute -top-6 -right-6 opacity-10 pointer-events-none">
        <svg width="80" height="80" viewBox="0 0 24 24" fill="currentColor">
          <path d="M9 17H5V16H9V17ZM19 4V12H21V14H19V18C19 19.11 18.11 20 17 20C15.9 20 15 19.11 15 18C15 16.9 15.9 16 17 16C17.35 16 17.69 16.09 18 16.23V4H19Z" />
        </svg>
      </div>

      {/* Media Section */}
      <div 
        className={cn(
          "relative overflow-hidden",
          {
            "w-full h-full": variant === "reels",
            "w-full h-52": variant === "grid",
            "w-full h-52 md:w-1/2 md:h-full": variant === "detail",
          }
        )}
      >
        {/* Video or Thumbnail */}
        {isPlaying && formattedEmbedUrl ? (
          <div className="relative w-full h-full">
            <iframe
              src={formattedEmbedUrl}
              className="absolute inset-0 w-full h-full border-0"
              allowFullScreen
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            ></iframe>
          </div>
        ) : (
          <div 
            className="relative w-full h-full cursor-pointer"
            onClick={hasVideo ? handlePlayVideo : undefined}
          >
            <div className="relative w-full h-full">
              <Image 
                src={thumbnailUrl}
                alt={`${stageName}'s performance`}
                className="w-full h-full object-cover"
                width={500}
                height={500}
              />
              {/* Dimming overlay */}
              <div className={cn(
                "absolute inset-0 bg-black/20 transition-opacity duration-300",
                { "opacity-40": isHovered, "opacity-20": !isHovered }
              )}/>
            </div>
            
            {/* Play button overlay */}
            {hasVideo && (
              <div className="absolute inset-0 flex items-center justify-center">
                <motion.div 
                  className="bg-white/10 backdrop-blur-sm rounded-full p-3 border border-white/30"
                  initial={{ opacity: 0.8, scale: 1 }}
                  whileHover={{ opacity: 1, scale: 1.1 }}
                  transition={{ duration: 0.2 }}
                >
                  <Play className="w-8 h-8 text-white fill-white" />
                </motion.div>
              </div>
            )}
          </div>
        )}

        {/* Overlay for reels variant */}
        {variant === "reels" && (
          <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/40 to-transparent pointer-events-none" />
        )}
      </div>

      {/* Content Section */}
      <div 
        className={cn(
          "flex flex-col z-10",
          {
            "absolute inset-0 justify-end p-4 pointer-events-none": variant === "reels",
            "p-4 flex-grow": variant === "grid",
            "p-5 md:w-1/2": variant === "detail",
          }
        )}
      >
        {/* Stage name and genre */}
        <div className="space-y-2">
          <h3 
            className={cn(
              "font-bold truncate",
              {
                "text-2xl": variant === "reels" || variant === "detail",
                "text-xl": variant === "grid",
              }
            )}
          >
            {stageName}
          </h3>
          
          <div className="flex items-center gap-2">
            <div className="bg-indigo-600 rounded-full p-1.5">
              {getGenreIcon(genre)}
            </div>
            <p className="text-sm text-indigo-200 font-medium">
              {genre}
            </p>
          </div>
        </div>

        {/* Performance Scores Visualizer */}
        {hasScores && (
          <div 
            className={cn(
              "mt-4 space-y-3",
              {
                "pointer-events-auto": variant === "reels",
              }
            )}
          >
            {performanceScores.map((score, index) => (
              <div key={score.name} className="space-y-1.5">
                <div className="flex justify-between items-center">
                  <span className="text-xs text-indigo-200 font-medium">
                    {score.name}
                  </span>
                  <span className="text-sm font-semibold">
                    {score.score}
                  </span>
                </div>
                
                <div className="h-1.5 bg-gray-700 rounded-full overflow-hidden">
                  <motion.div 
                    className={`h-full rounded-full ${
                      score.score > 85 ? "bg-gradient-to-r from-indigo-500 to-purple-500" : 
                      score.score > 70 ? "bg-gradient-to-r from-blue-500 to-indigo-500" : 
                      "bg-gradient-to-r from-cyan-500 to-blue-500"
                    }`}
                    initial={{ width: 0 }}
                    animate={{ width: `${score.score}%` }}
                    transition={{ duration: 1, delay: index * 0.1 }}
                  />
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Social Links */}
        {twitterUsername && (
          <div 
            className={cn(
              "mt-4 pt-3 border-t border-gray-700",
              {
                "pointer-events-auto": variant === "reels",
              }
            )}
          >
            <Link 
              href={`https://twitter.com/${twitterUsername}`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 text-sm font-medium text-indigo-300 hover:text-white transition-colors"
            >
              <X size={18} />
              <span>@{twitterUsername}</span>
            </Link>
          </div>
        )}
      </div>
      
      {/* Decorative elements */}
      <div className="absolute -bottom-12 -left-8 w-16 h-16 rounded-full bg-indigo-600/20 backdrop-blur-xl pointer-events-none" />
      <div className="absolute top-12 -right-4 w-8 h-8 rounded-full bg-purple-600/30 backdrop-blur-xl pointer-events-none" />
    </motion.div>
  );
};

export default PerformerCard;