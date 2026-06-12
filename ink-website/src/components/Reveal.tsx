import type { ElementType, ReactNode } from 'react'
import { useReveal } from '../lib/useReveal'

type RevealProps = {
  children: ReactNode
  /** Stagger step (0–6). Each step adds ~90ms to the transition delay. */
  delay?: number
  /** Element/component to render as. Defaults to a div. */
  as?: ElementType
  className?: string
  id?: string
}

/**
 * Wraps content so it fades + rises gently into view the first time it scrolls
 * into the viewport. Subtle by design (~16px travel, soft easing) and a no-op
 * for users who prefer reduced motion (handled in useReveal + CSS).
 */
export function Reveal({ children, delay = 0, as, className = '', id }: RevealProps) {
  const Tag = (as ?? 'div') as ElementType
  const { ref, visible } = useReveal<HTMLElement>()
  const delayClass = delay > 0 ? `reveal-delay-${Math.min(delay, 6)}` : ''

  return (
    <Tag
      ref={ref}
      id={id}
      className={`reveal ${visible ? 'reveal-visible' : ''} ${delayClass} ${className}`.trim()}
    >
      {children}
    </Tag>
  )
}
