'use client';

import React, { useState, useEffect, useRef } from 'react';
import { useParams } from 'next/navigation';
import { motion } from 'framer-motion';
import { ChevronUp, ChevronDown, ArrowLeft } from 'lucide-react';
import { Performer } from '@/utils/mocks/performers';
import PerformerReel from '@/components/audition/PerformerReel';
import Link from 'next/link';
import Image from 'next/image';
import logo from '@/app/assets/images/LogoText-W.png';
import { fetchPerformersByAuditionId } from '@/sevices/api';

export default function ReelsPage() {
  const params = useParams();
  const auditionId = params.auditionId as string;
  const [performers, setPerformers] = useState<Performer[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentIndex, setCurrentIndex] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);
  const [touchStart, setTouchStart] = useState<number | null>(null);
  const [touchEnd, setTouchEnd] = useState<number | null>(null);

  // Fetch performers data
  useEffect(() => {
    const loadPerformers = async () => {
      try {
        const data = await fetchPerformersByAuditionId(auditionId);
        setPerformers(data);
      } catch (error) {
        console.error('Error loading performers:', error);
      } finally {
        setLoading(false);
      }
    };

    loadPerformers();
  }, [auditionId]);

  // Handle swipe gestures
  const handleTouchStart = (e: React.TouchEvent) => {
    setTouchStart(e.targetTouches[0].clientY);
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    setTouchEnd(e.targetTouches[0].clientY);
  };

  const handleTouchEnd = () => {
    if (!touchStart || !touchEnd) return;
    
    const distance = touchStart - touchEnd;
    const isSwipeDown = distance < -50;
    const isSwipeUp = distance > 50;
    
    if (isSwipeUp && currentIndex < performers.length - 1) {
      setCurrentIndex(currentIndex + 1);
    } else if (isSwipeDown && currentIndex > 0) {
      setCurrentIndex(currentIndex - 1);
    }
    
    setTouchStart(null);
    setTouchEnd(null);
  };

  // Handle wheel/scroll events
  const handleWheel = (e: React.WheelEvent) => {
    if (e.deltaY > 0 && currentIndex < performers.length - 1) {
      setCurrentIndex(currentIndex + 1);
    } else if (e.deltaY < 0 && currentIndex > 0) {
      setCurrentIndex(currentIndex - 1);
    }
  };

  // Navigate to next/previous reel
  const goToNextReel = () => {
    if (currentIndex < performers.length - 1) {
      setCurrentIndex(currentIndex + 1);
    }
  };

  const goToPrevReel = () => {
    if (currentIndex > 0) {
      setCurrentIndex(currentIndex - 1);
    }
  };

  // Handle keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowDown' || e.key === 'j') {
        goToNextReel();
      } else if (e.key === 'ArrowUp' || e.key === 'k') {
        goToPrevReel();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [currentIndex, performers.length]);

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a] flex items-center justify-center">
        <div className="flex flex-col items-center">
          <div className="w-16 h-16 border-4 border-t-[#00f5d4] border-r-[#00f5d4] border-b-[#ff6b6b] border-l-[#ff6b6b] rounded-full animate-spin"></div>
          <p className="mt-4 text-white text-lg">Loading performers...</p>
        </div>
      </div>
    );
  }

  if (performers.length === 0) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a] flex items-center justify-center p-4">
        <div className="text-center">
          <Image
            src={logo}
            alt="MusicStrk Logo"
            width={200}
            className="mx-auto mb-6"
          />
          <h2 className="text-[#00f5d4] text-2xl font-bold mb-4">No performers found</h2>
          <p className="text-white mb-6">There are no performers registered for this audition yet.</p>
          <Link 
            href={`/audition/${auditionId}`}
            className="inline-block bg-[#ff6b6b] text-black font-bold px-6 py-3 rounded-full hover:bg-[#00f5d4] transition-colors"
          >
            Back to Audition
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div 
      ref={containerRef}
      className="min-h-screen bg-gradient-to-br from-[#0a0a2a] via-[#1a1a3a] to-[#2a2a4a] overflow-hidden"
      onWheel={handleWheel}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
    >
      {/* Header with back button and progress indicator */}
      <div className="absolute top-0 left-0 right-0 z-50 px-4 py-3 flex items-center justify-between bg-gradient-to-b from-[#0a0a2a] to-transparent">
        <Link 
          href={`/audition/${auditionId}`}
          className="flex items-center text-[#00f5d4] hover:text-[#ff6b6b] transition-colors"
        >
          <ArrowLeft className="mr-1" />
          <span>Back</span>
        </Link>
        <div className="flex items-center space-x-1">
          {performers.map((_, index) => (
            <div 
              key={index}
              className={`h-1 rounded-full ${
                index === currentIndex ? 'w-6 bg-[#00f5d4]' : 'w-2 bg-gray-500'
              } transition-all`}
            />
          ))}
        </div>
        <div className="text-white text-sm">
          {currentIndex + 1}/{performers.length}
        </div>
      </div>

      {/* Reels container with vertical swipe */}
      <div className="relative h-screen w-full">
        {performers.map((performer, index) => (
          <motion.div
            key={performer.id}
            className="absolute inset-0 w-full h-full"
            initial={{ opacity: 0 }}
            animate={{ 
              opacity: index === currentIndex ? 1 : 0,
              y: `${(index - currentIndex) * 100}%`
            }}
            transition={{ 
              opacity: { duration: 0.3 },
              y: { type: "spring", stiffness: 300, damping: 30 }
            }}
          >
            <PerformerReel 
              performer={performer} 
              isActive={index === currentIndex} 
            />
          </motion.div>
        ))}
      </div>

      {/* Navigation controls */}
      <div className="absolute right-4 top-1/2 transform -translate-y-1/2 z-50 flex flex-col space-y-2">
        <button
          onClick={goToPrevReel}
          disabled={currentIndex === 0}
          className={`p-2 rounded-full ${
            currentIndex === 0 
              ? 'bg-gray-700 text-gray-500 cursor-not-allowed' 
              : 'bg-[#1a1a3a] text-[#00f5d4] hover:bg-[#00f5d4] hover:text-black'
          } transition-colors`}
        >
          <ChevronUp />
        </button>
        <button
          onClick={goToNextReel}
          disabled={currentIndex === performers.length - 1}
          className={`p-2 rounded-full ${
            currentIndex === performers.length - 1 
              ? 'bg-gray-700 text-gray-500 cursor-not-allowed' 
              : 'bg-[#1a1a3a] text-[#00f5d4] hover:bg-[#00f5d4] hover:text-black'
          } transition-colors`}
        >
          <ChevronDown />
        </button>
      </div>

      {/* Swipe instruction for mobile */}
      <div className="absolute bottom-4 left-1/3 transform -translate-x-1/2 z-40 text-white text-xs bg-[#1a1a3a]/80 px-3 py-1 rounded-full flex items-center">
        <ChevronUp className="w-4 h-4 mr-1" />
        <span>Swipe to navigate</span>
        <ChevronDown className="w-4 h-4 ml-1" />
      </div>
    </div>
  );
}