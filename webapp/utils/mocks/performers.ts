// utils/mocks/performers.ts
export interface Performer {
  id: string;
  name: string;
  tiktokAuditionUrl: string;
  tiktokProfileUrl: string;
  socialX: string;
  walletAddress: string;
  auditionId: string;
  profileImageUrl?: string;
  genre?: string;
  personalityScale?: {
    vocalStrength: number;
    charisma: number;
    stagePresence: number;
    originality: number;
    technicalSkill: number;
  };
}

export const mockPerformers: { [auditionId: string]: Performer[] } = {
  "audition-123": [
    {
      id: "perf-1",
      name: "Jazz Phoenix",
      tiktokAuditionUrl: "https://www.tiktok.com/embed/7252868416219212075",
      tiktokProfileUrl: "https://www.tiktok.com/@jazzphoenix",
      socialX: "https://x.com/jazzphoenix",
      walletAddress: "0x1234...5678",
      auditionId: "audition-123",
      profileImageUrl: "https://randomuser.me/api/portraits/women/1.jpg",
      genre: "Jazz / Soul",
      personalityScale: {
        vocalStrength: 85,
        charisma: 92,
        stagePresence: 78,
        originality: 88,
        technicalSkill: 90
      }
    },
    {
      id: "perf-2",
      name: "Rock Maverick",
      tiktokAuditionUrl: "https://www.tiktok.com/embed/7276193906411578654",
      tiktokProfileUrl: "https://www.tiktok.com/@rockmaverick",
      socialX: "https://x.com/rockmaverick",
      walletAddress: "0x9876...5432",
      auditionId: "audition-123",
      profileImageUrl: "https://randomuser.me/api/portraits/men/2.jpg",
      genre: "Rock",
      personalityScale: {
        vocalStrength: 92,
        charisma: 85,
        stagePresence: 90,
        originality: 75,
        technicalSkill: 82
      }
    },
    {
      id: "perf-3",
      name: "Electro Sync",
      tiktokAuditionUrl: "https://www.tiktok.com/embed/7278777035228481829",
      tiktokProfileUrl: "https://www.tiktok.com/@electrosync",
      socialX: "https://x.com/electrosync",
      walletAddress: "0x2468...1357",
      auditionId: "audition-123",
      profileImageUrl: "https://randomuser.me/api/portraits/women/3.jpg",
      genre: "Electronic",
      personalityScale: {
        vocalStrength: 75,
        charisma: 88,
        stagePresence: 82,
        originality: 95,
        technicalSkill: 89
      }
    },
    {
      id: "perf-4",
      name: "Hip Hop Maven",
      tiktokAuditionUrl: "https://www.tiktok.com/embed/7281311453955120426",
      tiktokProfileUrl: "https://www.tiktok.com/@hiphopmavenofficial",
      socialX: "https://x.com/hiphopmavenofficial",
      walletAddress: "0x1357...2468",
      auditionId: "audition-123",
      profileImageUrl: "https://randomuser.me/api/portraits/men/4.jpg",
      genre: "Hip Hop",
      personalityScale: {
        vocalStrength: 88,
        charisma: 94,
        stagePresence: 92,
        originality: 85,
        technicalSkill: 80
      }
    },
    {
      id: "perf-5",
      name: "Folk Whisper",
      tiktokAuditionUrl: "https://www.tiktok.com/embed/7283456287654321098",
      tiktokProfileUrl: "https://www.tiktok.com/@folkwhisper",
      socialX: "https://x.com/folkwhisper",
      walletAddress: "0x5432...8765",
      auditionId: "audition-123",
      profileImageUrl: "https://randomuser.me/api/portraits/women/5.jpg",
      genre: "Folk / Acoustic",
      personalityScale: {
        vocalStrength: 80,
        charisma: 75,
        stagePresence: 70,
        originality: 92,
        technicalSkill: 85
      }
    }
  ],
  "audition-456": [
    {
      id: "perf-6",
      name: "Pop Star Rising",
      tiktokAuditionUrl: "https://www.tiktok.com/embed/7285678901234567890",
      tiktokProfileUrl: "https://www.tiktok.com/@popstarrising",
      socialX: "https://x.com/popstarrising",
      walletAddress: "0x3456...7890",
      auditionId: "audition-456",
      profileImageUrl: "https://randomuser.me/api/portraits/women/6.jpg",
      genre: "Pop",
      personalityScale: {
        vocalStrength: 90,
        charisma: 92,
        stagePresence: 88,
        originality: 78,
        technicalSkill: 85
      }
    }
    // Add more performers for this audition as needed
  ]
};

// Helper function to fetch performers by audition ID
export const getPerformersByAuditionId = (auditionId: string): Performer[] => {
  return mockPerformers[auditionId] || [];
};