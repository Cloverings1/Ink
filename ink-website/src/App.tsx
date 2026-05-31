import { PanelMockup } from './PanelMockup'

const GITHUB_URL = 'https://github.com/Cloverings1/Ink'

function Nav() {
  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-white/[0.06] bg-black/70 backdrop-blur-xl">
      <nav className="mx-auto flex h-14 max-w-6xl items-center justify-between px-6">
        <a href="#" className="flex items-center gap-2.5 text-sm font-medium text-zinc-100">
          <img src="/ink-icon.png" alt="" className="h-7 w-7 rounded-lg" width={28} height={28} />
          <span>Ink</span>
        </a>
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
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="hidden text-[13px] text-zinc-400 transition-colors hover:text-zinc-200 sm:inline"
          >
            GitHub
          </a>
          <a
            href="#download"
            className="rounded-full bg-white px-4 py-1.5 text-[13px] font-medium text-black transition hover:bg-zinc-200"
          >
            Get Ink
          </a>
        </div>
      </nav>
    </header>
  )
}

function Hero() {
  return (
    <section className="relative overflow-hidden pt-28 pb-12 md:pt-36 md:pb-16">
      <div className="pointer-events-none absolute inset-0 mesh-glow" aria-hidden />
      <div className="relative z-10 mx-auto max-w-4xl px-6 text-center">
        <p className="animate-fade-up mb-6 inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-3 py-1 text-[12px] text-zinc-400">
          <span className="h-1.5 w-1.5 rounded-full bg-ink-red shadow-[0_0_8px_#ff4b4b]" />
          macOS 14+ · Plain Markdown · You own every file
        </p>
        <h1 className="animate-fade-up-delay-1 text-[2.5rem] font-semibold leading-[1.08] tracking-[-0.03em] text-white sm:text-5xl md:text-[3.25rem]">
          Floating notes,
          <br />
          <span className="bg-gradient-to-b from-white to-zinc-500 bg-clip-text text-transparent">
            one keystroke away
          </span>
        </h1>
        <p className="animate-fade-up-delay-2 mx-auto mt-6 max-w-xl text-[15px] leading-relaxed text-zinc-400 md:text-base">
          Ink summons a frosted glass panel over any app, any Space, even fullscreen. Capture
          thoughts in raw Markdown — saved as real <code className="text-zinc-300">.md</code> files
          on your Mac.
        </p>
        <div className="animate-fade-up-delay-2 mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <a
            href="#download"
            className="inline-flex h-11 items-center justify-center rounded-full bg-white px-7 text-[14px] font-medium text-black transition hover:bg-zinc-200"
          >
            Download for macOS
          </a>
          <a
            href="#pricing"
            className="inline-flex h-11 items-center justify-center rounded-full border border-white/15 px-7 text-[14px] font-medium text-zinc-200 transition hover:border-white/25 hover:bg-white/[0.04]"
          >
            Ultra Premium — $25/mo
          </a>
        </div>
        <div className="animate-fade-up-delay-3 mt-10 md:mt-12">
          <PanelMockup />
        </div>
      </div>
    </section>
  )
}

const features = [
  {
    title: 'Zero friction',
    description:
      'Global hotkey opens the panel instantly. No context switch, no Dock icon required. Dismiss with Esc.',
    keys: ['⌥', '⌘', 'N'],
  },
  {
    title: 'Native floating panel',
    description:
      'Built on NSPanel with nonactivating behavior — floats above your work without stealing app activation.',
  },
  {
    title: 'Plain Markdown',
    description:
      'Raw Markdown with a toolbar that inserts syntax. What you see is exactly what lives on disk.',
  },
  {
    title: 'Files you own',
    description:
      'Notes are individual .md files in a folder you choose. Open them in Obsidian, VS Code, BBEdit, or git.',
  },
  {
    title: 'Customizable shortcuts',
    description:
      'Create, browse, and command palette — all remappable through KeyboardShortcuts.',
    keys: ['⌥', '⌘', 'P'],
  },
  {
    title: 'Instant search',
    description:
      'In-memory title and content index for fast browse and search. No database lock-in.',
  },
]

