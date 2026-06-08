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

    /// Per-file metadata signature cache, keyed by standardized fileURL.
    /// Lets `reconcileExternalChanges()` skip full-content reads for files
    /// whose (modification date, size) are unchanged since the last scan.
    private var fileSignatures: [URL: FileSignature] = [:]
    // `nonisolated(unsafe)`: set on the main actor in `startWatching()`, fired on
    // `RunLoop.main`, and read in `deinit` only once no other references remain —
    // so there is no concurrent access. This lets the nonisolated deinit invalidate it.
    nonisolated(unsafe) private var refreshTimer: Timer?

    private struct FileSignature: Equatable {
        let modified: Date
        let size: Int
    }

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

        startWatching()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    /// Starts a lightweight repeating poll that pulls clean external edits into
    /// the UI between panel shows. Reconcile is metadata-cheap (FIX #6) and skips
    /// dirty (pending-save) notes, so this no-ops when nothing changed and never
    /// spawns conflict copies for clean external edits.
    private func startWatching() {
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reconcileExternalChanges()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
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

    @discardableResult
    func selectNote(id: UUID) -> Bool {
        flushPendingSave(for: currentNoteID)
        reconcileExternalChanges()
        guard containsNote(id: id) else { return false }
        currentNoteID = id
        return true
    }

    func containsNote(id: UUID) -> Bool {
        notes.contains { $0.id == id }
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
        // Full reload: drop any cached signatures so every file is read fresh
        // and the cache is reseeded from scratch.
        fileSignatures.removeAll()
        var loaded = try readNotesFromDisk(reusingInMemory: false)
        loaded = notesByResolvingDuplicateIDs(loaded)

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
            let diskNotes = notesByResolvingDuplicateIDs(try readNotesFromDisk(reusingInMemory: true))
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

    func notesByResolvingDuplicateIDs(_ loaded: [Note]) -> [Note] {
        var usedIDs = Set<UUID>()
        var resolved: [Note] = []

        for note in loaded.sorted(by: duplicatePreferredOrder) {
            if usedIDs.insert(note.id).inserted {
                resolved.append(note)
            } else {
                resolved.append(noteByRekeyingDuplicateID(note, usedIDs: &usedIDs))
            }
        }

        return resolved
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
            if let baseline = lastKnownDiskContent[note.id] {
                let fileExists = fileManager.fileExists(atPath: note.fileURL.path)
                let diskData = try? Data(contentsOf: note.fileURL)

                if fileExists, let diskData {
                    // Compare RAW BYTES so a non-UTF-8 external edit (which still
                    // reads as non-nil Data) is detected and never overwritten.
                    if diskData != Data(baseline.utf8) {
                        try preserveConflict(
                            for: note,
                            originalDiskContent: String(decoding: diskData, as: UTF8.self)
                        )
                        saveState = .failed("External edit preserved; Ink copy saved")
                        return
                    }
                    // Bytes equal the baseline → safe to fall through to the write.
                } else if fileExists {
                    // File is present but unreadable (transient IO/permission error).
                    // Do NOT overwrite: save the pending content as a conflict copy and
                    // leave the original bytes alone.
                    try preserveUnreadableConflict(note)
                    saveState = .failed("Existing file unreadable; Ink copy saved")
                    return
                } else {
                    // File was deleted out from under Ink while we had pending content.
                    try preserveDirtyDeletedNote(note)
                    saveState = .failed("Deleted note preserved as Ink copy")
                    return
                }
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
        // Record the post-write signature so the next reconcile does not need to
        // re-read Ink's own writes (and conflict copies route through here too).
        recordSignature(for: note.fileURL)
    }

    /// Canonical cache key for a note file. `contentsOfDirectory` URLs are not
    /// pre-standardized, so every signature read/write must funnel through this
    /// to guarantee dictionary hits.
    private func signatureKey(for url: URL) -> URL {
        url.standardizedFileURL
    }

    private func signature(from resourceValues: URLResourceValues) -> FileSignature? {
        guard let modified = resourceValues.contentModificationDate else { return nil }
        return FileSignature(modified: modified, size: resourceValues.fileSize ?? 0)
    }

    @discardableResult
    private func recordSignature(for url: URL) -> FileSignature? {
        guard let resourceValues = try? url.resourceValues(
            forKeys: [.contentModificationDateKey, .fileSizeKey]
        ), let sig = signature(from: resourceValues) else {
            return nil
        }
        fileSignatures[signatureKey(for: url)] = sig
        return sig
    }

    private func readNotesFromDisk(reusingInMemory: Bool) throws -> [Note] {
        try Self.ensureDirectoryExists(at: notesDirectory, fileManager: fileManager)

        let urls = try fileManager.contentsOfDirectory(
            at: notesDirectory,
            includingPropertiesForKeys: Array(Self.noteResourceKeys),
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "md" }

        // Index existing in-memory notes by canonical fileURL so we can reuse a
        // note's already-loaded content when its on-disk signature is unchanged.
        let inMemoryByURL: [URL: Note] = reusingInMemory
            ? Dictionary(notes.map { (signatureKey(for: $0.fileURL), $0) }, uniquingKeysWith: { first, _ in first })
            : [:]

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

                let key = signatureKey(for: url)
                let currentSignature = signature(from: resourceValues)

                // Reuse path: signature matches the cache AND a matching in-memory
                // note exists AND it has a recorded disk baseline. Reproduce exactly
                // what a full read would yield (recomputed id + derived title +
                // baseline content) but skip String(contentsOf:).
                if reusingInMemory,
                   let cached = fileSignatures[key],
                   let current = currentSignature,
                   cached == current,
                   let existing = inMemoryByURL[key],
                   let baseline = lastKnownDiskContent[existing.id] {
                    loaded.append(try reusedNote(at: url, content: baseline, resourceValues: resourceValues))
                    importedBytes += fileBytes
                    continue
                }

                loaded.append(try readNote(at: url, resourceValues: resourceValues))
                if let currentSignature {
                    fileSignatures[key] = currentSignature
                }
                importedBytes += fileBytes
            } catch {
                recordFailure("Could not load note at \(url.path)", error: error)
            }
        }

        return loaded
    }

    /// Builds a Note for a file whose content is already known (unchanged on
    /// disk), byte-identical to what `readNote(at:resourceValues:)` would produce
    /// for the same content — so duplicate resolution and reconcile merge behave
    /// the same whether or not the read was skipped.
    private func reusedNote(at url: URL, content: String, resourceValues: URLResourceValues) throws -> Note {
        Note(
            id: noteID(for: url),
            title: Note.deriveTitle(from: content),
            content: content,
            fileURL: url,
            createdAt: resourceValues.creationDate ?? Date(),
            updatedAt: resourceValues.contentModificationDate ?? Date()
        )
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

        // Perform the fallible write FIRST. If it throws, no in-memory state or
        // baseline has been mutated yet, so the next retry still detects the
        // external edit and re-runs conflict preservation (FIX #8).
        let conflict = try createConflictCopy(from: note)

        let reloadedOriginal = try reloadedNote(for: note, content: originalDiskContent)
        updateInMemory(reloadedOriginal)
        lastKnownDiskContent[note.id] = originalDiskContent

        notes.append(conflict)
        lastKnownDiskContent[conflict.id] = conflict.content
        if wasCurrent {
            currentNoteID = conflict.id
        }
        rebuildSearchIndex()
    }

    /// Preserves the user's pending content when the original file is present but
    /// unreadable. Writes a NEW conflict copy and leaves the original (and its
    /// in-memory note) untouched, so even unreadable bytes are never destroyed.
    private func preserveUnreadableConflict(_ note: Note) throws {
        let wasCurrent = currentNoteID == note.id

        // Fallible write first; nothing else has been mutated if this throws.
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

    private func duplicatePreferredOrder(_ lhs: Note, _ rhs: Note) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.fileURL.lastPathComponent.localizedStandardCompare(rhs.fileURL.lastPathComponent) == .orderedAscending
    }

    private func noteByRekeyingDuplicateID(_ note: Note, usedIDs: inout Set<UUID>) -> Note {
        let basePath = relativeNotePath(for: note.fileURL)
        var suffix = 1
        var replacementID: UUID

        repeat {
            let stablePath = suffix == 1
                ? "duplicate-note-id:\(basePath)"
                : "duplicate-note-id:\(basePath)#\(suffix)"
            replacementID = Self.deterministicID(for: stablePath)
            suffix += 1
        } while usedIDs.contains(replacementID)

        usedIDs.insert(replacementID)
        return Note(
            id: replacementID,
            title: note.title,
            content: note.content,
            fileURL: note.fileURL,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt
        )
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
