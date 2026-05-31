import { Link } from 'react-router-dom'
import { features, GITHUB_URL, premiumFeatures, steps } from '../content'
import { GitHubIcon } from '../components/GitHubIcon'
import { Kbd } from '../components/Kbd'
import { PanelMockup } from '../components/PanelMockup'
import { publicAsset } from '../lib/publicAsset'
import type { VariantConfig } from './types'
import { accentClasses, radiusMap } from './types'

function btnClass(config: VariantConfig, primary = true) {
  const r = radiusMap[config.buttonStyle === 'pill' ? 'full' : config.radius === 'none' ? 'none' : 'md']
  if (config.buttonStyle === 'ghost') {
    return `${r} border border-white/15 px-7 py-2.5 text-[14px] font-medium text-zinc-200 transition hover:border-white/30 hover:bg-white/[0.04]`
  }
  if (primary) {
    const accent = accentClasses[config.accent]
    if (config.accent === 'white' || config.buttonStyle === 'square') {
      return `${r} bg-white px-7 py-2.5 text-[14px] font-medium text-black transition hover:bg-zinc-200`
    }
    return `${r} ${accent.bg} px-7 py-2.5 text-[14px] font-medium text-black transition hover:opacity-90`
  }
  return `${r} border border-white/15 px-7 py-2.5 text-[14px] font-medium text-zinc-200 transition hover:border-white/25 hover:bg-white/[0.04]`
}

function Nav({ config }: { config: VariantConfig }) {
  const navClass =
    config.navStyle === 'glass'
      ? 'border-b border-white/[0.06] bg-black/70 backdrop-blur-xl'
      : config.navStyle === 'bordered'
        ? 'border-b-2 border-white/20 bg-black'
        : config.navStyle === 'floating'
          ? 'mx-4 mt-4 max-w-6xl rounded-2xl border border-white/10 bg-white/[0.04] backdrop-blur-xl lg:mx-auto'
          : 'bg-transparent'

  return (
    <header className={`fixed inset-x-0 top-0 z-50 ${config.navStyle === 'floating' ? '' : navClass}`}>
      <nav
        className={`mx-auto flex h-14 max-w-6xl items-center justify-between px-6 ${config.navStyle === 'floating' ? navClass : ''}`}
      >
        <Link to={`/${config.slug}`} className="flex items-center gap-2.5 text-sm font-medium text-zinc-100">
          <img src={publicAsset('ink-icon.png')} alt="" className="h-7 w-7 rounded-lg" width={28} height={28} />
          <span>Ink</span>
          <span className="hidden text-[10px] text-zinc-600 sm:inline">· {config.name}</span>
        </Link>
        <div className="hidden items-center gap-8 text-[13px] text-zinc-400 md:flex">
          <a href="#features" className="transition-colors hover:text-zinc-200">
            Features
          </a>
          <a href="#how" className="transition-colors hover:text-zinc-200">
            How it works
          </a>
          <a href="#pricing" className="transition-colors hover:text-zinc-200">
            Pricing
          </a>
        </div>
        <div className="flex items-center gap-3">
          <Link
            to="/variants"
            className="hidden text-[11px] text-zinc-600 transition hover:text-zinc-400 sm:inline"
          >
            All variants
          </Link>
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="hidden text-[13px] text-zinc-400 transition-colors hover:text-zinc-200 sm:inline"
          >
            GitHub
          </a>
          <a href="#download" className={btnClass(config, true) + ' !px-4 !py-1.5 !text-[13px]'}>
            Get Ink
          </a>
        </div>
      </nav>
    </header>
  )
}

