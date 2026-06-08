import XCTest
@testable import Ink

final class NoteStoreTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("InkTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        UserDefaults.standard.removeObject(forKey: "notesDirectoryPath")
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        UserDefaults.standard.removeObject(forKey: "notesDirectoryPath")
    }

    @MainActor
    func testCreateNewNoteFlushesPreviousNote() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let first = try XCTUnwrap(store.createNewNote())
        store.updateCurrentNoteContent("# First\nUnsaved before new note")

        _ = store.createNewNote()

        let saved = try String(contentsOf: first.fileURL, encoding: .utf8)
        XCTAssertEqual(saved, "# First\nUnsaved before new note")
    }

    @MainActor
    func testSelectingNoteFlushesPreviousNote() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let first = try XCTUnwrap(store.createNewNote())
        let second = try XCTUnwrap(store.createNewNote())
        store.selectNote(id: first.id)
        store.updateCurrentNoteContent("First pending content")

        store.selectNote(id: second.id)

        let saved = try String(contentsOf: first.fileURL, encoding: .utf8)
        XCTAssertEqual(saved, "First pending content")
    }

    @MainActor
    func testSelectingMissingNoteReturnsFalseAndKeepsCurrentNote() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let note = try XCTUnwrap(store.createNewNote())

        let didSelect = store.selectNote(id: UUID())

        XCTAssertFalse(didSelect)
        XCTAssertEqual(store.currentNoteID, note.id)
    }

    @MainActor
    func testDeletingNoteMovesFileToTrashAndCancelsPendingSave() throws {
        let trashFolder = tempRoot.appendingPathComponent("Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashFolder, withIntermediateDirectories: true)
        var trashedURL: URL?
        let store = NoteStore(notesDirectory: tempRoot) { url in
            let destination = trashFolder.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: destination)
            trashedURL = destination
        }
        let note = try XCTUnwrap(store.createNewNote())
        store.updateCurrentNoteContent("This should not come back")

        store.deleteNote(id: note.id)

        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        XCTAssertFalse(FileManager.default.fileExists(atPath: note.fileURL.path))
        let movedFile = try XCTUnwrap(trashedURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: movedFile.path))
        XCTAssertEqual(try String(contentsOf: movedFile, encoding: .utf8), "")
    }

    @MainActor
    func testChangingFolderFlushesAndReloads() throws {
        let firstFolder = tempRoot.appendingPathComponent("First", isDirectory: true)
        let secondFolder = tempRoot.appendingPathComponent("Second", isDirectory: true)
        try FileManager.default.createDirectory(at: secondFolder, withIntermediateDirectories: true)

        let store = NoteStore(notesDirectory: firstFolder)
        let note = try XCTUnwrap(store.createNewNote())
        store.updateCurrentNoteContent("Saved before moving folders")

        store.changeNotesDirectory(to: secondFolder)

        let saved = try String(contentsOf: note.fileURL, encoding: .utf8)
        XCTAssertEqual(saved, "Saved before moving folders")
        XCTAssertEqual(store.notesDirectory, secondFolder)
        XCTAssertTrue(store.notes.isEmpty)
    }

    @MainActor
    func testExistingMarkdownFilesKeepTheirFilenames() throws {
        let existing = tempRoot.appendingPathComponent("meeting-notes.md")
        try "Existing content".write(to: existing, atomically: true, encoding: .utf8)

        let store = NoteStore(notesDirectory: tempRoot)

        XCTAssertEqual(store.notes.count, 1)
        let note = try XCTUnwrap(store.notes.first)
        XCTAssertEqual(note.fileURL.lastPathComponent, "meeting-notes.md")
        XCTAssertEqual(try String(contentsOf: note.fileURL, encoding: .utf8), "Existing content")
        XCTAssertTrue(FileManager.default.fileExists(atPath: existing.path))
        let filenames = try FileManager.default.contentsOfDirectory(atPath: tempRoot.path)
        XCTAssertFalse(filenames.contains { $0.hasPrefix("note-") })

        store.selectNote(id: note.id)
        store.updateCurrentNoteContent("Updated in place")
        store.flushPendingSaves()
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "Updated in place")

        let reloaded = NoteStore(notesDirectory: tempRoot)
        XCTAssertEqual(reloaded.notes.first?.id, note.id)
    }

    @MainActor
    func testCreateNewNoteDoesNotSelectUnsavedNoteWhenWriteFails() throws {
        let fileURL = tempRoot.appendingPathComponent("not-a-folder")
        try "not a directory".write(to: fileURL, atomically: true, encoding: .utf8)

        let store = NoteStore(notesDirectory: fileURL)
        let note = store.createNewNote()

        XCTAssertNil(note)
        XCTAssertNil(store.currentNoteID)
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.appendingPathComponent("Ink").path))
    }

    @MainActor
    func testCleanExternalEditReloadsWithoutOverwrite() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let note = try XCTUnwrap(store.createNewNote())
        store.updateCurrentNoteContent("# Original\nInk content")
        store.flushPendingSaves()

        try "# External\nEdited elsewhere".write(to: note.fileURL, atomically: true, encoding: .utf8)
        store.reconcileExternalChanges()

        XCTAssertEqual(store.currentNote?.content, "# External\nEdited elsewhere")
        XCTAssertEqual(store.currentNote?.title, "External")
        XCTAssertEqual(try String(contentsOf: note.fileURL, encoding: .utf8), "# External\nEdited elsewhere")
        XCTAssertEqual(store.searchNotes(query: "elsewhere").first?.id, note.id)
    }

    @MainActor
    func testPendingInkEditDoesNotOverwriteExternalEdit() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let note = try XCTUnwrap(store.createNewNote())
        store.updateCurrentNoteContent("Baseline")
        store.flushPendingSaves()

        try "External edit".write(to: note.fileURL, atomically: true, encoding: .utf8)
        store.updateCurrentNoteContent("Ink local edit")
        store.flushPendingSaves()

        XCTAssertEqual(try String(contentsOf: note.fileURL, encoding: .utf8), "External edit")

        let markdownFiles = try FileManager.default.contentsOfDirectory(
            at: tempRoot,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "md" }

        XCTAssertEqual(markdownFiles.count, 2)
        XCTAssertTrue(markdownFiles.contains { $0.lastPathComponent.contains("Ink conflict") })
        XCTAssertTrue(markdownFiles.contains { (try? String(contentsOf: $0, encoding: .utf8)) == "Ink local edit" })
        XCTAssertEqual(store.currentNote?.content, "Ink local edit")
    }

    @MainActor
    func testExternalNewMarkdownFileAppearsAfterReconcile() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        XCTAssertTrue(store.notes.isEmpty)

        let external = tempRoot.appendingPathComponent("from-obsidian.md")
        try "# Imported\nExternal content".write(to: external, atomically: true, encoding: .utf8)

        store.reconcileExternalChanges()

        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.notes.first?.fileURL.lastPathComponent, "from-obsidian.md")
        XCTAssertEqual(
            store.searchNotes(query: "imported").first?.fileURL.standardizedFileURL,
            external.standardizedFileURL
        )
    }

    @MainActor
    func testSymlinkedMarkdownFileIsNotImported() throws {
        let safe = tempRoot.appendingPathComponent("safe.md")
        try "# Safe\nExpected content".write(to: safe, atomically: true, encoding: .utf8)

        let outside = tempRoot
            .deletingLastPathComponent()
            .appendingPathComponent("outside-\(UUID().uuidString).md")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: outside)
        }
        try "# Secret\nShould not be imported".write(to: outside, atomically: true, encoding: .utf8)

        let symlink = tempRoot.appendingPathComponent("linked-secret.md")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)

        let store = NoteStore(notesDirectory: tempRoot)

        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.notes.first?.fileURL.standardizedFileURL, safe.standardizedFileURL)
        XCTAssertEqual(store.searchNotes(query: "secret").count, 0)
    }

    @MainActor
    func testOversizedMarkdownFileIsNotImported() throws {
        let oversized = tempRoot.appendingPathComponent("oversized.md")
        try "This file exceeds the tiny test limit".write(to: oversized, atomically: true, encoding: .utf8)

        let store = NoteStore(
            notesDirectory: tempRoot,
            importLimits: .init(maxNoteCount: 10, maxFileBytes: 8, maxTotalBytes: 1024)
        )

        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertTrue(store.searchNotes(query: "exceeds").isEmpty)
    }

    @MainActor
    func testImportStopsAtNoteCountLimit() throws {
        try "First".write(
            to: tempRoot.appendingPathComponent("first.md"),
            atomically: true,
            encoding: .utf8
        )
        try "Second".write(
            to: tempRoot.appendingPathComponent("second.md"),
            atomically: true,
            encoding: .utf8
        )

        let store = NoteStore(
            notesDirectory: tempRoot,
            importLimits: .init(maxNoteCount: 1, maxFileBytes: 1024, maxTotalBytes: 1024)
        )

        XCTAssertEqual(store.notes.count, 1)
    }

    @MainActor
    func testDuplicateParsedNoteIDsAreRekeyedWithoutDroppingFiles() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let duplicateID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let olderDate = Date(timeIntervalSince1970: 1)
        let newerDate = Date(timeIntervalSince1970: 2)

        let older = Note(
            id: duplicateID,
            title: "Older",
            content: "Older duplicate",
            fileURL: tempRoot.appendingPathComponent("note-\(duplicateID.uuidString.lowercased()).md"),
            createdAt: olderDate,
            updatedAt: olderDate
        )
        let newer = Note(
            id: duplicateID,
            title: "Newer",
            content: "Newer duplicate",
            fileURL: tempRoot.appendingPathComponent("note-\(duplicateID.uuidString.uppercased()).md"),
            createdAt: newerDate,
            updatedAt: newerDate
        )

        let resolved = store.notesByResolvingDuplicateIDs([older, newer])

        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(Set(resolved.map(\.id)).count, 2)
        XCTAssertEqual(resolved.first { $0.title == "Newer" }?.id, duplicateID)
        XCTAssertNotEqual(resolved.first { $0.title == "Older" }?.id, duplicateID)
    }

    @MainActor
    func testExternalDeletionRemovesCleanNote() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let note = try XCTUnwrap(store.createNewNote())
        store.updateCurrentNoteContent("Will be deleted elsewhere")
        store.flushPendingSaves()

        try FileManager.default.removeItem(at: note.fileURL)
        store.reconcileExternalChanges()

        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertNil(store.currentNoteID)
    }

    @MainActor
    func testExternalDeletionPreservesDirtyNoteAsConflictCopy() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let note = try XCTUnwrap(store.createNewNote())
        store.updateCurrentNoteContent("Baseline")
        store.flushPendingSaves()

        try FileManager.default.removeItem(at: note.fileURL)
        store.updateCurrentNoteContent("Unsaved Ink content")
        store.flushPendingSaves()

        let markdownFiles = try FileManager.default.contentsOfDirectory(
            at: tempRoot,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "md" }

        XCTAssertEqual(markdownFiles.count, 1)
        let conflict = try XCTUnwrap(markdownFiles.first)
        XCTAssertTrue(conflict.lastPathComponent.contains("Ink conflict"))
        XCTAssertEqual(try String(contentsOf: conflict, encoding: .utf8), "Unsaved Ink content")
        XCTAssertEqual(store.currentNote?.fileURL.standardizedFileURL, conflict.standardizedFileURL)
    }

    @MainActor
    func testNonUTF8ExternalEditIsPreservedAndOriginalBytesUntouched() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let note = try XCTUnwrap(store.createNewNote())
        store.updateCurrentNoteContent("# Baseline\nValid UTF-8 content")
        store.flushPendingSaves()

        // An external editor writes non-UTF-8 / invalid bytes over the file.
        let rawBytes = Data([0xFF, 0xFE, 0x00, 0x01])
        try rawBytes.write(to: note.fileURL, options: .atomic)

        // Ink has a pending local edit and tries to autosave.
        store.updateCurrentNoteContent("Ink local edit over invalid bytes")
        store.flushPendingSaves()

        // The original file's raw bytes must be untouched (not overwritten).
        let onDisk = try Data(contentsOf: note.fileURL)
        XCTAssertEqual(onDisk, rawBytes)

        let markdownFiles = try FileManager.default.contentsOfDirectory(
            at: tempRoot,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "md" }

        // Original + one new conflict copy.
        XCTAssertEqual(markdownFiles.count, 2)
        let conflict = try XCTUnwrap(markdownFiles.first { $0.lastPathComponent.contains("Ink conflict") })
        XCTAssertEqual(
            try String(contentsOf: conflict, encoding: .utf8),
            "Ink local edit over invalid bytes"
        )

        // The save state reflects a preserved conflict rather than a clean save.
        XCTAssertEqual(store.saveState, .failed("External edit preserved; Ink copy saved"))
    }

    @MainActor
    func testPreserveConflictReloadsExternalContentIntoOriginalNote() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let note = try XCTUnwrap(store.createNewNote())
        store.updateCurrentNoteContent("# Baseline\nInk content")
        store.flushPendingSaves()

        // A UTF-8 external edit lands on disk.
        try "# External\nEdited elsewhere".write(to: note.fileURL, atomically: true, encoding: .utf8)

        // Ink has a pending local edit and tries to autosave.
        store.updateCurrentNoteContent("Ink pending edit")
        store.flushPendingSaves()

        // The original on-disk file now holds the external content (untouched by Ink).
        XCTAssertEqual(
            try String(contentsOf: note.fileURL, encoding: .utf8),
            "# External\nEdited elsewhere"
        )

        // The in-memory original note was reloaded to the external content...
        let original = try XCTUnwrap(store.notes.first { $0.id == note.id })
        XCTAssertEqual(original.content, "# External\nEdited elsewhere")

        // ...and a conflict copy holds the user's pending Ink edit and is now current.
        let markdownFiles = try FileManager.default.contentsOfDirectory(
            at: tempRoot,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "md" }
        XCTAssertEqual(markdownFiles.count, 2)
        let conflict = try XCTUnwrap(markdownFiles.first { $0.lastPathComponent.contains("Ink conflict") })
        XCTAssertEqual(try String(contentsOf: conflict, encoding: .utf8), "Ink pending edit")
        XCTAssertEqual(store.currentNote?.content, "Ink pending edit")
    }

}
