import SwiftUI
import AppKit
import KeyboardShortcuts

/// Owns the single FloatingNotePanel instance for the whole app.
/// Handles:
/// - Global hotkey registration (⌘N create, ⌘P browse/toggle, ⌘K action panel)
/// - Show / hide / toggle logic
/// - Smart positioning (center on first show, remember last position)
/// - Switching between Editor and Browse modes inside the same panel
@MainActor
final class FloatingPanelController: ObservableObject {

    // The actual native panel
    private var panel: FloatingNotePanel?

    // The single source of truth for all notes
    let noteStore: NoteStore

    // What the panel is currently showing
    @Published var mode: PanelMode = .editor

    enum PanelMode {
        case editor
        case browse
        case actionPalette   // overlay on top of current mode
    }

    // Last known frame so we can restore position
    private var lastFrame: NSRect?

    init(noteStore: NoteStore) {
        self.noteStore = noteStore
        setupKeyboardShortcuts()
    }

    // MARK: - Hotkeys (the soul of the app)

    private func setupKeyboardShortcuts() {
        // Create Note — the most important "zero friction" command
        KeyboardShortcuts.onKeyUp(for: .createNote) { [weak self] in
            self?.createAndShow()
        }

        // Toggle / Browse Notes (main panel toggle + search)
        KeyboardShortcuts.onKeyUp(for: .toggleNotes) { [weak self] in
            self?.toggleBrowseOrEditor()
        }

        // Action Panel (⌘K) — the powerful command palette
        KeyboardShortcuts.onKeyUp(for: .showActionPanel) { [weak self] in
            self?.showActionPanel()
        }
    }

    // MARK: - Public API used by the rest of the app

    /// Shows the panel with the editor focused on the current (or newly created) note.
    func showEditor() {
        mode = .editor
        ensurePanelExistsAndShow()
        // Focus the text editor after a tiny delay so the view is in the hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // The SwiftUI side will observe .onAppear and becomeFirstResponder
            NotificationCenter.default.post(name: .focusEditor, object: nil)
        }
    }

    /// Shows the panel in browse/search mode (⌘P behavior).
    func showBrowse() {
        mode = .browse
        ensurePanelExistsAndShow()
    }

    /// Creates a fresh note and immediately shows the editor.
    func createAndShow() {
        _ = noteStore.createNewNote()
        showEditor()
    }

    /// Toggles between editor and browse, or shows the panel if it was hidden.
    func toggleBrowseOrEditor() {
        if panel?.isVisible == true {
            // Already visible — switch modes
            mode = (mode == .editor) ? .browse : .editor
        } else {
            // Not visible — decide intelligently
            if noteStore.currentNote != nil {
                showEditor()
            } else {
                showBrowse()
            }
        }
    }

    func showActionPanel() {
        // We keep the underlying mode (editor or browse) and just overlay the palette
        mode = .actionPalette
        ensurePanelExistsAndShow()
    }

    func dismissActionPanel() {
        // Go back to whatever we were doing
        mode = (noteStore.currentNote != nil) ? .editor : .browse
    }

    /// Completely hides the floating panel.
    func hide() {
        panel?.close()
        panel = nil   // we recreate on next show (cheap and avoids state issues)
    }

    // MARK: - Internal panel lifecycle

    private func ensurePanelExistsAndShow() {
        if panel == nil {
            createPanel()
        }
        positionPanelIfNeeded()
        panel?.makeKeyAndOrderFront(nil)
        // Make sure the app is active enough for the panel (but not stealing focus globally)
        NSApp.activate(ignoringOtherApps: false)
    }

    private func createPanel() {
        let rootView = FloatingPanelRootView()
            .environmentObject(self)
            .environmentObject(noteStore)

        panel = FloatingNotePanel {
            rootView
        }

        // Restore previous position if we have one
        if let frame = lastFrame {
            panel?.setFrame(frame, display: true)
        } else {
            panel?.center()
        }

        // Observe when the user manually moves/resizes so we remember it
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.lastFrame = self?.panel?.frame
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.lastFrame = self?.panel?.frame
        }
    }

    private func positionPanelIfNeeded() {
        guard let panel = panel else { return }

        if lastFrame == nil {
            panel.center()
        } else if let frame = lastFrame {
            // Keep the same size, just make sure it's still on screen
            var newFrame = frame
            if let screen = NSScreen.main {
                let visible = screen.visibleFrame
                if !visible.contains(newFrame.origin) {
                    newFrame.origin = CGPoint(
                        x: visible.midX - newFrame.width / 2,
                        y: visible.midY - newFrame.height / 2
                    )
                }
            }
            panel.setFrame(newFrame, display: true)
        }
    }
}

// MARK: - Notification for focusing the editor from SwiftUI
extension Notification.Name {
    static let focusEditor = Notification.Name("Ink.FocusEditor")
}