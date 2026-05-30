# Ink — Floating Notes for macOS

Beautiful, zero-friction note-taking app with a global hotkey that summons a gorgeous floating panel anywhere on your Mac. Notes are plain Markdown files you own.

## Status
This is the complete scaffolded source for the **Ink** macOS app following the approved implementation plan.

All core to-dos are being implemented here.

## App Icon (May 2026)
We are using a gorgeous **liquid glass / frosted** icon (originally styled after Pocket Casts' beautiful aesthetic).

- Master file: `Ink/Resources/Icons/Ink.icns` (1.2 MB, contains all required sizes)
- Xcode asset catalog: fully populated in `Ink/Resources/Assets.xcassets/AppIcon.appiconset/`

This icon will appear in the menu bar, Dock (if you later allow it), Finder, and the app switcher. It looks fantastic on both light and dark wallpapers.

## Build for Testing Right Now

You already have everything ready (including the beautiful icon). Here's the fastest path to a working test build:

1. Open Xcode → **Create a new Project** → **macOS** → **App**
2. Name: `Ink`, Interface: SwiftUI, Language: Swift. Uncheck Core Data and tests.
3. Save it inside the `Ink/` folder (next to the existing `Ink/` source group).
4. Delete the default `InkApp.swift`, `ContentView.swift`, and the placeholder `Assets.xcassets` that Xcode generated.
5. Drag the `Ink/` folder (the one containing `InkApp.swift`, `Core/`, `UI/`, `Resources/`, etc.) from this repo into your Xcode project navigator. Choose "Create groups" and add to the Ink target.
6. Add the KeyboardShortcuts package (see step 10 below).
7. In the target settings:
   - **General** → Deployment Target: macOS 14.0+
   - **Info** tab:
     - Add `LSUIElement` (Boolean) = `YES`
     - Add a URL Type with scheme `ink`
   - **Build Settings** → "Asset Catalog Compiler - Options" → **App Icon** should already point to `AppIcon`
8. Select the `Ink` target → **Build Phases** → make sure `Assets.xcassets` is included.
9. Press **⌘R**.

You should see:
- No main window on launch (correct for an agent-style app)
- The gorgeous liquid glass icon in the menu bar
- Press ⌘N and the floating panel appears with the icon visible in the app switcher / menu bar

## How to Set Up the Xcode Project (Required)

Because a full `.xcodeproj` is a binary package, follow these 5 minutes steps to get a buildable native macOS app:

1. Open **Xcode** (16+ recommended) → **Create a new Xcode project**.
2. Choose **macOS** → **App** → **SwiftUI** interface, **Swift** language.
3. Product Name: **Ink**
4. Organization Identifier: e.g. `com.yourname`
5. Interface: **SwiftUI**
6. Language: **Swift**
7. **Uncheck** "Use Core Data", "Include Tests" for now (you can add later).
8. Save the project into this repo's `Ink/` folder (or anywhere; the files below are the content of the `Ink/` group).

9. **Replace the generated files** with the ones in this repo's `Ink/` folder (copy the Swift files into the project navigator, replacing `InkApp.swift` etc.).

10. **Add the KeyboardShortcuts dependency** (critical for global hotkeys):
    - In Xcode: File → Add Package Dependencies…
    - Paste: `https://github.com/sindresorhus/KeyboardShortcuts`
    - Version: Up to Next Major (or latest 2.x)
    - Add to the Ink target.

11. **Configure the target** for a floating panel app (agent-like):
    - Select the Ink target → General → Deployment Target: macOS 14.0 (Sonoma) or later.
    - Info tab:
      - Add `LSUIElement` (Boolean) = `YES`  (no Dock icon by default — pure hotkey + menu bar experience)
      - Add URL scheme: `URL Types` → Item 0 → URL Schemes → `ink`
    - Build Settings → Other Linker Flags (if needed, usually not).

12. **Capabilities** (for future):
    - Later: App Sandbox + User Selected Files (read/write) if you want strict sandboxing. For v1 we start without heavy sandbox to allow easy folder access.

13. **Assets**:
    - The beautiful liquid glass app icon is **already prepared** for you.
    - Just make sure the folder `Ink/Resources/Assets.xcassets/AppIcon.appiconset/` (with all the PNGs and the updated `Contents.json`) gets copied into your Xcode project.
    - The master `Ink.icns` is also ready at `Resources/Icons/Ink.icns` if you ever want to reference it directly.

14. Build & Run (⌘R). The app should launch with no main window (because of LSUIElement).

## Running Ink
- Press the registered global hotkey (default: **⌘N** for Create Note — customizable later).
- The floating panel appears instantly over any app, any Space, fullscreen.
- Type Markdown. Use the bottom toolbar.
- ⌘P to browse/search notes.
- ⌘K for the full Action Panel (command palette).
- Esc or click outside to dismiss (just like Spotlight).

## Project Structure (after copying files)

```
Ink/
├── InkApp.swift
├── App/
│   └── KeyboardShortcuts+Ink.swift
├── Core/
│   ├── Models/Note.swift
│   └── Services/NoteStore.swift
├── UI/
│   ├── Editor/InkEditorView.swift
│   ├── Browse/NotesBrowserView.swift
│   ├── FloatingPanel/
│   │   ├── FloatingNotePanel.swift
│   │   └── FloatingPanelController.swift
│   └── CommandPalette/ActionPanelView.swift
├── Resources/
│   ├── Assets.xcassets/
│   └── Icons/Ink.icns
├── Info.plist
├── Ink.entitlements
├── project.yml
├── README.md
├── AGENTS.md
├── CLAUDE.md
└── Ink.xcodeproj/          ← generated by xcodegen
```

## Key Design Decisions Implemented
- **Pure native Swift + SwiftUI + AppKit (NSPanel)**: Delivers an instant, non-activating floating panel over any app.
- **Plain .md files**: Stored in `~/Library/Application Support/Ink/Notes` (user can change in Settings). Fully portable, git-friendly, searchable by any tool.
- **Plain text Markdown editing** with toolbar that inserts syntax (matches your screenshots exactly).
- **No heavy dependencies** except KeyboardShortcuts for user-customizable global hotkeys.
- **In-memory search index** for instant title + content search (no DB in v1).

## Next Steps After Setup
The scaffold includes:
- Working floating panel + hotkey (toggle + create).
- Editor with formatting toolbar.
- File-backed NoteStore with auto-save.
- Browse list + search.
- Action palette (⌘K).
- Basic settings and deeplink support.

Run through the phases in the plan by building incrementally.

## Distribution (future)
- Direct .app downloads (notarize).
- Homebrew cask.
- (Optional) Mac App Store with proper sandboxing + entitlements.

## Screenshots Reference
The UI is built to exactly match the aesthetic and layout in the six screenshots you provided (dark theme, frosted panel, bottom toolbar, browse list with metadata, action panel with keyboard shortcuts shown).

## Questions / Feedback
Open an issue or just edit the code. This is your app — make it perfect.

Built with love for frictionless thinking on macOS.

## License
MIT — you own your notes and your code.
