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

    @MainActor
    func testClampedFrameKeepsFrameFullyOnScreen() throws {
        guard let main = NSScreen.main else {
            throw XCTSkip("No main screen available in this environment")
        }
        let visible = main.visibleFrame

        // Deliberately oversized AND far offscreen so we exercise both the
        // size-min clamp and the origin clamp. Pin to the main screen so the
        // result is deterministic on multi-monitor machines (a zero-overlap
        // frame would otherwise resolve to an arbitrary screen).
        let offscreen = NSRect(
            x: visible.maxX + 5000,
            y: visible.maxY + 5000,
            width: visible.width + 1000,
            height: visible.height + 1000
        )

        let clamped = FloatingPanelController.clampedFrame(
            offscreen,
            screens: [main],
            fallback: main
        )

        // Size never exceeds the visible area.
        XCTAssertLessThanOrEqual(clamped.width, visible.width)
        XCTAssertLessThanOrEqual(clamped.height, visible.height)

        // Origin keeps the (clamped) frame fully within the visible area.
        XCTAssertGreaterThanOrEqual(clamped.minX, visible.minX)
        XCTAssertGreaterThanOrEqual(clamped.minY, visible.minY)
        XCTAssertLessThanOrEqual(clamped.maxX, visible.maxX)
        XCTAssertLessThanOrEqual(clamped.maxY, visible.maxY)
    }
}
