import { Navigate, useParams } from 'react-router-dom'
import { getVariant } from '../variants/configs'
import { VariantLanding, VariantNotFound } from '../variants/VariantLanding'

export function VariantPage() {
  const { slug } = useParams<{ slug: string }>()
  if (!slug) return <Navigate to="/" replace />

  const config = getVariant(slug)
  if (!config) return <VariantNotFound />

  return <VariantLanding config={config} />
}
