import { getVariant, primaryVariantSlug } from '../variants/configs'
import { VariantLanding } from '../variants/VariantLanding'

export function HomePage() {
  const config = getVariant(primaryVariantSlug)
  if (!config) {
    throw new Error(`Primary variant "${primaryVariantSlug}" is not configured`)
  }
  return <VariantLanding config={config} />
}
