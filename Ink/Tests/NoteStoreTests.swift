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
        let first = store.createNewNote()
        store.updateCurrentNoteContent("# First\nUnsaved before new note")

        _ = store.createNewNote()

        let saved = try String(contentsOf: first.fileURL, encoding: .utf8)
        XCTAssertEqual(saved, "# First\nUnsaved before new note")
    }

    func testSelectingNoteFlushesPreviousNote() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let first = store.createNewNote()
        let second = store.createNewNote()
        store.selectNote(id: first.id)
        store.updateCurrentNoteContent("First pending content")

        store.selectNote(id: second.id)

        let saved = try String(contentsOf: first.fileURL, encoding: .utf8)
        XCTAssertEqual(saved, "First pending content")
    }

    func testDeletingNoteCancelsPendingSave() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let note = store.createNewNote()
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
        let note = store.createNewNote()
        store.updateCurrentNoteContent("Saved before moving folders")

        store.changeNotesDirectory(to: secondFolder)

        let saved = try String(contentsOf: note.fileURL, encoding: .utf8)
        XCTAssertEqual(saved, "Saved before moving folders")
        XCTAssertEqual(store.notesDirectory, secondFolder)
        XCTAssertTrue(store.notes.isEmpty)
    }

    func testExistingNotesMigrateToStableNoteFilenames() throws {
        let legacy = tempRoot.appendingPathComponent("untitled-abcd1234.md")
        try "Legacy content".write(to: legacy, atomically: true, encoding: .utf8)

        let store = NoteStore(notesDirectory: tempRoot)

        XCTAssertEqual(store.notes.count, 1)
        let note = try XCTUnwrap(store.notes.first)
        XCTAssertTrue(note.fileURL.lastPathComponent.hasPrefix("note-"))
        XCTAssertEqual(try String(contentsOf: note.fileURL, encoding: .utf8), "Legacy content")
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))

        let reloaded = NoteStore(notesDirectory: tempRoot)
        XCTAssertEqual(reloaded.notes.first?.id, note.id)
    }
}
