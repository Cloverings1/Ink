import SwiftUI
import AppKit
import KeyboardShortcuts

@main
struct InkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No WindowGroup — all UI lives inside the custom NSPanel.
        // The app has a menu bar extra + floating panel (utility app style).
        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate

enum DeepLinkRoute: Equatable {
    case create
    case note(UUID)
    case ignored
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?

    private(set) var noteStore: NoteStore?
    private var panelController: FloatingPanelController?
    private var clipboardHistory: ClipboardHistoryStore?

    private var statusItem: NSStatusItem?
    private var pendingDeepLinks: [URL] = []
    private var settingsBridgeHost: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        guard !Self.isRunningUnitTests else { return }

        // 1. Data layer
        let store = NoteStore()
        noteStore = store

        // 1b. Clipboard history (polls the system pasteboard for the app lifetime)
        let clip = ClipboardHistoryStore()
        clipboardHistory = clip
        clip.start()

        // 1c. Hidden SwiftUI host to capture the `openSettings` environment action.
        installSettingsBridgeHost()

        // 2. Floating panel + hotkeys
        panelController = FloatingPanelController(noteStore: store)

        // 3. Menu bar extra
        setupMenuBarExtra()

        // 4. First-run welcome note
        if noteStore?.notes.isEmpty == true {
            if noteStore?.createNewNote() != nil {
                let content = """
                # Welcome to Ink

                This is your first note. Everything you write here is stored as a plain **Markdown** file on your Mac.

                - Press **⌥⌘N** from anywhere to create a new note instantly.
                - Press **⌥⌘P** to browse and search all your notes.
                - Press **⌥⌘K** to open the Action Panel.

                Your notes live here:
                \(noteStore?.notesDirectory.path ?? "")

                You own your data — open the files in any editor, Obsidian, VS Code, or git them.

                Happy thinking.
                """
                noteStore?.updateCurrentNoteContent(content)
            }
        }

        drainPendingDeepLinks()

        print("Ink launched — menu bar extra + global hotkeys.")
    }

    // MARK: - App reopened from activation path

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController?.showEditor()
        return true
    }

    // MARK: - Deeplink routing

    static func deepLinkRoute(for url: URL) -> DeepLinkRoute {
        guard url.scheme?.lowercased() == "ink" else { return .ignored }

        switch url.host?.lowercased() {
        case "create":
            return (url.path.isEmpty || url.path == "/") ? .create : .ignored

        case "note":
            let pathParts = url.pathComponents.filter { $0 != "/" }
            guard pathParts.count == 1, let uuid = UUID(uuidString: pathParts[0]) else {
                return .ignored
            }
            return .note(uuid)

        default:
            return .ignored
        }
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: - Menu bar extra

    private func setupMenuBarExtra() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        button.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Ink")
        button.toolTip = "Ink — Quick Notes"
        button.action = #selector(menuBarAction)
        button.target = self
        // NSStatusBarButton only sends on left-mouse-up by default; opt in to
        // right-mouse-up so control/right-click reaches `menuBarAction`.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func menuBarAction() {
        guard let event = NSApp.currentEvent else {
            panelController?.showEditor()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            panelController?.showEditor()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "New Note", action: #selector(createNote), keyEquivalent: "n")
        menu.addItem(withTitle: "Browse Notes", action: #selector(browseNotes), keyEquivalent: "p")
        menu.addItem(withTitle: "Action Panel", action: #selector(showActions), keyEquivalent: "k")
        menu.addItem(.separator())

        let clipboardItem = NSMenuItem(title: "Clipboard History", action: nil, keyEquivalent: "")
        clipboardItem.submenu = makeClipboardHistorySubmenu()
        menu.addItem(clipboardItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Ink", action: #selector(quit), keyEquivalent: "q")

        for item in menu.items {
            item.target = self
        }

        guard let button = statusItem?.button else { return }
        menu.popUp(positioning: nil, at: .zero, in: button)
    }

    private func makeClipboardHistorySubmenu() -> NSMenu {
        let submenu = NSMenu()
        let entries = clipboardHistory?.entries ?? []

        if entries.isEmpty {
            let empty = NSMenuItem(title: "No clipboard history yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            return submenu
        }

        for entry in entries.prefix(25) {
            let item = NSMenuItem(
                title: Self.previewTitle(for: entry.text),
                action: #selector(copyClipboardEntry(_:)),
                keyEquivalent: ""
            )
            item.toolTip = entry.text
            item.representedObject = entry.id
            item.target = self
            submenu.addItem(item)
        }

        submenu.addItem(.separator())
        let clear = NSMenuItem(
            title: "Clear Clipboard History",
            action: #selector(clearClipboardHistory),
            keyEquivalent: ""
        )
        clear.target = self
        submenu.addItem(clear)

        return submenu
    }

    /// Single-line, trimmed, ~50-char preview of an entry for the menu title.
    private static func previewTitle(for text: String) -> String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let limit = 50
        if flattened.count > limit {
            return String(flattened.prefix(limit)) + "…"
        }
        return flattened
    }

    // MARK: - Actions

    @objc private func createNote() {
        panelController?.createAndShow()
    }

    @objc private func browseNotes() {
        panelController?.showBrowse()
    }

    @objc private func showActions() {
        panelController?.showActionPanel()
    }

    @objc private func copyClipboardEntry(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let entry = clipboardHistory?.entries.first(where: { $0.id == id }) else {
            return
        }
        clipboardHistory?.copyToClipboard(entry)
    }

    @objc private func clearClipboardHistory() {
        clipboardHistory?.clearHistory()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        // Prefer the captured SwiftUI `openSettings` action (reliable on macOS
        // 14/15); fall back to the private selector so behavior never regresses
        // if the bridge action is a no-op on some OS version.
        if let open = SettingsOpener.shared.action {
            open()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    /// Creates a tiny, off-screen, always-alive SwiftUI host whose `.onAppear`
    /// captures `@Environment(\.openSettings)` into `SettingsOpener.shared`.
    private func installSettingsBridgeHost() {
        guard settingsBridgeHost == nil else { return }

        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: SettingsBridgeView())
        // Order it on screen (off-screen frame) so SwiftUI runs `.onAppear`.
        window.orderFrontRegardless()

        settingsBridgeHost = window
    }

    @objc private func quit() {
        noteStore?.flushPendingSaves()
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        noteStore?.flushPendingSaves()
        return .terminateNow
    }

    // MARK: - URL Scheme Handling

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard noteStore != nil, panelController != nil else {
            pendingDeepLinks.append(url)
            return
        }

        switch Self.deepLinkRoute(for: url) {
        case .create:
            panelController?.showExternalRequest(.createNote)

        case .note(let uuid):
            noteStore?.reconcileExternalChanges()
            guard noteStore?.containsNote(id: uuid) == true else { return }
            panelController?.showExternalRequest(.openNote(uuid))

        case .ignored:
            return
        }
    }

    private func drainPendingDeepLinks() {
        let urls = pendingDeepLinks
        pendingDeepLinks.removeAll()
        for url in urls {
            handleDeepLink(url)
        }
    }
}

// MARK: - Settings open bridge (#9)

/// Holds the captured SwiftUI `openSettings` environment action so AppKit menu
/// handlers can open the Settings scene reliably on macOS 14/15.
@MainActor
final class SettingsOpener {
    static let shared = SettingsOpener()
    var action: (() -> Void)?
    private init() {}
}

/// A zero-cost SwiftUI view that captures `@Environment(\.openSettings)` once it
/// appears and stores it in `SettingsOpener.shared`.
private struct SettingsBridgeView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                SettingsOpener.shared.action = { openSettings() }
            }
    }
}

