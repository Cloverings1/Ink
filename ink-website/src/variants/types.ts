export type HeroLayout = 'centered' | 'split' | 'minimal' | 'roadmap-first' | 'spotlight'
export type FeatureLayout = 'grid' | 'bento' | 'list' | 'compact'
export type NavStyle = 'glass' | 'minimal' | 'bordered' | 'floating'
export type ButtonStyle = 'pill' | 'square' | 'ghost'
export type Accent = 'red' | 'white' | 'emerald' | 'blue' | 'violet' | 'cyan' | 'amber' | 'gold'

export type VariantConfig = {
  id: number
  slug: string
  name: string
  tagline: string
  accent: Accent
  heroLayout: HeroLayout
  featureLayout: FeatureLayout
  navStyle: NavStyle
  buttonStyle: ButtonStyle
  shell: string
  backdrop?: string
  font?: 'sans' | 'mono' | 'mixed'
  radius: 'none' | 'md' | 'xl' | 'full'
  showGrid?: boolean
  showNoise?: boolean
  showMesh?: boolean
}

export const accentClasses: Record<
  Accent,
  { text: string; bg: string; border: string; glow: string; dot: string; kbd: string }
> = {
  red: {
    text: 'text-ink-red',
    bg: 'bg-ink-red',
    border: 'border-ink-red/35',
    glow: 'bg-ink-red/20',
    dot: 'bg-ink-red shadow-[0_0_8px_#ff4b4b]',
    kbd: 'text-[#ffb4b4] border-ink-red/35 bg-ink-red/15',
  },
  white: {
    text: 'text-white',
    bg: 'bg-white',
    border: 'border-white/30',
    glow: 'bg-white/10',
    dot: 'bg-white shadow-[0_0_8px_#ffffff]',
    kbd: 'text-white border-white/20 bg-white/10',
  },
  emerald: {
    text: 'text-emerald-400',
    bg: 'bg-emerald-500',
    border: 'border-emerald-500/35',
    glow: 'bg-emerald-500/15',
    dot: 'bg-emerald-400 shadow-[0_0_8px_#34d399]',
    kbd: 'text-emerald-200 border-emerald-500/30 bg-emerald-500/10',
  },
  blue: {
    text: 'text-blue-400',
    bg: 'bg-blue-500',
    border: 'border-blue-500/35',
    glow: 'bg-blue-500/15',
    dot: 'bg-blue-400 shadow-[0_0_8px_#60a5fa]',
    kbd: 'text-blue-200 border-blue-500/30 bg-blue-500/10',
  },
  violet: {
    text: 'text-violet-400',
    bg: 'bg-violet-500',
    border: 'border-violet-500/35',
    glow: 'bg-violet-500/15',
    dot: 'bg-violet-400 shadow-[0_0_8px_#a78bfa]',
    kbd: 'text-violet-200 border-violet-500/30 bg-violet-500/10',
  },
  cyan: {
    text: 'text-cyan-400',
    bg: 'bg-cyan-500',
    border: 'border-cyan-500/35',
    glow: 'bg-cyan-500/15',
    dot: 'bg-cyan-400 shadow-[0_0_8px_#22d3ee]',
    kbd: 'text-cyan-200 border-cyan-500/30 bg-cyan-500/10',
  },
  amber: {
    text: 'text-amber-400',
    bg: 'bg-amber-500',
    border: 'border-amber-500/35',
    glow: 'bg-amber-500/15',
    dot: 'bg-amber-400 shadow-[0_0_8px_#fbbf24]',
    kbd: 'text-amber-200 border-amber-500/30 bg-amber-500/10',
  },
  gold: {
    text: 'text-yellow-300',
    bg: 'bg-yellow-500',
    border: 'border-yellow-500/35',
    glow: 'bg-yellow-500/15',
    dot: 'bg-yellow-300 shadow-[0_0_8px_#fde047]',
    kbd: 'text-yellow-100 border-yellow-500/30 bg-yellow-500/10',
  },
}

export const radiusMap = {
  none: 'rounded-none',
  md: 'rounded-lg',
  xl: 'rounded-2xl',
  full: 'rounded-full',
}
