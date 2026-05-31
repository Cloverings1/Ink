import type { Accent } from '../variants/types'
import { accentClasses } from '../variants/types'

export function PanelMockup({ accent = 'red' }: { accent?: Accent }) {
  const a = accentClasses[accent]

  return (
    <div
      className="animate-float-panel relative mx-auto w-full max-w-2xl select-none"
      aria-hidden
    >
      <div className={`pointer-events-none absolute -inset-x-8 -top-6 h-24 blur-3xl ${a.glow}`} />
      <div className="glass-card relative overflow-hidden rounded-2xl border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]">
        <div className="flex items-center gap-2 border-b border-white/[0.06] px-4 py-3">
          <span className="h-2.5 w-2.5 rounded-full bg-[#ff5f57]" />
          <span className="h-2.5 w-2.5 rounded-full bg-[#febc2e]" />
          <span className="h-2.5 w-2.5 rounded-full bg-[#28c840]" />
          <span className="mx-auto text-[12px] font-medium text-zinc-300">Ink</span>
        </div>
        <div className="space-y-3 px-5 py-5 text-left">
          <p className="text-lg font-semibold tracking-tight text-white">Meeting notes</p>
          <p className="text-[13px] leading-relaxed text-zinc-500">
            Capture ideas without leaving the app you&apos;re in.
          </p>
          <div className="space-y-1.5 pt-1 font-mono text-[12px] text-zinc-400">
            <p>- Ship the floating panel polish</p>
            <p>- Keep notes as plain Markdown files</p>
            <p>- Auto-save to ~/Library/.../Ink/Notes</p>
          </div>
          <p className={`inline-block h-4 w-0.5 animate-pulse ${a.bg}`} />
        </div>
        <div className="flex items-center justify-between border-t border-white/[0.06] px-5 py-3 text-[11px] font-semibold text-zinc-400">
          <div className="flex gap-3">
            <span>B</span>
            <span>I</span>
            <span>H</span>
            <span>•</span>
            <span>[]</span>
          </div>
          <span className="font-mono text-[10px] text-zinc-600">saved</span>
        </div>
      </div>
      <div
        className={`absolute -right-2 -top-3 rounded-full border px-3 py-1 font-mono text-[11px] font-semibold shadow-[0_0_24px_rgba(255,75,75,0.2)] ${a.kbd}`}
      >
        ⌥⌘N
      </div>
    </div>
  )
}