// MARK: - Polished Settings with real hotkey recorder (KeyboardShortcuts.Recorder)

struct SettingsView: View {
    @AppStorage("notesDirectoryPath") private var storedNotesPath: String = ""

    @State private var noteStoreForSettings: NoteStore? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Ink")
                .font(.largeTitle.weight(.semibold))

            // Hotkeys section — real recorder!
            VStack(alignment: .leading, spacing: 12) {
                Text("Global Hotkeys")
                    .font(.headline)

                HStack {
                    Text("Create Note")
                        .frame(width: 140, alignment: .leading)
                    KeyboardShortcuts.Recorder(for: .createNote)
                }
                HStack {
                    Text("Browse / Toggle")
                        .frame(width: 140, alignment: .leading)
                    KeyboardShortcuts.Recorder(for: .toggleNotes)
                }
                HStack {
                    Text("Action Panel (⌥⌘K)")
                        .frame(width: 140, alignment: .leading)
                    KeyboardShortcuts.Recorder(for: .showActionPanel)
                }

                Text("Tip: Click a recorder then press your desired key combination. Conflicts with system shortcuts are shown automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Notes folder
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes Storage")
                    .font(.headline)

                Text("All notes are saved as plain .md files. You can open them in any text editor, Obsidian, or VS Code.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(noteStoreForSettings?.notesDirectory.path ?? "Default location")
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 280, alignment: .leading)

                    Button("Choose Folder…") {
                        chooseNotesFolder()
                    }

                    Button("Reveal") {
                        revealNotesFolder()
                    }
                }
            }

            Spacer()

            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            Text("Ink \(version)  •  Made for thinking at the speed of thought")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 480, height: 380)
        .onAppear {
            if noteStoreForSettings == nil {
                noteStoreForSettings = AppDelegate.shared?.noteStore ?? NoteStore()
            }
        }
    }

    private func chooseNotesFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use This Folder"

        if panel.runModal() == .OK, let url = panel.url {
            noteStoreForSettings?.changeNotesDirectory(to: url)
            storedNotesPath = url.path
        }
    }

    private func revealNotesFolder() {
        guard let url = noteStoreForSettings?.notesDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