function HeroCopy({ config, className = '' }: { config: VariantConfig; className?: string }) {
  const accent = accentClasses[config.accent]
  const fontClass =
    config.font === 'mono' ? 'font-mono' : config.font === 'mixed' ? 'font-serif' : ''

  return (
    <div className={`${fontClass} ${className}`}>
      <p
        className={`mb-6 inline-flex items-center gap-2 border border-white/10 bg-white/[0.04] px-3 py-1 text-[12px] text-zinc-400 ${radiusMap[config.radius === 'full' ? 'full' : 'md']}`}
      >
        <span className={`h-1.5 w-1.5 rounded-full ${accent.dot}`} />
        macOS 14+ · Plain Markdown · You own every file
      </p>
      <h1
        className={`text-[2.25rem] font-semibold leading-[1.08] tracking-[-0.03em] text-white sm:text-5xl md:text-[3rem] ${config.font === 'mixed' ? 'font-serif md:text-[3.5rem]' : ''}`}
      >
        {config.heroLayout === 'minimal' ? (
          <>Floating notes.</>
        ) : config.heroLayout === 'pricing-first' ? (
          <>
            Ultra Premium.
            <br />
            <span className={accent.text}>$25/month.</span>
          </>
        ) : (
          <>
            Floating notes,
            <br />
            <span className="bg-gradient-to-b from-white to-zinc-500 bg-clip-text text-transparent">
              one keystroke away
            </span>
          </>
        )}
      </h1>
      <p className="mx-auto mt-6 max-w-xl text-[15px] leading-relaxed text-zinc-400 md:text-base">
        {config.heroLayout === 'pricing-first'
          ? 'The full Ink experience — maintained, synced, and polished. Every note still a plain .md file you own.'
          : 'Ink summons a frosted glass panel over any app, any Space, even fullscreen. Capture thoughts in raw Markdown — saved as real .md files on your Mac.'}
      </p>
      <div className="mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
        <a href="#download" className={btnClass(config, true)}>
          Download for macOS
        </a>
        <a href="#pricing" className={btnClass(config, false)}>
          Ultra Premium — $25/mo
        </a>
      </div>
    </div>
  )
}

function SpotlightHero({ config }: { config: VariantConfig }) {
  return (
    <div className="mx-auto max-w-2xl text-center">
      <p className="mb-8 text-[13px] uppercase tracking-[0.25em] text-zinc-500">Press to capture</p>
      <div
        className={`flex items-center gap-3 border border-white/15 bg-white/[0.04] px-5 py-4 text-left shadow-[0_0_80px_-20px_rgba(255,255,255,0.15)] ${radiusMap[config.radius === 'none' ? 'md' : 'full']}`}
      >
        <span className={`text-[12px] ${accentClasses[config.accent].text}`}>⌥⌘N</span>
        <span className="flex-1 text-[15px] text-zinc-500">Capture a thought…</span>
        <span className="text-[11px] text-zinc-600">↵</span>
      </div>
      <p className="mt-8 text-[14px] text-zinc-500">
        Ink appears instantly. Plain Markdown. Files you own.
      </p>
      <div className="mt-8 flex justify-center gap-3">
        <a href="#download" className={btnClass(config, true)}>
          Get Ink
        </a>
        <a href="#pricing" className={btnClass(config, false)}>
          $25/mo
        </a>
      </div>
      <div className="mt-12">
        <PanelMockup accent={config.accent} />
      </div>
    </div>
  )
}

function Hero({ config }: { config: VariantConfig }) {
  const pt = config.navStyle === 'floating' ? 'pt-28' : 'pt-28'

  if (config.heroLayout === 'spotlight') {
    return (
      <section className={`relative overflow-hidden ${pt} pb-12 md:pb-16`}>
        {config.showMesh && <div className="pointer-events-none absolute inset-0 mesh-glow" aria-hidden />}
        <div className="relative z-10 mx-auto max-w-4xl px-6">
          <SpotlightHero config={config} />
        </div>
      </section>
    )
  }

  if (config.heroLayout === 'split') {
    return (
      <section className={`relative overflow-hidden ${pt} pb-12 md:pb-16`}>
        {config.showMesh && <div className="pointer-events-none absolute inset-0 mesh-glow" aria-hidden />}
        <div className="relative z-10 mx-auto grid max-w-6xl items-center gap-12 px-6 lg:grid-cols-2">
          <HeroCopy config={config} className="text-left [&_h1]:text-left [&_p]:mx-0 [&_div]:justify-start" />
          <PanelMockup accent={config.accent} />
        </div>
      </section>
    )
  }

  if (config.heroLayout === 'minimal') {
    return (
      <section className={`relative ${pt} pb-8 md:pt-40 md:pb-12`}>
        <div className="relative z-10 mx-auto max-w-2xl px-6 text-center">
          <HeroCopy config={config} />
        </div>
      </section>
    )
  }

  if (config.heroLayout === 'pricing-first') {
    const accent = accentClasses[config.accent]
    return (
      <section className={`relative overflow-hidden ${pt} pb-12 md:pb-16`}>
        <div className={`pointer-events-none absolute inset-0 ${config.backdrop ?? ''}`} aria-hidden />
        <div className="relative z-10 mx-auto max-w-4xl px-6 text-center">
          <HeroCopy config={config} />
          <div className={`mx-auto mt-12 max-w-sm border p-8 ${accent.border} ${radiusMap[config.radius === 'none' ? 'md' : 'xl']} glass-card`}>
            <p className={`text-[11px] uppercase tracking-widest ${accent.text}`}>Ultra Premium</p>
            <p className="mt-4 text-6xl font-semibold text-white">$25</p>
            <p className="text-zinc-500">/month · cancel anytime</p>
          </div>
          <div className="mt-12">
            <PanelMockup accent={config.accent} />
          </div>
        </div>
      </section>
    )
  }

  return (
    <section className={`relative overflow-hidden ${pt} pb-12 md:pt-36 md:pb-16`}>
      {config.showMesh && <div className="pointer-events-none absolute inset-0 mesh-glow" aria-hidden />}
      <div className="relative z-10 mx-auto max-w-4xl px-6 text-center">
        <HeroCopy config={config} />
        <div className="mt-10 md:mt-12">
          <PanelMockup accent={config.accent} />
        </div>
      </div>
    </section>
  )
}

