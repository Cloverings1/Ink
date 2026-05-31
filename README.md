<div align="center">

<img src=".github/assets/banner.svg" width="100%" alt="Ink — Floating notes for macOS"/>

<br/><br/>

<img src=".github/assets/icon.png" width="112" alt="Ink app icon"/>

# Ink

**Instant floating notes. Plain Markdown. You own every file.**

<br/>

[![macOS](https://img.shields.io/badge/macOS-14.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-+-007AFF?style=for-the-badge&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-8e8e93?style=for-the-badge)](LICENSE)

<br/>

[Features](#-features) · [Demo](#-demo) · [Shortcuts](#-shortcuts) · [Get Started](#-get-started) · [Structure](#-structure)

</div>

<img src=".github/assets/divider.svg" width="100%" alt=""/>

<br/>

## ✦ Demo

<p align="center">
  <img src=".github/assets/panel-demo.svg" width="92%" alt="Animated Ink floating panel mockup"/>
</p>

<p align="center">
  <sub>Summon a frosted panel over any app, any Space, even fullscreen — start typing in milliseconds.</sub>
</p>

<img src=".github/assets/divider.svg" width="100%" alt=""/>

<br/>

## ✦ Features

<table>
<tr>
<td width="50%" valign="top">

### ⚡ Zero friction

Global hotkey → floating panel appears instantly. No context switch. No Dock icon required. Dismiss with **Esc** or click outside.

### 🪟 Native floating panel

Built on `NSPanel` with `.nonactivatingPanel` — stays above your work without stealing app activation.

### ⌨️ Customizable shortcuts

All primary commands register through **[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)** so users can remap keys.

</td>
<td width="50%" valign="top">

### 📝 Plain Markdown

Raw Markdown editing with a bottom toolbar that **inserts syntax** — not a WYSIWYG layer. What you see is what’s on disk.

### 📁 Files you own

Notes live as individual `.md` files (default: `~/Library/Application Support/Ink/Notes`). Open them in Obsidian, VS Code, BBEdit, or git.

### 🔍 Instant search

In-memory title + content index for fast browse/search — no database lock-in in v1.

</td>
</tr>
</table>

<img src=".github/assets/divider.svg" width="100%" alt=""/>

<br/>

## ✦ Shortcuts

<p align="center">

| Action | Default | What it does |
|:--|:--:|:--|
| **Create note** | `⌥⌘N` | Opens the editor with a fresh note |
| **Browse / toggle** | `⌥⌘P` | Search and switch notes |
| **Action panel** | `⌥⌘K` | Command palette for all actions |
| **Dismiss** | `Esc` | Hide the panel (Spotlight-style) |

</p>

<img src=".github/assets/divider.svg" width="100%" alt=""/>

<br/>

## ✦ Get Started

### Quick build (~5 min)

```bash
git clone https://github.com/Cloverings1/Ink.git
cd Ink
```

1. Open **Xcode** → **Create a new Project** → **macOS** → **App**
2. Name: **Ink** · Interface: **SwiftUI** · Language: **Swift**
3. Save inside the repo’s `Ink/` folder
4. Delete Xcode’s default `InkApp.swift`, `ContentView.swift`, and placeholder assets
5. Drag the repo’s `Ink/` source folder into the project navigator (**Create groups**, add to target)
6. Add package dependency: `https://github.com/sindresorhus/KeyboardShortcuts`
7. Configure the target:
   - **Deployment Target:** macOS 14.0+
   - **Info → `LSUIElement`:** `YES`
   - **URL Types → Schemes:** `ink`
8. Press **⌘R**

You should get a menu bar extra, no main window, and **⌥⌘N** summoning the panel.

<details>
<summary><strong>Full Xcode setup checklist</strong></summary>

<br/>

**Project creation**
- Xcode 16+ recommended
- Product Name: **Ink**
- Organization Identifier: e.g. `com.yourname`
- Uncheck Core Data. The repo includes an `InkTests` target for persistence coverage.

**Replace generated files**
- Copy all Swift sources from this repo’s `Ink/` folder into your project

**KeyboardShortcuts (required)**
- File → Add Package Dependencies…
- URL: `https://github.com/sindresorhus/KeyboardShortcuts`
- Version: Up to Next Major (2.x)
- Add to the Ink target

**Target configuration**
- General → Deployment Target: macOS 14.0 (Sonoma)+
- Info → `LSUIElement` = `YES` (agent-style app, no Dock icon by default)
- Info → URL Types → Item 0 → URL Schemes → `ink`
- Ensure `Ink/Resources/Assets.xcassets` is in **Build Phases → Copy Bundle Resources**
- App Icon should point to `AppIcon` in asset catalog

**Assets**
- App icon is pre-built in `Ink/Resources/Assets.xcassets/AppIcon.appiconset/`
- Master `.icns` at `Ink/Resources/Icons/Ink.icns`

**Build & run**
- ⌘R — app launches with no main window (expected)
- Press ⌥⌘N to verify the floating panel
- Run `xcodebuild test -project Ink.xcodeproj -scheme Ink -destination 'platform=macOS'` to verify persistence behavior

</details>

<img src=".github/assets/divider.svg" width="100%" alt=""/>

<br/>

## ✦ Structure

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
│   │   ├── FloatingPanelController.swift
│   │   └── FloatingPanelRootView.swift
│   └── CommandPalette/ActionPanelView.swift
├── Tests/
│   └── NoteStoreTests.swift
├── Resources/
│   ├── Assets.xcassets/
│   └── Icons/Ink.icns
├── Info.plist
└── Ink.entitlements
```

<img src=".github/assets/divider.svg" width="100%" alt=""/>

<br/>

## ✦ Design principles

| Principle | Implementation |
|:--|:--|
| **Instant** | Global hotkey + non-activating `NSPanel` |
| **Native** | SwiftUI + AppKit, frosted HUD window material |
| **Portable** | Plain `.md` files on disk, debounced per-note auto-save with flush-on-transition |
| **Lightweight** | One dependency (`KeyboardShortcuts`) for hotkeys |
| **Searchable** | In-memory index, no SQLite in v1 |

<img src=".github/assets/divider.svg" width="100%" alt=""/>

<br/>

<div align="center">

### Built for frictionless thinking on macOS.

<br/>

**MIT License** — you own your notes and your code.

<br/>

<sub>If Ink saves you a thought, star the repo ⭐</sub>

</div>
