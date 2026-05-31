# Ink Website

Marketing landing page for [Ink](https://github.com/Cloverings1/Ink) — floating notes for macOS.

## Stack

- **Vite** + **React 19** + **TypeScript**
- **Tailwind CSS v4** (`@tailwindcss/vite`)

## Run locally

```bash
cd ink-website
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173).

**Production homepage:** `/ink/` uses the **Timeline** variant (`v22`).

**Public URL:** [https://www.krevo.io/ink](https://www.krevo.io/ink) (proxied from the `graphite` project).

## Deploy to Vercel

From this directory (`ink-website/`):

```bash
npm run build
npx vercel          # preview
npx vercel --prod   # production
```

If the Git repo root is the parent `ink/` folder, set **Root Directory** to `ink-website` in the Vercel project settings.

The app is built with Vite `base: '/ink/'`. The **graphite** (`krevo.io`) project rewrites `/ink` and `/ink/*` to this deployment — redeploy **both** `ink-website` and `graphite` after routing changes.

## Variants

25 full-page landing designs:

| Route | Style |
|-------|--------|
| `/` | **Timeline** (production default) |
| `/variants` | Index — grid of all variants |
| `/v1` | Linear — red mesh, centered hero |
| `/v2` | Cursor — terminal green, mono |
| `/v3` | Vercel — sharp monochrome |
| `/v4` | Apple — large calm type |
| `/v5` | Brutalist — hard edges |
| `/v6` | Aurora — violet gradients |
| `/v7` | Glass — frosted surfaces |
| `/v8` | Monochrome — typography-first |
| `/v9` | Ink Red — brand-forward |
| `/v10` | Neon — cyan cyber |
| `/v11` | Editorial — serif hierarchy |
| `/v12` | Split — copy + panel side-by-side |
| `/v13` | Bento — asymmetric tiles |
| `/v14` | Blueprint — grid crosshairs |
| `/v15` | Soft — rounded gentle |
| `/v16` | Stripe — diagonal bands |
| `/v17` | Zen — ultra-minimal |
| `/v18` | Command — palette hero |
| `/v19` | Spotlight — search-bar hero |
| `/v20` | Matrix — dot texture |
| `/v21` | Premium First — pricing-led |
| `/v22` | Timeline — process vertical |
| `/v23` | Geometric — angular split |
| `/v24` | Frost — ice overlay |
| `/v25` | Ultra Luxury — gold premium |

Config lives in `src/variants/configs.ts`. Layout engine in `src/variants/VariantLanding.tsx`.


```bash
npm run build
npm run preview
```

## Assets

- `public/ink-icon.png` — copied from `Ink/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png`
- `public/panel-demo.svg` — hero mockup from `.github/assets/panel-demo.svg`
