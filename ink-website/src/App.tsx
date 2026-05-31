import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { HomePage } from './pages/HomePage'
import { IndexPage } from './pages/IndexPage'
import { VariantPage } from './pages/VariantPage'

export default function App() {
  return (
    <BrowserRouter basename="/ink">
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/variants" element={<IndexPage />} />
        <Route path="/:slug" element={<VariantPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
