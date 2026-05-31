import { Link } from 'react-router-dom'
import { publicAsset } from '../lib/publicAsset'
import { variants } from '../variants/configs'

export function IndexPage() {
  return (
    <div className="relative min-h-screen bg-black text-zinc-100">
      <div className="pointer-events-none fixed inset-0 bg-grid opacity-30" aria-hidden />
      <div className="relative z-10 mx-auto max-w-5xl px-6 py-20">
        <div className="flex items-center gap-3">
          <img src={publicAsset('ink-icon.png')} alt="" className="h-10 w-10 rounded-xl" />
          <div>
            <h1 className="text-2xl font-semibold tracking-tight text-white">Ink landing variants</h1>
            <Link to="/" className="mt-2 inline-block text-[13px] text-ink-red hover:underline">
              ← Back to live site
            </Link>
            <p className="mt-1 text-[14px] text-zinc-500">
              Production: <Link to="/" className="text-zinc-400 hover:text-white">Timeline (/)</Link> · /v1–/v25
            </p>
          </div>
        </div>
        <div className="mt-12 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {variants.map((v) => (
            <Link
              key={v.slug}
              to={`/${v.slug}`}
              className="glass-card group rounded-xl p-5 transition hover:border-white/[0.18]"
            >
              <div className="flex items-center justify-between">
                <span className="font-mono text-[11px] text-zinc-600">/{v.slug}</span>
                <span className="text-[11px] text-zinc-600 group-hover:text-zinc-400">Open →</span>
              </div>
              <p className="mt-3 text-[15px] font-medium text-zinc-100">{v.name}</p>
              <p className="mt-1 text-[13px] leading-relaxed text-zinc-500">{v.tagline}</p>
            </Link>
          ))}
        </div>
      </div>
    </div>
  )
}
