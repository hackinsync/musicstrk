"use client";

import {
  motion,
  type MotionValue,
  useMotionTemplate,
  useTransform,
} from "framer-motion";
import type { ReactNode } from "react";

interface InfiniteBannerProps {
  clock: MotionValue<number>;
  loopDuration?: number;
  children: ReactNode;
  className?: string;
}

export function InfiniteBanner({
  clock,
  loopDuration = 20000,
  children,
  className = "",
}: InfiniteBannerProps) {
  const progress = useTransform(
    clock,
    (time) => (time % loopDuration) / loopDuration
  );

  const percentage = useTransform(progress, (t) => t * 100);
  const translateX = useMotionTemplate`-${percentage}%`;

  return (
    <div className={`relative w-max ${className}`}>
      <motion.div
        style={{
          translateX,
          width: "max-content",
          willChange: "transform",
        }}
      >
        <div>{children}</div>
        <div
          style={{
            position: "absolute",
            height: "100%",
            width: "100%",
            left: "100%",
            top: 0,
          }}
        >
          {children}
        </div>
      </motion.div>
    </div>
  );
}
