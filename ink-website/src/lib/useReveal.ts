import { useEffect, useRef, useState } from 'react'

const prefersReducedMotion = () =>
  typeof window !== 'undefined' &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches

/** Reveal once the element's top is within this fraction of the viewport height. */
const TRIGGER_RATIO = 0.88

/**
 * Reveal-on-scroll hook. Returns a ref to attach to an element and a `visible`
 * flag that flips true once the element scrolls into view — and stays true
 * (fade-in only; it never fades back out).
 *
 * Uses rAF-throttled position sampling rather than IntersectionObserver: an
 * observer can miss short elements during fast scrolls or anchor jumps (the
 * intersection ratio goes 0→0 and the callback never fires), leaving content
 * stuck invisible. Sampling the element's rect can't skip. When the user
 * prefers reduced motion, content starts visible and nothing is observed.
 */
export function useReveal<T extends HTMLElement = HTMLDivElement>() {
  const ref = useRef<T>(null)
  const [visible, setVisible] = useState(() => prefersReducedMotion())

  useEffect(() => {
    if (prefersReducedMotion()) return
    const el = ref.current
    if (!el) return

    let raf = 0

    const cleanup = () => {
      window.removeEventListener('scroll', onScroll)
      window.removeEventListener('resize', onScroll)
      if (raf) cancelAnimationFrame(raf)
    }

    const check = () => {
      raf = 0
      const rect = el.getBoundingClientRect()
      const vh = window.innerHeight
      // top < trigger line → reaching view (top < 0 covers already-scrolled-past);
      // bottom <= vh → fully on screen, which catches the last element at page end
      // where the top can never reach the trigger line because scrolling bottoms out.
      if (rect.top < vh * TRIGGER_RATIO || rect.bottom <= vh) {
        setVisible(true)
        cleanup()
      }
    }

    const onScroll = () => {
      if (!raf) raf = requestAnimationFrame(check)
    }

    window.addEventListener('scroll', onScroll, { passive: true })
    window.addEventListener('resize', onScroll, { passive: true })
    // Initial check on next frame (avoids a synchronous setState in the effect body).
    raf = requestAnimationFrame(check)

    return cleanup
  }, [])

  return { ref, visible }
}
