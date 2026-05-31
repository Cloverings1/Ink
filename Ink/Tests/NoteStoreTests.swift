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

    func testDeletingNoteCancelsPendingSave() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let note = try XCTUnwrap(store.createNewNote())
        store.updateCurrentNoteContent("This should not come back")

        store.deleteNote(id: note.id)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        XCTAssertFalse(FileManager.default.fileExists(atPath: note.fileURL.path))
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
}
