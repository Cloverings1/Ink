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
    private var noteStore: NoteStore!
    private var panelController: FloatingPanelController!

    // Optional menu bar extra so users can still interact when the panel is hidden
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Create the data layer (plain .md files)
        noteStore = NoteStore()

        // 2. Create the panel controller (owns hotkeys + the NSPanel)
        panelController = FloatingPanelController(noteStore: noteStore)

        // 3. Create a minimal, elegant menu bar icon
        setupMenuBarExtra()

        // 4. On first launch, create a welcome note so the app feels alive immediately
        if noteStore.notes.isEmpty {
            let welcome = noteStore.createNewNote()
            var content = """
            # Welcome to Ink

            This is your first note. Everything you write here is stored as a plain **Markdown** file on your Mac.

            - Press **⌘N** from anywhere to create a new note instantly.
            - Press **⌘P** to browse and search all your notes.
            - Press **⌘K** to open the powerful Action Panel.

            Your notes live here:
            \(noteStore.notesDirectory.path)

            You own your data — open the files in any editor, Obsidian, VS Code, or git them.

            Happy thinking.
            """
            noteStore.updateCurrentNoteContent(content)
        }

        // 5. Show the panel on launch (great for first-run delight)
        // In production you might make this optional via a preference.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.panelController.showEditor()
        }

        print("Ink launched — global hotkeys registered via KeyboardShortcuts.")
    }

    private func setupMenuBarExtra() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        // Simple elegant "ink drop" symbol
        button.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Ink")
        button.toolTip = "Ink — Quick Notes"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Create Note (⌘N)", action: #selector(createNote), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Browse Notes (⌘P)", action: #selector(browseNotes), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Action Panel (⌘K)", action: #selector(showActions), keyEquivalent: "k"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Ink", action: #selector(quit), keyEquivalent: "q"))

        // Wire targets
        for item in menu.items {
            item.target = self
        }

        button.menu = menu
    }

    @objc private func createNote() {
        panelController.createAndShow()
    }

    @objc private func browseNotes() {
        panelController.showBrowse()
    }

    @objc private func showActions() {
        panelController.showActionPanel()
    }

    @objc private func openSettings() {
        // In a real app we would bring up the Settings scene.
        // For now just show the panel in a future settings tab.
        panelController.showEditor()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - URL Scheme Handling (ink://note/UUID and ink://create)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "ink" else { return }

        if url.host == "create" || url.path == "/create" {
            panelController.createAndShow()
            return
        }

        if url.host == "note", let idString = url.pathComponents.last,
           let uuid = UUID(uuidString: idString) {
            noteStore.selectNote(id: uuid)
            panelController.showEditor()
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
                    Text("Action Panel (⌘K)")
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
                noteStoreForSettings = NoteStore()
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
}