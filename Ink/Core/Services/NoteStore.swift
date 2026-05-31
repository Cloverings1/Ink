import Foundation
import Combine
import os

/// Manages all notes as plain .md files in a user-chosen directory.
/// Provides fast in-memory search + reliable auto-save.
@MainActor
final class NoteStore: ObservableObject {
    enum SaveState: Equatable {
        case idle
        case saving
        case saved(Date)
        case failed(String)
    }

    @Published private(set) var notes: [Note] = []
    @Published private(set) var currentNoteID: UUID?
    @Published private(set) var notesDirectory: URL
    @Published private(set) var saveState: SaveState = .idle

    private var searchIndex: [UUID: String] = [:]
    private let fileManager: FileManager
    private var pendingSaveWorkItems: [UUID: DispatchWorkItem] = [:]
    private var pendingSaveSnapshots: [UUID: Note] = [:]

    private static let logger = Logger(subsystem: "com.jonasbubela.Ink", category: "NoteStore")
    private static let notesDirectoryKey = "notesDirectoryPath"

    static var defaultNotesDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Ink/Notes", isDirectory: true)
    }

    init(notesDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let storedPath = UserDefaults.standard.string(forKey: Self.notesDirectoryKey)
        if let notesDirectory {
            self.notesDirectory = notesDirectory
        } else if let path = storedPath, !path.isEmpty {
            self.notesDirectory = URL(fileURLWithPath: path)
        } else {
            self.notesDirectory = Self.defaultNotesDirectory
        }

        do {
            try Self.ensureDirectoryExists(at: self.notesDirectory, fileManager: fileManager)
            try loadNotes()
        } catch {
            recordFailure("Could not load notes from \(self.notesDirectory.path)", error: error)
        }
    }

    var currentNote: Note? {
        guard let id = currentNoteID else { return nil }
        return notes.first { $0.id == id }
    }

    @discardableResult
    func createNewNote() -> Note {
        flushPendingSaves()

        let note = Note.new(in: notesDirectory)
        do {
            try writeNoteToDisk(note)
            saveState = .saved(Date())
        } catch {
            recordFailure("Could not create note at \(note.fileURL.path)", error: error)
        }

        notes.append(note)
        rebuildSearchIndex()
        currentNoteID = note.id
        return note
    }

    func selectNote(id: UUID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        flushPendingSave(for: currentNoteID)
        currentNoteID = id
    }

    func updateCurrentNoteContent(_ newContent: String) {
        guard var note = currentNote else { return }
        guard newContent != note.content else { return }

        note.content = newContent
        note.updatedAt = Date()
        note.title = Note.deriveTitle(from: newContent)

        updateInMemory(note)
        rebuildSearchIndex()
        scheduleSave(note)
    }

    func deleteNote(id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes[idx]

        cancelPendingSave(for: id)

        do {
            if fileManager.fileExists(atPath: note.fileURL.path) {
                try fileManager.removeItem(at: note.fileURL)
            }
        } catch {
            recordFailure("Could not delete note at \(note.fileURL.path)", error: error)
            return
        }

        notes.remove(at: idx)
        rebuildSearchIndex()

        if currentNoteID == id {
            currentNoteID = notes.first?.id
        }
    }

    func searchNotes(query: String) -> [Note] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return notes.sorted { $0.updatedAt > $1.updatedAt } }

        return notes
            .filter { (searchIndex[$0.id] ?? "").contains(q) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func flushPendingSaves() {
        for id in Array(pendingSaveSnapshots.keys) {
            flushPendingSave(for: id)
        }
    }

    func flushPendingSave(for id: UUID?) {
        guard let id else { return }
        pendingSaveWorkItems[id]?.cancel()
        pendingSaveWorkItems[id] = nil

        guard let note = pendingSaveSnapshots.removeValue(forKey: id) else { return }
        persist(note)
    }

    func changeNotesDirectory(to newURL: URL) {
        flushPendingSaves()

        do {
            try Self.ensureDirectoryExists(at: newURL, fileManager: fileManager)
            UserDefaults.standard.set(newURL.path, forKey: Self.notesDirectoryKey)
            notesDirectory = newURL
            try loadNotes()
        } catch {
            recordFailure("Could not switch notes folder to \(newURL.path)", error: error)
        }
    }

    func exportNoteAsMarkdown(_ note: Note) -> URL? {
        flushPendingSave(for: note.id)
        return note.fileURL
    }

    func loadNotes() throws {
        flushPendingSaves()
        try Self.ensureDirectoryExists(at: notesDirectory, fileManager: fileManager)

        let urls = try fileManager.contentsOfDirectory(
            at: notesDirectory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "md" }

        var loaded: [Note] = []

        for url in urls {
            do {
                let canonicalURL = try canonicalNoteURL(for: url)
                let content = try String(contentsOf: canonicalURL, encoding: .utf8)
                let attrs = try? canonicalURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])

                let note = Note(
                    id: try Self.noteID(from: canonicalURL),
                    title: Note.deriveTitle(from: content),
                    content: content,
                    fileURL: canonicalURL,
                    createdAt: attrs?.creationDate ?? Date(),
                    updatedAt: attrs?.contentModificationDate ?? Date()
                )
                loaded.append(note)
            } catch {
                recordFailure("Could not load note at \(url.path)", error: error)
            }
        }

        loaded.sort { $0.updatedAt > $1.updatedAt }
        notes = loaded
        rebuildSearchIndex()

        if currentNoteID == nil || !notes.contains(where: { $0.id == currentNoteID }) {
            currentNoteID = notes.first?.id
        }
    }

    private static func ensureDirectoryExists(at url: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func scheduleSave(_ note: Note) {
        pendingSaveWorkItems[note.id]?.cancel()
        pendingSaveSnapshots[note.id] = note
        saveState = .saving

        let noteID = note.id
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.performScheduledSave(for: noteID)
            }
        }

        pendingSaveWorkItems[note.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func performScheduledSave(for id: UUID) {
        pendingSaveWorkItems[id] = nil
        guard let note = pendingSaveSnapshots.removeValue(forKey: id) else { return }
        persist(note)
    }

    private func persist(_ note: Note) {
        do {
            try writeNoteToDisk(note)
            saveState = .saved(Date())
        } catch {
            pendingSaveSnapshots[note.id] = note
            saveState = .failed("Could not save \(note.fileURL.lastPathComponent)")
            Self.logger.error("Save failed for \(note.fileURL.path, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    private func writeNoteToDisk(_ note: Note) throws {
        try Self.ensureDirectoryExists(at: note.fileURL.deletingLastPathComponent(), fileManager: fileManager)
        let data = note.content.data(using: .utf8) ?? Data()
        try data.write(to: note.fileURL, options: .atomic)
    }

    private func cancelPendingSave(for id: UUID) {
        pendingSaveWorkItems[id]?.cancel()
        pendingSaveWorkItems[id] = nil
        pendingSaveSnapshots[id] = nil
    }

    private func updateInMemory(_ note: Note) {
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[idx] = note
    }

    private func rebuildSearchIndex() {
        searchIndex = Dictionary(uniqueKeysWithValues: notes.map { note in
            (note.id, "\(note.title.lowercased()) \(note.content.lowercased())")
        })
    }

    private func canonicalNoteURL(for url: URL) throws -> URL {
        if (try? Self.noteID(from: url)) != nil {
            return url
        }

        let id = UUID()
        let newURL = notesDirectory.appendingPathComponent("note-\(id.uuidString).md")
        try fileManager.moveItem(at: url, to: newURL)
        Self.logger.info("Migrated note filename from \(url.lastPathComponent, privacy: .public) to \(newURL.lastPathComponent, privacy: .public)")
        return newURL
    }

    private static func noteID(from url: URL) throws -> UUID {
        let name = url.deletingPathExtension().lastPathComponent
        guard name.hasPrefix("note-") else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let rawID = String(name.dropFirst("note-".count))
        guard let id = UUID(uuidString: rawID) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return id
    }

    private func recordFailure(_ message: String, error: Error) {
        saveState = .failed(message)
        Self.logger.error("\(message, privacy: .public): \(String(describing: error), privacy: .public)")
    }
}
