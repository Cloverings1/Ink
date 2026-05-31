/** Public files from /public, prefixed for Vite `base` (e.g. /ink/). */
export function publicAsset(path: string) {
  const normalized = path.replace(/^\//, '')
  return `${import.meta.env.BASE_URL}${normalized}`
}
