import SwiftUI
import AppKit

/// A floating panel that behaves like Spotlight.
/// - Never activates the app (user stays in whatever they were doing)
/// - Stays above other windows
/// - Visible on all Spaces + fullscreen apps
/// - Dismisses on Esc / click outside / resign key
final class FloatingNotePanel: NSPanel {
    var onDismissRequest: (() -> Void)?

    init<Content: View>(@ViewBuilder content: () -> Content,
                        contentRect: NSRect = NSRect(x: 0, y: 0, width: 720, height: 520)) {

        super.init(
            contentRect: contentRect,
            styleMask: [
                .nonactivatingPanel,   // <-- This is the magic for "doesn't steal focus from other apps"
                .titled,
                .closable,
                .fullSizeContentView,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        // Visuals matching the screenshots (dark, clean, minimal chrome)
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.backgroundColor = NSColor.clear   // SwiftUI view will draw the background
        self.isOpaque = false

        // Floating behavior
        self.isFloatingPanel = true
        self.level = .floating
        self.hidesOnDeactivate = false          // Important: stays visible when you click other apps
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Interaction
        self.isMovableByWindowBackground = true
        self.becomesKeyOnlyIfNeeded = true      // Only becomes key when a text field truly needs it

        // Animation feels
        self.animationBehavior = .utilityWindow

        // Host the SwiftUI content
        let hostingView = NSHostingView(rootView: content())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView = hostingView

        // Nice rounded corners + subtle shadow (the screenshots have a soft modern look)
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 16
        self.contentView?.layer?.masksToBounds = true
        self.hasShadow = true
    }

    // MARK: - Key behavior overrides

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Close when user clicks outside (or switches Spaces in certain ways)
    override func resignKey() {
        super.resignKey()
        onDismissRequest?()
    }

    /// Allow Esc key to close the panel from anywhere inside
    override func cancelOperation(_ sender: Any?) {
        onDismissRequest?()
    }
}
