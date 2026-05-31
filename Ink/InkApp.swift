import SwiftUI
import AppKit
import KeyboardShortcuts

@main
struct InkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We intentionally provide NO WindowGroup.
        // The app is a pure hotkey + floating panel + optional menu bar experience (LSUIElement).
        // All UI lives inside the custom NSPanel managed by FloatingPanelController.
        Settings {
            // Future Settings window (polish phase)
            SettingsView()
        }
    }
}

// MARK: - App Delegate (the real "main" for a floating panel app)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?

    private(set) var noteStore: NoteStore?
    private var panelController: FloatingPanelController?

    // Optional menu bar extra so users can still interact when the panel is hidden
    private var statusItem: NSStatusItem?
    private var didReceiveExternalURL = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        guard !Self.isRunningUnitTests else { return }

        // 1. Create the data layer (plain .md files)
        let store = NoteStore()
        noteStore = store

        // 2. Create the panel controller (owns hotkeys + the NSPanel)
        panelController = FloatingPanelController(noteStore: store)

        // 3. Create a minimal, elegant menu bar icon
        setupMenuBarExtra()

        // 4. On first launch, create a welcome note so the app feels alive immediately
        var createdWelcomeNote = false
        if noteStore?.notes.isEmpty == true {
            if noteStore?.createNewNote() != nil {
                createdWelcomeNote = true
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

        // 5. Show only the first-run welcome note automatically. Existing private notes
        // stay hidden until the user presses a hotkey, uses the menu, or accepts a link.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if Self.shouldShowPanelOnLaunch(
                createdWelcomeNote: createdWelcomeNote,
                receivedExternalURL: self.didReceiveExternalURL
            ) {
                self.panelController?.showEditor()
            }
        }

        print("Ink launched — global hotkeys registered via KeyboardShortcuts.")
    }

    static func shouldShowPanelOnLaunch(createdWelcomeNote: Bool, receivedExternalURL: Bool) -> Bool {
        createdWelcomeNote && !receivedExternalURL
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func setupMenuBarExtra() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        // Simple elegant "ink drop" symbol
        button.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Ink")
        button.toolTip = "Ink — Quick Notes"

        let menu = NSMenu()
        menu.addItem(shortcutItem(title: "Create Note (⌥⌘N)", action: #selector(createNote), key: "n"))
        menu.addItem(shortcutItem(title: "Browse Notes (⌥⌘P)", action: #selector(browseNotes), key: "p"))
        menu.addItem(shortcutItem(title: "Action Panel (⌥⌘K)", action: #selector(showActions), key: "k"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings(_:)), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Ink", action: #selector(quit), keyEquivalent: "q"))

        // Wire targets
        for item in menu.items {
            item.target = self
        }

        button.menu = menu
    }

    private func shortcutItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = [.option, .command]
        return item
    }

    @objc private func createNote() {
        panelController?.createAndShow()
    }

    @objc private func browseNotes() {
        panelController?.showBrowse()
    }

    @objc private func showActions() {
        panelController?.showActionPanel()
    }

    @objc private func openSettings(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: sender)
    }

    @objc private func quit() {
        noteStore?.flushPendingSaves()
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        noteStore?.flushPendingSaves()
        return .terminateNow
    }

    // MARK: - URL Scheme Handling (ink://note/UUID and ink://create)

    func application(_ application: NSApplication, open urls: [URL]) {
        didReceiveExternalURL = true
        for url in urls {
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "ink" else { return }

        if url.host == "create" || url.path == "/create" {
            panelController?.createAndShow()
            return
        }

        if url.host == "note", let idString = url.pathComponents.last,
           let uuid = UUID(uuidString: idString) {
            noteStore?.selectNote(id: uuid)
            panelController?.showEditor()
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

            Text("Ink v0.1  •  Made for thinking at the speed of thought")
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