function Features() {
  return (
    <section id="features" className="relative border-t border-white/[0.06] py-20 md:py-24">
      <div className="mx-auto max-w-6xl px-6">
        <div className="max-w-xl">
          <p className="text-[12px] font-medium uppercase tracking-[0.2em] text-zinc-500">
            Features
          </p>
          <h2 className="mt-3 text-2xl font-semibold tracking-[-0.02em] text-white md:text-3xl">
            Built for speed, designed for calm
          </h2>
          <p className="mt-4 text-[15px] leading-relaxed text-zinc-400">
            Everything that makes Ink feel native — not another note app fighting for your
            attention.
          </p>
        </div>
        <div className="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((f) => (
            <article
              key={f.title}
              className="glass-card rounded-2xl p-6 transition hover:border-white/[0.14]"
            >
              <h3 className="text-[15px] font-medium text-zinc-100">{f.title}</h3>
              <p className="mt-2 text-[13px] leading-relaxed text-zinc-500">{f.description}</p>
              {f.keys && (
                <div className="mt-4 flex gap-1">
                  {f.keys.map((k) => (
                    <span key={k} className="kbd">
                      {k}
                    </span>
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

const steps = [
  {
    step: '01',
    title: 'Summon from anywhere',
    body: 'Press ⌥⌘N while coding, browsing, or in fullscreen. The frosted panel appears in milliseconds.',
  },
  {
    step: '02',
    title: 'Write in Markdown',
    body: 'Type raw Markdown with toolbar inserts for bold, headings, lists, and more. No WYSIWYG layer.',
  },
  {
    step: '03',
    title: 'Own your files',
    body: 'Every note auto-saves as note-<UUID>.md in your notes folder. Open, sync, and version them anywhere.',
  },
]

function HowItWorks() {
  return (
    <section id="how" className="relative border-t border-white/[0.06] py-20 md:py-24">
      <div className="mx-auto max-w-6xl px-6">
        <div className="text-center">
          <p className="text-[12px] font-medium uppercase tracking-[0.2em] text-zinc-500">
            How it works
          </p>
          <h2 className="mt-3 text-2xl font-semibold tracking-[-0.02em] text-white md:text-3xl">
            Three beats. No ceremony.
          </h2>
        </div>
        <ol className="mt-16 grid gap-8 md:grid-cols-3">
          {steps.map((s) => (
            <li key={s.step} className="relative text-center md:text-left">
              <span className="font-mono text-[11px] text-ink-red/80">{s.step}</span>
              <h3 className="mt-2 text-lg font-medium text-zinc-100">{s.title}</h3>
              <p className="mt-3 text-[14px] leading-relaxed text-zinc-500">{s.body}</p>
            </li>
          ))}
        </ol>
        <div className="mt-16 flex flex-wrap items-center justify-center gap-2 text-[13px] text-zinc-500">
          <span>Browse</span>
          <span className="kbd">⌥</span>
          <span className="kbd">⌘</span>
          <span className="kbd">P</span>
          <span className="mx-2 text-zinc-700">·</span>
          <span>Action panel</span>
          <span className="kbd">⌥</span>
          <span className="kbd">⌘</span>
          <span className="kbd">K</span>
        </div>
      </div>
    </section>
  )
}

const premiumFeatures = [
  'Priority sync & backup to your cloud of choice',
  'Custom themes & panel chrome',
  'Unlimited notes & workspaces',
  'Early access builds & direct support',
  'Team sharing (coming soon)',
]

function Pricing() {
  return (
    <section id="pricing" className="relative border-t border-white/[0.06] py-20 md:py-24">
      <div className="mx-auto max-w-6xl px-6">
        <div className="mx-auto max-w-xl text-center">
          <p className="text-[12px] font-medium uppercase tracking-[0.2em] text-zinc-500">
            Pricing
          </p>
          <h2 className="mt-3 text-2xl font-semibold tracking-[-0.02em] text-white md:text-3xl">
            One tier. Uncompromising.
          </h2>
          <p className="mt-4 text-[15px] text-zinc-400">
            Ink is free to build and self-host from GitHub. Ultra Premium is for people who want
            the full experience maintained for them.
          </p>
        </div>
        <div className="mx-auto mt-14 max-w-md">
          <div className="pricing-glow glass-card relative overflow-hidden rounded-3xl p-8 md:p-10">
            <div
              className="pointer-events-none absolute -top-24 left-1/2 h-48 w-64 -translate-x-1/2 rounded-full bg-ink-red/30 blur-3xl"
              aria-hidden
            />
            <div className="relative">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="text-[12px] font-medium uppercase tracking-widest text-ink-red">
                    Ultra Premium
                  </p>
                  <p className="mt-2 text-sm text-zinc-500">Everything Ink can be</p>
                </div>
                <img src="/ink-icon.png" alt="" className="h-10 w-10 rounded-xl opacity-90" />
              </div>
              <div className="mt-8 flex items-baseline gap-1">
                <span className="text-5xl font-semibold tracking-tight text-white">$25</span>
                <span className="text-zinc-500">/month</span>
              </div>
              <ul className="mt-8 space-y-3 border-t border-white/[0.08] pt-8">
                {premiumFeatures.map((item) => (
                  <li key={item} className="flex gap-3 text-[14px] text-zinc-400">
                    <svg
                      className="mt-0.5 h-4 w-4 shrink-0 text-ink-red"
                      viewBox="0 0 16 16"
                      fill="none"
                      aria-hidden
                    >
                      <path
                        d="M3.5 8.5L6.5 11.5L12.5 4.5"
                        stroke="currentColor"
                        strokeWidth="1.5"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                    {item}
                  </li>
                ))}
              </ul>
              <a
                href="#download"
                className="mt-10 flex h-11 w-full items-center justify-center rounded-full bg-white text-[14px] font-medium text-black transition hover:bg-zinc-200"
              >
                Start Ultra Premium
              </a>
              <p className="mt-4 text-center text-[12px] text-zinc-600">
                Cancel anytime · macOS only
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

function Download() {
  return (
    <section
      id="download"
      className="relative border-t border-white/[0.06] py-20 md:py-24"
    >
      <div className="mx-auto max-w-3xl px-6 text-center">
        <h2 className="text-2xl font-semibold tracking-[-0.02em] text-white md:text-3xl">
          Ready when you are
        </h2>
        <p className="mx-auto mt-4 max-w-lg text-[15px] leading-relaxed text-zinc-400">
          Clone the repo, build in Xcode, and summon your first note with ⌥⌘N. Open source —
          your notes never leave your Mac unless you want them to.
        </p>
        <div className="mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex h-11 items-center gap-2 rounded-full bg-white px-7 text-[14px] font-medium text-black transition hover:bg-zinc-200"
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

function Footer() {
  return (
    <footer className="border-t border-white/[0.06] py-10">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-6 text-[12px] text-zinc-600 sm:flex-row">
        <div className="flex items-center gap-2">
          <img src="/ink-icon.png" alt="" className="h-5 w-5 rounded-md opacity-80" />
          <span>© {new Date().getFullYear()} Ink</span>
        </div>
        <div className="flex gap-6">
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="transition hover:text-zinc-400"
          >
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
    </footer>
  )
}

function GitHubIcon() {
  return (
    <svg className="h-4 w-4" viewBox="0 0 16 16" fill="currentColor" aria-hidden>
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.18.82.63-.18 1.29-.27 1.96-.27.67 0 1.33.09 1.96.27 1.51-1.04 2.18-.82 2.18-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0016 8c0-4.42-3.58-8-8-8z" />
    </svg>
  )
}

export default function App() {
  return (
    <div className="noise relative min-h-screen bg-black text-zinc-100">
      <div className="pointer-events-none fixed inset-0 bg-grid opacity-40" aria-hidden />
      <Nav />
      <main className="relative z-10">
        <Hero />
        <Features />
        <HowItWorks />
        <Pricing />
        <Download />
      </main>
      <Footer />
    </div>
  )
}
