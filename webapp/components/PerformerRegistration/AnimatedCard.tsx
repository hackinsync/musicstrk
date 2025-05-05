import React from "react"
import { motion } from "framer-motion"

interface AnimatedCardProps {
  children: React.ReactNode
  step: number
}

export function AnimatedCard({ children, step }: AnimatedCardProps) {
  // Animation variants
  const cardVariants = {
    hidden: { opacity: 0, y: 20 },
    visible: { opacity: 1, y: 0, transition: { duration: 0.5 } },
    exit: { opacity: 0, y: -20, transition: { duration: 0.3 } },
  }

  return (
    <motion.div
      key={step}
      initial="hidden"
      animate="visible"
      exit="exit"
      variants={cardVariants}
      className="w-full max-w-md"
    >
      {children}
    </motion.div>
  )
}