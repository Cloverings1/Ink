import Foundation

/// Represents a single note stored as a plain .md file on disk.
/// This is the single source of truth for Ink.
struct Note: Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    var content: String
    let fileURL: URL
    var createdAt: Date
    var updatedAt: Date

    /// Convenience computed property used in the UI.
    var charCount: Int {
        content.count
    }

    /// Creates a brand new note (used by "Create Note").
    static func new(in folder: URL) -> Note {
        let id = UUID()
        let now = Date()
        // Human-friendly but unique filename
        let slug = "untitled-\(id.uuidString.prefix(8))"
        let fileURL = folder.appendingPathComponent("\(slug).md")

        return Note(
            id: id,
            title: "Untitled",
            content: "",
            fileURL: fileURL,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Derive a nice title from the Markdown content.
    /// Priority: first ATX heading (# Title), else first non-empty line, else "Untitled".
    static func deriveTitle(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)

        // Look for first # heading
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                let candidate = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty { return String(candidate) }
            }
        }

        // First non-empty line
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                // Take first 80 chars max for title
                return String(trimmed.prefix(80))
            }
        }

        return "Untitled"
    }
}