import XCTest
@testable import Ink

final class FloatingPanelControllerTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("InkPanelTests-\(UUID().uuidString)", isDirectory: true)
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
    func testExternalCreateRequestDoesNotCreateNoteUntilAccepted() {
        let store = NoteStore(notesDirectory: tempRoot)
        let controller = FloatingPanelController(noteStore: store)
        defer { controller.hide() }

        controller.showExternalRequest(.createNote)
        controller.showExternalRequest(.createNote)

        XCTAssertEqual(store.notes.count, 0)
        XCTAssertEqual(controller.mode, .externalRequest)
        XCTAssertEqual(controller.externalLinkRequest, .createNote)

        controller.acceptExternalRequest()

        XCTAssertEqual(store.notes.count, 1)
        XCTAssertNil(controller.externalLinkRequest)
        XCTAssertEqual(controller.mode, .editor)
    }

    @MainActor
    func testExternalOpenRequestDoesNotSwitchNotesUntilAccepted() throws {
        let store = NoteStore(notesDirectory: tempRoot)
        let first = try XCTUnwrap(store.createNewNote())
        let second = try XCTUnwrap(store.createNewNote())
        let controller = FloatingPanelController(noteStore: store)
        defer { controller.hide() }

        controller.showExternalRequest(.openNote(first.id))

        XCTAssertEqual(store.currentNoteID, second.id)
        XCTAssertEqual(controller.mode, .externalRequest)
        XCTAssertEqual(controller.externalLinkRequest, .openNote(first.id))

        controller.acceptExternalRequest()

        XCTAssertEqual(store.currentNoteID, first.id)
        XCTAssertNil(controller.externalLinkRequest)
        XCTAssertEqual(controller.mode, .editor)
    }
}
