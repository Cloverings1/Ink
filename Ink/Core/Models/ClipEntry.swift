import Foundation

/// A single plain-text clipboard history entry.
/// Persisted as part of a `Codable` array to `clipboard-history.json`.
struct ClipEntry: Identifiable, Equatable, Codable {
    let id: UUID
    let text: String
    let copiedAt: Date
}
