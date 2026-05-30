import Foundation
import Combine

/// Manages all notes as plain .md files in a user-chosen directory.
/// Provides fast in-memory search + auto-save.
/// This class is the single source of truth for the app's data layer.
@MainActor
final class NoteStore: ObservableObject {
    // MARK: - Published State (SwiftUI observes these)

    @Published private(set) var notes: [Note] = []
    @Published private(set) var currentNoteID: UUID?

    // The folder where all notes live (user can change this in Settings)
    @Published var notesDirectory: URL {
        didSet {
            // When user changes the folder we reload everything
            try? loadNotes()
        }
    }

    // Simple in-memory search index (title + content). Rebuilt on every change.
    private var searchIndex: [UUID: String] = [:]   // lowercased blob for fast contains()

    private let fileManager = FileManager.default
    private var saveWorkItem: DispatchWorkItem?   // debounce auto-save

    // Default location: ~/Library/Application Support/Ink/Notes
    static var defaultNotesDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let inkDir = appSupport.appendingPathComponent("Ink/Notes", isDirectory: true)
        return inkDir
    }

    init(notesDirectory: URL? = nil) {
        let storedPath = UserDefaults.standard.string(forKey: "notesDirectoryPath")
        let resolvedDir: URL

        if let path = storedPath, !path.isEmpty {
            resolvedDir = URL(fileURLWithPath: path)
        } else if let provided = notesDirectory {
            resolvedDir = provided
        } else {
            resolvedDir = Self.defaultNotesDirectory
        }

        self.notesDirectory = resolvedDir
        try? Self.ensureDirectoryExists(at: resolvedDir)
        try? loadNotes()
    }

    // MARK: - Directory Management

    private static func ensureDirectoryExists(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: - CRUD

    /// Creates a brand new empty note and makes it current.
    @discardableResult
    func createNewNote() -> Note {
        var note = Note.new(in: notesDirectory)
        // Give it a tiny starter content so the title derivation works nicely later
        note.content = ""
        note.title = "Untitled"

        // Write immediately so the file exists
        try? writeNoteToDisk(note)

        notes.append(note)
        rebuildSearchIndex()
        currentNoteID = note.id
        return note
    }

    /// Loads a specific note into the editor (by ID).
    func selectNote(id: UUID) {
        guard notes.first(where: { $0.id == id }) != nil else { return }
        currentNoteID = id
    }

    /// Returns the currently selected note (or nil).
    var currentNote: Note? {
        guard let id = currentNoteID else { return nil }
        return notes.first { $0.id == id }
    }

    /// Updates the content of the current note (called by the editor on every keystroke).
    /// Triggers a debounced disk write + index rebuild.
    func updateCurrentNoteContent(_ newContent: String) {
        guard var note = currentNote else { return }

        let oldContent = note.content
        guard newContent != oldContent else { return }

        note.content = newContent
        note.updatedAt = Date()
        note.title = Note.deriveTitle(from: newContent)

        // Update in-memory list
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = note
        }

        // Rebuild search index immediately (cheap)
        rebuildSearchIndex()

        // Debounced save to disk (300ms)
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            try? self?.writeNoteToDisk(note)
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Deletes a note from disk and memory.
    func deleteNote(id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes[idx]

        try? fileManager.removeItem(at: note.fileURL)

        notes.remove(at: idx)
        rebuildSearchIndex()

        if currentNoteID == id {
            currentNoteID = notes.first?.id
        }
    }

    // MARK: - Search

    /// Fast search across title + content. Case-insensitive.
    func searchNotes(query: String) -> [Note] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return notes.sorted { $0.updatedAt > $1.updatedAt } }

        return notes
            .filter { note in
                (searchIndex[note.id] ?? "").contains(q)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func rebuildSearchIndex() {
        searchIndex = [:]
        for note in notes {
            let blob = "\(note.title.lowercased()) \(note.content.lowercased())"
            searchIndex[note.id] = blob
        }
    }

    // MARK: - Persistence (plain .md files)

    private func writeNoteToDisk(_ note: Note) throws {
        let data = note.content.data(using: .utf8) ?? Data()
        try data.write(to: note.fileURL, options: .atomic)
    }

    /// Scans the notes directory and loads all .md files into memory.
    func loadNotes() throws {
        try Self.ensureDirectoryExists(at: notesDirectory)

        let urls = try fileManager.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
            .filter { $0.pathExtension.lowercased() == "md" }

        var loaded: [Note] = []

        for url in urls {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }

            let attrs = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            let created = attrs?.creationDate ?? Date()
            let updated = attrs?.contentModificationDate ?? Date()

            let id = UUID() // We use filename for stability? For v1 we just synthesize stable IDs from path.
            // Better: embed UUID in filename or use a simple hash. For simplicity in v1 we use file path hash as ID.
            // To keep things simple and robust we just generate a deterministic ID from the filename.
            let stableID = UUID(uuidString: String(format: "%08x-%04x-%04x-%04x-%012x",
                                                   url.lastPathComponent.hashValue & 0xffffffff,
                                                   0, 0, 0, 0)) ?? UUID()

            // Actually a cleaner approach for v1: just use the file path as the identity and a random UUID per load? No.
            // Best pragmatic choice: store a tiny YAML frontmatter with the ID on first save.
            // For the scaffold we do a simple reliable thing: use the file's inode or just always re-derive and keep last known current.

            // Simpler robust approach used here:
            let noteID = UUID() // We will improve this in polish phase with frontmatter.
            // For now to make switching work reliably we use a hash of the URL path.
            let pathHash = url.path.hashValue
            let idFromPath = UUID(uuidString: String(format: "%08x-%04x-%04x-%04x-%012x", pathHash & 0xffffffff, 0, 0, 0, 0)) ?? UUID()

            let title = Note.deriveTitle(from: content)

            let note = Note(
                id: idFromPath,
                title: title,
                content: content,
                fileURL: url,
                createdAt: created,
                updatedAt: updated
            )
            loaded.append(note)
        }

        // Sort by most recently updated
        loaded.sort { $0.updatedAt > $1.updatedAt }

        self.notes = loaded
        rebuildSearchIndex()

        // Restore last current note or pick the most recent
        if currentNoteID == nil || !notes.contains(where: { $0.id == currentNoteID }) {
            currentNoteID = notes.first?.id
        }
    }

    /// Allows the user (via Settings) to pick a completely different notes folder.
    func changeNotesDirectory(to newURL: URL) {
        UserDefaults.standard.set(newURL.path, forKey: "notesDirectoryPath")
        notesDirectory = newURL
    }

    // MARK: - Export helpers (used by Action Panel)

    func exportNoteAsMarkdown(_ note: Note) -> URL? {
        // In a real app we would use NSSavePanel. Here we just return the existing file URL.
        return note.fileURL
    }
}