import XCTest
@testable import Ink

@MainActor
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

    func testCreateNewNoteFlushesPreviousNote() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let first = try XCTUnwrap(store.createNewNote())
        store.updateCurrentNoteContent("# First\nUnsaved before new note")

        _ = store.createNewNote()

        let saved = try String(contentsOf: first.fileURL, encoding: .utf8)
        XCTAssertEqual(saved, "# First\nUnsaved before new note")
    }

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

}