function Features({ config }: { config: VariantConfig }) {
  const accent = accentClasses[config.accent]
  const cardRadius = radiusMap[config.radius === 'full' ? 'xl' : config.radius]

  const header = (
    <div className={config.featureLayout === 'bento' ? 'max-w-xl' : 'max-w-xl'}>
      <p className="text-[12px] font-medium uppercase tracking-[0.2em] text-zinc-500">Features</p>
      <h2 className="mt-3 text-2xl font-semibold tracking-[-0.02em] text-white md:text-3xl">
        Built for speed, designed for calm
      </h2>
      <p className="mt-4 text-[15px] leading-relaxed text-zinc-400">
        Everything that makes Ink feel native — not another note app fighting for your attention.
      </p>
    </div>
  )

  if (config.featureLayout === 'list') {
    return (
      <section id="features" className="relative border-t border-white/[0.06] py-20 md:py-24">
        <div className="mx-auto max-w-3xl px-6">
          {header}
          <ul className="mt-12 divide-y divide-white/[0.06]">
            {features.map((f) => (
              <li key={f.title} className="flex flex-col gap-2 py-6 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <h3 className={`text-[15px] font-medium text-zinc-100 ${accent.text}`}>{f.title}</h3>
                  <p className="mt-1 max-w-lg text-[13px] leading-relaxed text-zinc-500">{f.description}</p>
                </div>
                {'keys' in f && f.keys && (
                  <div className="flex gap-1">
                    {f.keys.map((k) => (
                      <Kbd key={k}>{k}</Kbd>
                    ))}
                  </div>
                )}
              </li>
            ))}
          </ul>
        </div>
      </section>
    )
  }

  if (config.featureLayout === 'bento') {
    return (
      <section id="features" className="relative border-t border-white/[0.06] py-20 md:py-24">
        <div className="mx-auto max-w-6xl px-6">
          {header}
          <div className="mt-14 grid gap-4 md:grid-cols-4 md:grid-rows-2">
            {features.map((f, i) => (
              <article
                key={f.title}
                className={`glass-card p-6 transition hover:border-white/[0.14] ${cardRadius} ${
                  i === 0 ? 'md:col-span-2 md:row-span-2' : i === 3 ? 'md:col-span-2' : ''
                }`}
              >
                <h3 className="text-[15px] font-medium text-zinc-100">{f.title}</h3>
                <p className="mt-2 text-[13px] leading-relaxed text-zinc-500">{f.description}</p>
              </article>
            ))}
          </div>
        </div>
      </section>
    )
  }

  if (config.featureLayout === 'compact') {
    return (
      <section id="features" className="relative border-t border-white/[0.06] py-16 md:py-20">
        <div className="mx-auto max-w-4xl px-6 text-center">
          <p className="text-[12px] font-medium uppercase tracking-[0.2em] text-zinc-500">Features</p>
          <div className="mt-8 flex flex-wrap justify-center gap-x-8 gap-y-3 text-[13px] text-zinc-400">
            {features.map((f) => (
              <span key={f.title} className="flex items-center gap-2">
                <span className={`h-1 w-1 rounded-full ${accent.bg}`} />
                {f.title}
              </span>
            ))}
          </div>
        </div>
      </section>
    )
  }

  return (
    <section id="features" className="relative border-t border-white/[0.06] py-20 md:py-24">
      <div className="mx-auto max-w-6xl px-6">
        {header}
        <div className="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((f) => (
            <article
              key={f.title}
              className={`glass-card p-6 transition hover:border-white/[0.14] ${cardRadius}`}
            >
              <h3 className="text-[15px] font-medium text-zinc-100">{f.title}</h3>
              <p className="mt-2 text-[13px] leading-relaxed text-zinc-500">{f.description}</p>
              {'keys' in f && f.keys && (
                <div className="mt-4 flex gap-1">
                  {f.keys.map((k) => (
                    <Kbd key={k}>{k}</Kbd>
                  ))}
                </div>
              )}
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}

function HowItWorks({ config }: { config: VariantConfig }) {
  const accent = accentClasses[config.accent]
  const isTimeline = config.name === 'Timeline'

  return (
    <section id="how" className="relative border-t border-white/[0.06] py-20 md:py-24">
      <div className="mx-auto max-w-6xl px-6">
        <div className="text-center">
          <p className="text-[12px] font-medium uppercase tracking-[0.2em] text-zinc-500">How it works</p>
          <h2 className="mt-3 text-2xl font-semibold tracking-[-0.02em] text-white md:text-3xl">
            Three beats. No ceremony.
          </h2>
        </div>
        <ol
          className={`mt-16 gap-8 ${isTimeline ? 'relative mx-auto max-w-2xl space-y-10 border-l border-white/10 pl-8' : 'grid md:grid-cols-3'}`}
        >
          {steps.map((s) => (
            <li key={s.step} className={`relative ${isTimeline ? '' : 'text-center md:text-left'}`}>
              {isTimeline && (
                <span
                  className={`absolute -left-[2.05rem] top-1 h-3 w-3 rounded-full border-2 border-black ${accent.bg}`}
                />
              )}
              <span className={`font-mono text-[11px] ${accent.text}`}>{s.step}</span>
              <h3 className="mt-2 text-lg font-medium text-zinc-100">{s.title}</h3>
              <p className="mt-3 text-[14px] leading-relaxed text-zinc-500">{s.body}</p>
            </li>
          ))}
        </ol>
        <div className="mt-16 flex flex-wrap items-center justify-center gap-2 text-[13px] text-zinc-500">
          <span>Browse</span>
          <Kbd>⌥</Kbd>
          <Kbd>⌘</Kbd>
          <Kbd>P</Kbd>
          <span className="mx-2 text-zinc-700">·</span>
          <span>Action panel</span>
          <Kbd>⌥</Kbd>
          <Kbd>⌘</Kbd>
          <Kbd>K</Kbd>
        </div>
      </div>
    </section>
  )
}

function Pricing({ config }: { config: VariantConfig }) {
  const accent = accentClasses[config.accent]
  const cardRadius = radiusMap[config.radius === 'none' ? 'md' : 'xl']

  return (
    <section id="pricing" className="relative border-t border-white/[0.06] py-20 md:py-24">
      <div className="mx-auto max-w-6xl px-6">
        <div className="mx-auto max-w-xl text-center">
          <p className="text-[12px] font-medium uppercase tracking-[0.2em] text-zinc-500">Pricing</p>
          <h2 className="mt-3 text-2xl font-semibold tracking-[-0.02em] text-white md:text-3xl">
            One tier. Uncompromising.
          </h2>
          <p className="mt-4 text-[15px] text-zinc-400">
            Ink is free to build and self-host from GitHub. Ultra Premium is for people who want the
            full experience maintained for them.
          </p>
        </div>
        <div className="mx-auto mt-14 max-w-md">
          <div
            className={`pricing-glow glass-card relative overflow-hidden p-8 md:p-10 ${cardRadius} ${config.accent === 'gold' ? 'border border-yellow-500/30' : ''}`}
          >
            <div className={`pointer-events-none absolute -top-24 left-1/2 h-48 w-64 -translate-x-1/2 rounded-full blur-3xl ${accent.glow}`} aria-hidden />
            <div className="relative">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className={`text-[12px] font-medium uppercase tracking-widest ${accent.text}`}>
                    Ultra Premium
                  </p>
                  <p className="mt-2 text-sm text-zinc-500">Everything Ink can be</p>
                </div>
                <img src={publicAsset('ink-icon.png')} alt="" className="h-10 w-10 rounded-xl opacity-90" />
              </div>
              <div className="mt-8 flex items-baseline gap-1">
                <span className="text-5xl font-semibold tracking-tight text-white">$25</span>
                <span className="text-zinc-500">/month</span>
              </div>
              <ul className="mt-8 space-y-3 border-t border-white/[0.08] pt-8">
                {premiumFeatures.map((item) => (
                  <li key={item} className="flex gap-3 text-[14px] text-zinc-400">
                    <svg className={`mt-0.5 h-4 w-4 shrink-0 ${accent.text}`} viewBox="0 0 16 16" fill="none" aria-hidden>
                      <path d="M3.5 8.5L6.5 11.5L12.5 4.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                    </svg>
                    {item}
                  </li>
                ))}
              </ul>
              <a href="#download" className={`mt-10 flex h-11 w-full items-center justify-center ${btnClass(config, true)}`}>
                Start Ultra Premium
              </a>
              <p className="mt-4 text-center text-[12px] text-zinc-600">Cancel anytime · macOS only</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

function Download({ config }: { config: VariantConfig }) {
  return (
    <section id="download" className="relative border-t border-white/[0.06] py-20 md:py-24">
      <div className="mx-auto max-w-3xl px-6 text-center">
        <h2 className="text-2xl font-semibold tracking-[-0.02em] text-white md:text-3xl">
          Ready when you are
        </h2>
        <p className="mx-auto mt-4 max-w-lg text-[15px] leading-relaxed text-zinc-400">
          Clone the repo, build in Xcode, and summon your first note with ⌥⌘N. Open source — your
          notes never leave your Mac unless you want them to.
        </p>
        <div className="mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className={`inline-flex h-11 items-center gap-2 ${btnClass(config, true)}`}
          >
            <GitHubIcon />
            Cloverings1/Ink
          </a>
          <span className="text-[13px] text-zinc-600">Requires macOS 14.0+ · Xcode build</span>
        </div>
      </div>
    </section>
  )
}

const KREVO_URL = 'https://www.krevo.io'

function Footer({ config }: { config: VariantConfig }) {
  return (
    <footer className="border-t border-white/[0.06] py-10">
      <div className="mx-auto max-w-6xl px-6">
        <div className="flex flex-col items-center justify-between gap-4 text-[12px] text-zinc-600 sm:flex-row">
          <div className="flex items-center gap-2">
            <img src={publicAsset('ink-icon.png')} alt="" className="h-5 w-5 rounded-md opacity-80" />
            <span>
              © {new Date().getFullYear()} Ink · {config.name}
            </span>
          </div>
          <div className="flex flex-wrap justify-center gap-4 sm:gap-6">
            <Link to="/variants" className="transition hover:text-zinc-400">
              Variants
            </Link>
            <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" className="transition hover:text-zinc-400">
              GitHub
            </a>
            <a href="#features" className="transition hover:text-zinc-400">
              Features
            </a>
            <a href="#pricing" className="transition hover:text-zinc-400">
              Pricing
            </a>
          </div>
        </div>
        <p className="mt-6 text-center text-[11px] text-zinc-700">
          <a
            href={KREVO_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="transition hover:text-zinc-500"
          >
            A Krevo company
          </a>
        </p>
      </div>
    </footer>
  )
}

export function VariantLanding({ config }: { config: VariantConfig }) {
  const fontClass =
    config.font === 'mono' ? 'font-mono' : config.font === 'mixed' ? '[&_h1]:font-serif' : ''

  return (
    <div
      className={`noise relative min-h-screen ${config.shell} ${fontClass} ${config.showNoise === false ? '[&::after]:hidden' : ''}`}
    >
      {config.backdrop && (
        <div className={`pointer-events-none fixed inset-0 ${config.backdrop}`} aria-hidden />
      )}
      {config.showGrid !== false && (
        <div className="pointer-events-none fixed inset-0 bg-grid opacity-40" aria-hidden />
      )}
      <Nav config={config} />
      <main className="relative z-10">
        <Hero config={config} />
        <Features config={config} />
        <HowItWorks config={config} />
        <Pricing config={config} />
        <Download config={config} />
      </main>
      <Footer config={config} />
    </div>
  )
}

export function VariantNotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-black text-zinc-400">
      <p className="text-lg text-white">Variant not found</p>
      <Link to="/variants" className="mt-4 text-sm text-ink-red hover:underline">
        View all variants
      </Link>
    </div>
  )
}
