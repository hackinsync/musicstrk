"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import {
  useAnimationFrame,
  useMotionValue,
  type MotionValue,
} from "framer-motion";
import { InfiniteBanner } from "./infinite-banner";
import { ReelThumbnail } from "./reel-thumbnail";
import { Camera, CameraTarget } from "./camera";

// Define proper types for the camera and target
interface CameraContextType {
  motionValues: {
    posX: MotionValue<number>;
    posY: MotionValue<number>;
    zoom: MotionValue<number>;
    rotation: MotionValue<number>;
  };
  panTo: (position: { x: number; y: number }) => void;
  setZoom: (zoomValue: number) => void;
  setRotation: (rotationValue: number) => void;
  follow: (target: CameraTargetType) => void;
  unfollow: (target: CameraTargetType) => void;
}

interface CameraTargetType {
  el: HTMLElement | null;
  camera: CameraContextType;
}

// Define type for reel items
interface ReelItem {
  id: number;
  title: string;
  artist: string;
  image: string;
  color: string;
}

// Sample reel data - in a real app, this would come from an API
const reelItems: ReelItem[] = [
  {
    id: 1,
    title: "Electronic Beat",
    artist: "WaveMaker",
    image: "/reel-image.jpg",
    color: "#00E5FF",
  },
  {
    id: 2,
    title: "Trap Fusion",
    artist: "BeatCrafter",
    image: "/reel-image.jpg",
    color: "#FF3D71",
  },
  {
    id: 3,
    title: "Lo-Fi Chill",
    artist: "MelodyMind",
    image: "/reel-image.jpg",
    color: "#0095FF",
  },
  {
    id: 4,
    title: "Synth Wave",
    artist: "RetroBeats",
    image: "/reel-image.jpg",
    color: "#00D68F",
  },
  {
    id: 5,
    title: "Drum & Bass",
    artist: "RhythmRunner",
    image: "/reel-image.jpg",
    color: "#FFE700",
  },
];

const reelItems2: ReelItem[] = [
  {
    id: 6,
    title: "Jazz Fusion",
    artist: "SmoothTones",
    image: "/reel-image.jpg",
    color: "#FF3D71",
  },
  {
    id: 7,
    title: "Classical Remix",
    artist: "TimelessBeats",
    image: "/reel-image.jpg",
    color: "#00D68F",
  },
  {
    id: 8,
    title: "Indie Folk",
    artist: "AcousticSoul",
    image: "/reel-image.jpg",
    color: "#FFE700",
  },
  {
    id: 9,
    title: "Metal Core",
    artist: "HeavyRiffs",
    image: "/reel-image.jpg",
    color: "#0095FF",
  },
  {
    id: 10,
    title: "Ambient Space",
    artist: "CosmicSounds",
    image: "/reel-image.jpg",
    color: "#00E5FF",
  },
];

// Define return type for useClock hook
interface ClockHook {
  value: MotionValue<number>;
  stop: () => void;
  start: () => void;
}

// Define options type for useClock
interface ClockOptions {
  defaultValue?: number;
  reverse?: boolean;
  speed?: number;
}

// Custom hook for the clock functionality with performance optimizations
function useClock({
  defaultValue = 0,
  reverse = false,
  speed = 1,
}: ClockOptions = {}): ClockHook {
  const clock = useMotionValue(defaultValue);
  const pausedRef = useRef(false);

  useAnimationFrame((_, delta) => {
    if (pausedRef.current) return;

    // Use requestAnimationFrame for smoother animation
    requestAnimationFrame(() => {
      if (reverse) {
        clock.set(clock.get() - delta * speed);
      } else {
        clock.set(clock.get() + delta * speed);
      }
    });
  });

  const stop = useCallback(() => {
    pausedRef.current = true;
  }, []);

  const start = useCallback(() => {
    pausedRef.current = false;
  }, []);

  return {
    value: clock,
    stop,
    start,
  };
}

export function ReelBannerEffect() {
  const [activeTarget, setActiveTarget] = useState<CameraTargetType | null>(
    null
  );
  const cameraRef = useRef<CameraContextType | null>(null);

  // Memoize clock instances to prevent unnecessary re-renders
  const clock1 = useClock({ defaultValue: Date.now() });
  const clock2 = useClock({ defaultValue: Date.now(), reverse: true });

  // Handle target click with useCallback to prevent unnecessary re-renders
  const handleTargetClick = useCallback((target: CameraTargetType) => {
    setActiveTarget((prev) => (prev !== target ? target : null));
  }, []);

  useEffect(() => {
    if (!cameraRef.current) return;

    if (activeTarget) {
      // Enhanced zoom effect with slightly different parameters for a more dynamic feel
      cameraRef.current.follow(activeTarget);
      cameraRef.current.setZoom(2.2); // Slightly less zoom for better visibility
      cameraRef.current.setRotation(0);
      clock1.stop();
      clock2.stop();
    } else {
      cameraRef.current.panTo({ x: 0, y: 0 });
      cameraRef.current.setZoom(1);
      cameraRef.current.setRotation(-5);
      clock1.start();
      clock2.start();
    }

    return () => {
      if (activeTarget && cameraRef.current) {
        cameraRef.current.unfollow(activeTarget);
      }
    };
  }, [activeTarget, clock1, clock2]);

  // Adjust speeds for smoother scrolling
  const firstBannerSpeed = 0.8;
  const secondBannerSpeed = 0.65;

  return (
    <Camera ref={cameraRef} className="w-full h-full">
      <div className="flex flex-col items-center justify-center gap-12 transform scale-110">
        <InfiniteBanner
          clock={clock1.value}
          loopDuration={30000 / firstBannerSpeed}
          className="pr-12" // Add extra padding to ensure right-side cards are visible
        >
          <div className="flex gap-8 pr-8">
            {reelItems.map((item) => (
              <CameraTarget key={item.id} onClick={handleTargetClick}>
                <ReelThumbnail
                  title={item.title}
                  artist={item.artist}
                  image={item.image}
                  color={item.color}
                />
              </CameraTarget>
            ))}
          </div>
        </InfiniteBanner>

        <InfiniteBanner
          clock={clock2.value}
          loopDuration={25000 / secondBannerSpeed}
          className="pr-12" // Add extra padding to ensure right-side cards are visible
        >
          <div className="flex gap-8 pr-8">
            {reelItems2.map((item) => (
              <CameraTarget key={item.id} onClick={handleTargetClick}>
                <ReelThumbnail
                  title={item.title}
                  artist={item.artist}
                  image={item.image}
                  color={item.color}
                />
              </CameraTarget>
            ))}
          </div>
        </InfiniteBanner>
      </div>
    </Camera>
  );
}
