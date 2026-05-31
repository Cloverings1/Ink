import Foundation
import Combine
import CryptoKit
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

    struct ImportLimits: Equatable {
        var maxNoteCount: Int
        var maxFileBytes: Int64
        var maxTotalBytes: Int64

        static let `default` = ImportLimits(
            maxNoteCount: 5_000,
            maxFileBytes: 10 * 1024 * 1024,
            maxTotalBytes: 100 * 1024 * 1024
        )
    }

    @Published private(set) var notes: [Note] = []
    @Published private(set) var currentNoteID: UUID?
    @Published private(set) var notesDirectory: URL
    @Published private(set) var saveState: SaveState = .idle

    private var searchIndex: [UUID: String] = [:]
    private let importLimits: ImportLimits
    private let fileManager: FileManager
    private let trashItem: (URL) throws -> Void
    private var pendingSaveWorkItems: [UUID: DispatchWorkItem] = [:]
    private var pendingSaveSnapshots: [UUID: Note] = [:]
    private var lastKnownDiskContent: [UUID: String] = [:]

    private static let logger = Logger(subsystem: "com.jonasbubela.Ink", category: "NoteStore")
    private static let notesDirectoryKey = "notesDirectoryPath"
    private static let noteResourceKeys: Set<URLResourceKey> = [
        .creationDateKey,
        .contentModificationDateKey,
        .fileSizeKey,
        .isRegularFileKey,
        .isSymbolicLinkKey
    ]

    private enum NoteImportError: Error, CustomStringConvertible {
        case unsafeFile(URL, String)
        case importLimit(URL, String)

        var description: String {
            switch self {
            case let .unsafeFile(url, reason):
                return "Skipped \(url.lastPathComponent): \(reason)"
            case let .importLimit(url, reason):
                return "Skipped \(url.lastPathComponent): \(reason)"
            }
        }
    }

    static var defaultNotesDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Ink/Notes", isDirectory: true)
    }

    init(
        notesDirectory: URL? = nil,
        importLimits: ImportLimits = .default,
        fileManager: FileManager = .default,
        trashItem: @escaping (URL) throws -> Void = { url in
            _ = try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    ) {
        self.importLimits = importLimits
        self.fileManager = fileManager
        self.trashItem = trashItem

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
    func createNewNote() -> Note? {
        flushPendingSaves()

        let note = Note.new(in: notesDirectory)
        do {
            try writeNoteToDisk(note)
            saveState = .saved(Date())
        } catch {
            recordFailure("Could not create note at \(note.fileURL.path)", error: error)
            return nil
        }

        notes.append(note)
        lastKnownDiskContent[note.id] = note.content
        rebuildSearchIndex()
        currentNoteID = note.id
        return note
    }

    func selectNote(id: UUID) {
        flushPendingSave(for: currentNoteID)
        reconcileExternalChanges()
        guard notes.contains(where: { $0.id == id }) else { return }
        currentNoteID = id
    }

    func updateCurrentNoteContent(_ newContent: String) {
        guard var note = currentNote else { return }
        guard newContent != note.content else { return }

        note.content = newContent
        note.updatedAt = Date()
        note.title = Note.deriveTitle(from: newContent)

        updateInMemory(note)
        updateSearchIndex(for: note)
        scheduleSave(note)
    }

    func deleteNote(id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes[idx]

        cancelPendingSave(for: id)

        do {
            if fileManager.fileExists(atPath: note.fileURL.path) {
                try trashItem(note.fileURL)
            }
        } catch {
            recordFailure("Could not delete note at \(note.fileURL.path)", error: error)
            return
        }

        notes.remove(at: idx)
        lastKnownDiskContent[id] = nil
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
        var loaded = try readNotesFromDisk()

        loaded.sort { $0.updatedAt > $1.updatedAt }
        notes = loaded
        lastKnownDiskContent = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0.content) })
        rebuildSearchIndex()

        if currentNoteID == nil || !notes.contains(where: { $0.id == currentNoteID }) {
            currentNoteID = notes.first?.id
        }
    }

    func reconcileExternalChanges() {
        do {
            let diskNotes = try readNotesFromDisk()
            let diskByID = Dictionary(uniqueKeysWithValues: diskNotes.map { ($0.id, $0) })
            let dirtyIDs = Set(pendingSaveSnapshots.keys)

            for note in notes {
                guard diskByID[note.id] == nil else { continue }
                if dirtyIDs.contains(note.id) {
                    try preserveDirtyDeletedNote(note)
                } else {
                    removeInMemoryNote(id: note.id)
                    lastKnownDiskContent[note.id] = nil
                }
            }

            for diskNote in diskNotes {
                if dirtyIDs.contains(diskNote.id) {
                    continue
                }

                if let idx = notes.firstIndex(where: { $0.id == diskNote.id }) {
                    notes[idx] = diskNote
                } else {
                    notes.append(diskNote)
                }
                lastKnownDiskContent[diskNote.id] = diskNote.content
            }

            notes.sort { $0.updatedAt > $1.updatedAt }
            rebuildSearchIndex()

            if currentNoteID == nil || !notes.contains(where: { $0.id == currentNoteID }) {
                currentNoteID = notes.first?.id
            }
        } catch {
            recordFailure("Could not refresh notes from \(notesDirectory.path)", error: error)
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
            if let baseline = lastKnownDiskContent[note.id],
               let diskContent = try? String(contentsOf: note.fileURL, encoding: .utf8),
               diskContent != baseline {
                try preserveConflict(for: note, originalDiskContent: diskContent)
                saveState = .failed("External edit preserved; Ink copy saved")
                return
            }

            if lastKnownDiskContent[note.id] != nil,
               !fileManager.fileExists(atPath: note.fileURL.path) {
                try preserveDirtyDeletedNote(note)
                saveState = .failed("Deleted note preserved as Ink copy")
                return
            }

            try writeNoteToDisk(note)
            lastKnownDiskContent[note.id] = note.content
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

    private func readNotesFromDisk() throws -> [Note] {
        try Self.ensureDirectoryExists(at: notesDirectory, fileManager: fileManager)

        let urls = try fileManager.contentsOfDirectory(
            at: notesDirectory,
            includingPropertiesForKeys: Array(Self.noteResourceKeys),
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "md" }

        var loaded: [Note] = []
        var importedBytes: Int64 = 0

        for url in urls {
            do {
                guard loaded.count < importLimits.maxNoteCount else {
                    throw NoteImportError.importLimit(url, "note import count limit reached")
                }

                let resourceValues = try validateNoteFile(at: url)
                let fileBytes = Int64(resourceValues.fileSize ?? 0)

                guard fileBytes <= importLimits.maxFileBytes else {
                    throw NoteImportError.importLimit(url, "file is larger than the note import size limit")
                }

                guard importedBytes + fileBytes <= importLimits.maxTotalBytes else {
                    throw NoteImportError.importLimit(url, "notes folder exceeds the aggregate import size limit")
                }

                loaded.append(try readNote(at: url, resourceValues: resourceValues))
                importedBytes += fileBytes
            } catch {
                recordFailure("Could not load note at \(url.path)", error: error)
            }
        }

        return loaded
    }

    private func validateNoteFile(at url: URL) throws -> URLResourceValues {
        let resourceValues = try url.resourceValues(forKeys: Self.noteResourceKeys)

        if resourceValues.isSymbolicLink == true {
            throw NoteImportError.unsafeFile(url, "symbolic links are not imported as notes")
        }

        if resourceValues.isRegularFile != true {
            throw NoteImportError.unsafeFile(url, "only regular Markdown files are imported as notes")
        }

        guard isInsideNotesDirectory(url) else {
            throw NoteImportError.unsafeFile(url, "resolved path is outside the notes folder")
        }

        return resourceValues
    }

    private func isInsideNotesDirectory(_ url: URL) -> Bool {
        let folderPath = notesDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let filePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
        return filePath.hasPrefix(prefix)
    }

    private func readNote(at url: URL, resourceValues: URLResourceValues) throws -> Note {
        let content = try String(contentsOf: url, encoding: .utf8)

        return Note(
            id: noteID(for: url),
            title: Note.deriveTitle(from: content),
            content: content,
            fileURL: url,
            createdAt: resourceValues.creationDate ?? Date(),
            updatedAt: resourceValues.contentModificationDate ?? Date()
        )
    }

    private func preserveConflict(for note: Note, originalDiskContent: String) throws {
        let wasCurrent = currentNoteID == note.id
        let reloadedOriginal = try reloadedNote(for: note, content: originalDiskContent)
        updateInMemory(reloadedOriginal)
        lastKnownDiskContent[note.id] = originalDiskContent

        let conflict = try createConflictCopy(from: note)
        notes.append(conflict)
        lastKnownDiskContent[conflict.id] = conflict.content
        if wasCurrent {
            currentNoteID = conflict.id
        }
        rebuildSearchIndex()
    }

    private func preserveDirtyDeletedNote(_ note: Note) throws {
        let wasCurrent = currentNoteID == note.id
        cancelPendingSave(for: note.id)
        removeInMemoryNote(id: note.id)
        lastKnownDiskContent[note.id] = nil

        let conflict = try createConflictCopy(from: note)
        notes.append(conflict)
        lastKnownDiskContent[conflict.id] = conflict.content
        if wasCurrent {
            currentNoteID = conflict.id
        }
        rebuildSearchIndex()
    }

    private func reloadedNote(for note: Note, content: String) throws -> Note {
        let attrs = try? note.fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return Note(
            id: note.id,
            title: Note.deriveTitle(from: content),
            content: content,
            fileURL: note.fileURL,
            createdAt: attrs?.creationDate ?? note.createdAt,
            updatedAt: attrs?.contentModificationDate ?? Date()
        )
    }

    private func createConflictCopy(from note: Note) throws -> Note {
        let conflictURL = nextAvailableConflictURL(for: note.fileURL)
        let conflict = Note(
            id: noteID(for: conflictURL),
            title: note.title,
            content: note.content,
            fileURL: conflictURL,
            createdAt: Date(),
            updatedAt: Date()
        )
        try writeNoteToDisk(conflict)
        return conflict
    }

    private func nextAvailableConflictURL(for originalURL: URL) -> URL {
        let folder = originalURL.deletingLastPathComponent()
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let timestamp = Self.conflictTimestampFormatter.string(from: Date())
        let proposedName = "\(baseName) (Ink conflict \(timestamp)).md"
        var candidate = folder.appendingPathComponent(proposedName)
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName) (Ink conflict \(timestamp)-\(suffix)).md")
            suffix += 1
        }

        return candidate
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

    private func removeInMemoryNote(id: UUID) {
        notes.removeAll { $0.id == id }
        if currentNoteID == id {
            currentNoteID = notes.first?.id
        }
    }

    private func rebuildSearchIndex() {
        searchIndex = Dictionary(uniqueKeysWithValues: notes.map { note in
            (note.id, indexText(for: note))
        })
    }

    private func updateSearchIndex(for note: Note) {
        searchIndex[note.id] = indexText(for: note)
    }

    private func indexText(for note: Note) -> String {
        "\(note.title.lowercased()) \(note.content.lowercased())"
    }

    private func noteID(for url: URL) -> UUID {
        let name = url.deletingPathExtension().lastPathComponent
        if name.hasPrefix("note-") {
            let rawID = String(name.dropFirst("note-".count))
            if let id = UUID(uuidString: rawID) {
                return id
            }
        }

        return Self.deterministicID(for: relativeNotePath(for: url))
    }

    private func relativeNotePath(for url: URL) -> String {
        let folderPath = notesDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let filePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
        if filePath.hasPrefix(prefix) {
            return String(filePath.dropFirst(prefix.count))
        }
        return url.lastPathComponent
    }

    private static func deterministicID(for path: String) -> UUID {
        let digest = SHA256.hash(data: Data(path.utf8))
        let bytes = Array(digest.prefix(16))
        let uuid = uuid_t(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }

    private static let conflictTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        return formatter
    }()

    private func recordFailure(_ message: String, error: Error) {
        saveState = .failed(message)
        Self.logger.error("\(message, privacy: .public): \(String(describing: error), privacy: .public)")
    }
}
