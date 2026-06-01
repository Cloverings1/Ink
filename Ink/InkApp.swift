import SwiftUI
import AppKit
import KeyboardShortcuts

@main
struct InkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No WindowGroup — all UI lives inside the custom NSPanel.
        // The app has a Dock icon + menu bar extra + floating panel.
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

    private var statusItem: NSStatusItem?
    private var didReceiveExternalURL = false
    private var pendingDeepLinks: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        guard !Self.isRunningUnitTests else { return }

        // 1. Data layer
        let store = NoteStore()
        noteStore = store

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

        // 5. Show the panel on every launch (brief delay for setup)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard !self.didReceiveExternalURL else { return }
            self.panelController?.showEditor()
        }

        print("Ink launched — Dock icon + menu bar extra + global hotkeys.")
    }

    // MARK: - Dock icon clicked (app reopened)

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
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Ink", action: #selector(quit), keyEquivalent: "q")

        for item in menu.items {
            item.target = self
        }

        guard let button = statusItem?.button else { return }
        menu.popUp(positioning: nil, at: .zero, in: button)
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

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
        didReceiveExternalURL = true
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
