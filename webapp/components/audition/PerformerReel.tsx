'use client';

import React, { useRef, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Performer } from '@/utils/mocks/performers';
import { 
  ChevronUp, 
  ChevronDown, 
  ThumbsUp, 
  User, 
  Music, 
  TrendingUp, 
  Star, 
  Mic, 
  Volume2
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';

interface PerformerReelProps {
  performer: Performer;
  isActive: boolean;
}

const PerformerReel: React.FC<PerformerReelProps> = ({ performer, isActive }) => {
  const { toast } = useToast();
  const [showDetails, setShowDetails] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const [isVoting, setIsVoting] = useState(false);
  
  // Function to handle voting
  const handleVote = () => {
    setIsVoting(true);
    setTimeout(() => {
      setIsVoting(false);
      toast({
        title: "Vote Recorded! 🎵",
        description: `You voted for ${performer.name}`,
      });
    }, 1000);
  };

  // Function to animate the audio level bars randomly
  const AudioLevelBars = () => {
    const bars = Array.from({ length: 10 }, (_, i) => {
      const height = isActive ? Math.floor(Math.random() * 80) + 20 : 10;
      return (
        <div 
          key={i} 
          className="w-1 mx-px bg-[#00f5d4]" 
          style={{ 
            height: `${height}%`,
            transition: 'height 0.2s ease-in-out',
          }}
        />
      );
    });
    
    return (
      <div className="absolute bottom-28 left-4 h-24 flex items-end space-x-1">
        {bars}
      </div>
    );
  };

  // Create visual representation of personality scales
  const PersonalityScaleBars = () => {
    if (!performer.personalityScale) return null;
    
    const scales = [
      { name: 'Vocal Strength', value: performer.personalityScale.vocalStrength, icon: <Mic className="w-4 h-4" /> },
      { name: 'Charisma', value: performer.personalityScale.charisma, icon: <Star className="w-4 h-4" /> },
      { name: 'Stage Presence', value: performer.personalityScale.stagePresence, icon: <TrendingUp className="w-4 h-4" /> },
      { name: 'Originality', value: performer.personalityScale.originality, icon: <Music className="w-4 h-4" /> },
      { name: 'Technical Skill', value: performer.personalityScale.technicalSkill, icon: <Volume2 className="w-4 h-4" /> },
    ];
    
    return (
      <div className="space-y-2 mt-4">
        {scales.map((scale) => (
          <div key={scale.name} className="flex items-center mb-1">
            <div className="flex items-center w-32 text-xs">
              {scale.icon}
              <span className="ml-1">{scale.name}</span>
            </div>
            <div className="flex-1 h-2 bg-gray-700 rounded-full overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-[#00f5d4] to-[#ff6b6b]"
                style={{ width: `${scale.value}%` }}
              />
            </div>
            <span className="ml-2 text-xs">{scale.value}</span>
          </div>
        ))}
      </div>
    );
  };

  return (
    <div
      ref={containerRef}
      className={`relative w-full h-full flex flex-col overflow-hidden ${isActive ? 'z-10' : 'z-0'}`}
    >
      {/* Video container with retro DAW UI frame */}
      <div className="relative flex-1 bg-[#1a1a3a] border-2 border-[#00f5d4] rounded-lg overflow-hidden">
        {/* TikTok embed */}
        <div className="absolute inset-0 w-full h-full flex items-center justify-center">
          {isActive && (
            <iframe
              src={performer.tiktokAuditionUrl}
              className="absolute inset-0 w-full h-full"
              allowFullScreen
              allow="autoplay"
            />
          )}
        </div>
        
        {/* DAW style overlay elements */}
        <div className="absolute top-0 left-0 right-0 p-3 bg-gradient-to-b from-[#0a0a2a]/80 to-transparent flex items-center justify-between z-10">
          <div className="flex items-center">
            <div className="w-10 h-10 rounded-full overflow-hidden border-2 border-[#00f5d4] mr-2 mt-10">
              {performer.profileImageUrl ? (
                <img src={performer.profileImageUrl} alt={performer.name} className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full bg-[#ff6b6b] flex items-center justify-center">
                  <User className="text-white" />
                </div>
              )}
            </div>
            <div>
              <h3 className="text-white font-bold text-lg">{performer.name}</h3>
              <div className="flex items-center text-xs text-[#00f5d4]">
                <Music className="w-3 h-3 mr-1" />
                <span>{performer.genre || 'Artist'}</span>
              </div>
            </div>
          </div>
          <div 
            className="py-1 px-3 bg-[#ff6b6b] rounded-full text-xs font-bold text-black cursor-pointer hover:bg-[#00f5d4] transition-colors"
            onClick={() => setShowDetails(!showDetails)}
          >
            {showDetails ? 'Hide' : 'Details'}
          </div>
        </div>
        
        {/* Audio level visualization */}
        <AudioLevelBars />
        
        {/* Vote button and social links */}
        <div className="absolute bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-[#0a0a2a]/80 to-transparent z-10">
          <AnimatePresence>
            {showDetails && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                className="bg-[#1a1a3a]/80 backdrop-blur-sm p-3 rounded-lg mb-4"
              >
                <h4 className="text-[#00f5d4] font-bold mb-2">Performance Metrics</h4>
                <PersonalityScaleBars />
                <div className="mt-3 flex space-x-2">
                  <a 
                    href={performer.tiktokProfileUrl} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="text-xs text-white bg-[#1a1a3a] px-2 py-1 rounded hover:bg-[#00f5d4] hover:text-black transition-colors"
                  >
                    TikTok
                  </a>
                  
                  <a 
                    href={performer.socialX} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="text-xs text-white bg-[#1a1a3a] px-2 py-1 rounded hover:bg-[#00f5d4] hover:text-black transition-colors"
                  >
                    Twitter
                  </a>
                  <span className="text-xs text-white bg-[#1a1a3a] px-2 py-1 rounded">
                    Wallet: {`${performer.walletAddress.substring(0, 6)}...${performer.walletAddress.substring(performer.walletAddress.length - 4)}`}
                  </span>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
          
          <Button 
            onClick={handleVote}
            disabled={isVoting}
            className={`w-full py-3 ${isVoting 
              ? 'bg-gray-500' 
              : 'bg-gradient-to-r from-[#00f5d4] to-[#ff6b6b] hover:from-[#ff6b6b] hover:to-[#00f5d4]'} 
              text-black font-bold rounded-full transition-all transform hover:scale-105`}
          >
            {isVoting ? 'Recording Vote...' : (
              <div className="flex items-center justify-center">
                <ThumbsUp className="mr-2" />
                Vote for {performer.name}
              </div>
            )}
          </Button>
        </div>
      </div>
    </div>
  );
};

export default PerformerReel;