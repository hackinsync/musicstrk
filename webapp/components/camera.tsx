"use client";

import React, {
  forwardRef,
  useContext,
  useImperativeHandle,
  useRef,
  useState,
  useCallback,
} from "react";
import {
  motion,
  useMotionValue,
  useTransform,
  animate,
  type MotionValue,
} from "framer-motion";

// Define proper types for the camera context
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

// Define the target type
interface CameraTargetType {
  el: HTMLElement | null;
  camera: CameraContextType;
}

// Camera context with proper typing
const CameraContext = React.createContext<CameraContextType | null>(null);

export const useCamera = () => {
  const camera = useContext(CameraContext);
  if (!camera) {
    throw new Error("useCamera must be used within a Camera component");
  }
  return camera;
};

// Vector utility class
class Vector {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }

  add(other: Vector | { x: number; y: number }) {
    this.x += other.x;
    this.y += other.y;
    return this;
  }

  sub(other: Vector | { x: number; y: number }) {
    this.x -= other.x;
    this.y -= other.y;
    return this;
  }

  multiplyScalar(factor: number) {
    this.x *= factor;
    this.y *= factor;
    return this;
  }

  clone() {
    return new Vector(this.x, this.y);
  }
}

// Enhanced spring animation configurations
const ZOOM_SPRING = {
  type: "spring" as const,
  damping: 20,
  stiffness: 90,
  mass: 0.8,
  restDelta: 0.001,
};

const PAN_SPRING = {
  type: "spring" as const,
  damping: 28,
  stiffness: 180,
  mass: 0.6,
  restDelta: 0.001,
};

const ROTATION_SPRING = {
  type: "spring" as const,
  damping: 22,
  stiffness: 100,
  mass: 0.7,
  restDelta: 0.001,
};

// Camera component
interface CameraProps {
  children: React.ReactNode;
  className?: string;
}

export const Camera = forwardRef<CameraContextType, CameraProps>(
  ({ children, className = "" }, ref) => {
    const containerRef = useRef<HTMLDivElement>(null);
    const contentRef = useRef<HTMLDivElement>(null);
    const followingRef = useRef<{
      target: CameraTargetType;
      interval: NodeJS.Timeout;
    } | null>(null);

    // Create motion values directly using the hook
    const posX = useMotionValue(0);
    const posY = useMotionValue(0);
    const zoom = useMotionValue(1);
    const rotation = useMotionValue(0);

    // Define camera methods at the top level of the component
    const panTo = useCallback(
      (position: { x: number; y: number }) => {
        void animate(posX.get(), position.x, {
          ...PAN_SPRING,
          onUpdate: (v) => posX.set(v),
        });
        void animate(posY.get(), position.y, {
          ...PAN_SPRING,
          onUpdate: (v) => posY.set(v),
        });
      },
      [posX, posY]
    );

    const setZoom = useCallback(
      (zoomValue: number) => {
        void animate(zoom.get(), zoomValue, {
          ...ZOOM_SPRING,
          onUpdate: (v) => zoom.set(v),
        });
      },
      [zoom]
    );

    const setRotation = useCallback(
      (rotationValue: number) => {
        void animate(rotation.get(), rotationValue, {
          ...ROTATION_SPRING,
          onUpdate: (v) => rotation.set(v),
        });
      },
      [rotation]
    );

    const unfollow = useCallback((target: CameraTargetType) => {
      if (followingRef.current?.target === target) {
        clearInterval(followingRef.current.interval);
        followingRef.current = null;
      }
    }, []);

    const follow = useCallback(
      (target: CameraTargetType) => {
        if (followingRef.current) {
          clearInterval(followingRef.current.interval);
          followingRef.current = null;
        }

        const panToTarget = () => {
          if (!target.el) return;
          const rect = target.el.getBoundingClientRect();
          const containerRect = containerRef.current?.getBoundingClientRect();

          if (!containerRect) return;

          const targetCenter = {
            x: rect.left + rect.width / 2,
            y: rect.top + rect.height / 2,
          };

          const containerCenter = {
            x: containerRect.left + containerRect.width / 2,
            y: containerRect.top + containerRect.height / 2,
          };

          const targetOffset = new Vector(
            targetCenter.x - containerCenter.x,
            targetCenter.y - containerCenter.y
          ).multiplyScalar(1 / zoom.get());

          const position = new Vector(posX.get(), posY.get()).add(targetOffset);

          panTo(position);
        };

        panToTarget();
        followingRef.current = {
          target,
          interval: setInterval(panToTarget, 100),
        };
      },
      [posX, posY, zoom, panTo]
    );

    // Create camera object with methods
    const camera: CameraContextType = {
      motionValues: {
        posX,
        posY,
        zoom,
        rotation,
      },
      panTo,
      setZoom,
      setRotation,
      follow,
      unfollow,
    };

    useImperativeHandle(ref, () => camera);

    // Fix the type issue with useTransform by providing explicit type parameters
    const translate = useTransform<[number, number], string>(
      [posX, posY] as [MotionValue<number>, MotionValue<number>],
      ([x, y]) => `${-x}px ${-y}px`
    );

    const transformOrigin = useTransform<[number, number], string>(
      [posX, posY] as [MotionValue<number>, MotionValue<number>],
      ([x, y]) => `calc(50% + ${x}px) calc(50% + ${y}px)`
    );

    return (
      <CameraContext.Provider value={camera}>
        <motion.div
          ref={containerRef}
          className={`overflow-visible ${className}`}
          style={{ willChange: "transform" }}
        >
          <motion.div
            ref={contentRef}
            className="w-full h-full"
            style={{
              translate,
              transformOrigin,
              scale: zoom,
              rotate: rotation,
              willChange: "transform",
            }}
          >
            {children}
          </motion.div>
        </motion.div>
      </CameraContext.Provider>
    );
  }
);

Camera.displayName = "Camera";

// CameraTarget component
interface CameraTargetProps {
  children: React.ReactNode;
  onClick?: (target: CameraTargetType) => void;
  className?: string;
}

export const CameraTarget = forwardRef<CameraTargetType, CameraTargetProps>(
  ({ children, onClick, className = "" }, ref) => {
    const targetRef = useRef<HTMLDivElement>(null);
    const camera = useCamera();

    const [target] = useState<CameraTargetType>(() => ({
      el: null as HTMLElement | null,
      camera,
    }));

    useImperativeHandle(ref, () => target);

    React.useEffect(() => {
      target.el = targetRef.current;
    }, [target]);

    const handleClick = useCallback(() => {
      if (onClick) {
        onClick(target);
      }
    }, [onClick, target]);

    return (
      <div
        ref={targetRef}
        className={className}
        onClick={handleClick}
        style={{ willChange: "transform" }}
      >
        {children}
      </div>
    );
  }
);

CameraTarget.displayName = "CameraTarget";
