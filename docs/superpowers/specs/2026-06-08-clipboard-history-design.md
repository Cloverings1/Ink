# Clipboard History — Design

**Date:** 2026-06-08
**Status:** Approved (pending written-spec review)
**Author:** Ink (with user)

## Goal

Give Ink a lightweight clipboard history so the user can go back and re-copy
text they previously copied/pasted — up to **25** entries — accessed from the
menu-bar icon dropdown. Must not compromise the floating-panel contract, the
plain-`.md` storage model, or the "instant from anywhere" feel.

## Approved decisions

| Decision | Choice |
| --- | --- |
| Reuse action | Selecting an entry **copies it back to the system clipboard** (user presses ⌘V themselves). No Accessibility permission, no synthetic events. |
| Persistence | **Persist to disk** — survives relaunch. |
| Access | **Menu-bar icon dropdown** — a `Clipboard History ▸` **submenu** in the existing right/control-click context menu. No new global hotkey; floating panel untouched. |
| Capture | **Plain text only.** Images/files ignored. |
| On reuse | **Move the reused entry to the top** (most-recent-first), like standard clipboard managers. |
| Privacy (non-negotiable) | Skip concealed/transient/sensitive pasteboard items. Provide "Clear Clipboard History". |

## Architecture

### `ClipboardHistoryStore` — `@MainActor`, `ObservableObject`

Single source of truth for clipboard history. Mirrors `NoteStore`'s
dependency-injection style for testability.

**State**
- `entries: [ClipEntry]` — newest first, capped at `maxEntries` (default 25).
- `ClipEntry: Identifiable, Equatable, Codable { let id: UUID; let text: String; let copiedAt: Date }`.

**Monitoring**
- A repeating `Timer` (interval ~0.5s) polls `pasteboard.changeCount`.
  macOS provides no clipboard-change notification, so polling `changeCount`
  is the established approach. The poll is O(1) until the count changes.
- Runs for the app lifetime (LSUIElement menu-bar app is always resident), so
  it captures copies from any app, not just Ink.
- `start()` called once from `AppDelegate.applicationDidFinishLaunching`.

**Ingest rules (on `changeCount` change)**
1. **Privacy skip:** if `pasteboard.types` (or any item's types) contains
   `org.nspasteboard.ConcealedType`, `org.nspasteboard.TransientType`, or
   `com.apple.is-sensitive`, ignore entirely (do not read the value).
2. Read `pasteboard.string(forType: .string)`. Ignore `nil`,
   empty, or whitespace-only.
3. **Dedupe:** if an entry with identical `text` exists, remove it and
   re-insert at front (move-to-top). Else insert at front.
4. Trim to `maxEntries`.
5. Persist.

**Copy-back**
- `copyToClipboard(_ entry:)` writes `entry.text` to `pasteboard` (clear + set
  `.string`), then records the new `changeCount` as `lastSeenChangeCount` so the
  next poll tick does not re-ingest our own write as a new external copy.
  (Dedupe would keep it correct anyway; this avoids a redundant rewrite and any
  reorder flicker.)
- Also moves the entry to the top immediately (per "on reuse" decision) and
  persists.

**Clear**
- `clearHistory()` empties `entries`, deletes the on-disk file.

**Persistence**
- File: `Application Support/Ink/clipboard-history.json` (sibling of `Notes/`,
  resolved via the same `applicationSupportDirectory` root NoteStore uses).
- `Codable` array of `ClipEntry`. Written atomically on every mutation
  (25 small entries — cost negligible). Loaded on `init`; a corrupt/missing
  file yields an empty history (never crashes).
- Injectable `storageURL` and a pasteboard abstraction so tests run without the
  real system pasteboard or real Library directory.

### Pasteboard abstraction (for tests)

```
protocol PasteboardReading {
    var changeCount: Int { get }
    var types: [NSPasteboard.PasteboardType]? { get }
    func string() -> String?
    func write(_ string: String)   // clears + sets .string, returns new changeCount via changeCount
}
```

`NSPasteboard.general` gets a conforming adapter for production; tests use a fake
that lets them drive `changeCount`, advertised `types`, and string contents.

### Menu-bar integration (`AppDelegate`)

- `AppDelegate` owns a `clipboardHistory: ClipboardHistoryStore`, created and
  `start()`ed in `applicationDidFinishLaunching` (after the unit-test guard).
- In `showContextMenu()`, insert a **`Clipboard History ▸` submenu** (e.g. above
  the `Settings…` separator):
  - Up to 25 items, each titled with a single-line preview: newlines→spaces,
    trimmed, truncated to ~50 chars with `…`; full text as the item `toolTip`.
    Each item's action copies that entry back.
  - When empty: a single disabled `No clipboard history yet` item.
  - Separator + `Clear Clipboard History`.
  - Menu is rebuilt on each open (existing behavior), so it always reflects
    current state — no live menu observation needed.

## Data flow

```
[any app copies text]
        ↓ (≤0.5s)
Timer tick → changeCount changed?
        ↓ yes, not concealed, non-empty
ingest → dedupe/move-to-top → cap 25 → persist JSON
        ↓
right-click menu-bar icon → showContextMenu rebuilds submenu from entries
        ↓
user selects entry → copyToClipboard(entry) → text on system clipboard + moved to top + persisted
        ↓
user presses ⌘V in their app
```

## Error handling

- Corrupt/unreadable JSON on load → start empty (logged, no crash).
- Write failure → logged via `os.Logger`; in-memory history remains usable.
- Concealed-type detection is conservative: if uncertain, skip (favor privacy).

## Testing (added to `InkTests`)

Unit tests on `ClipboardHistoryStore` via the fake pasteboard + temp storage URL:
1. New text ingest appends an entry (front).
2. Duplicate text moves existing entry to top, no duplication, count unchanged.
3. Cap enforced at 25 (26th copy drops the oldest).
4. Whitespace-only / empty copies ignored.
5. Concealed/transient/sensitive types skipped (value never ingested).
6. `copyToClipboard` puts text on the pasteboard, moves entry to top, and does
   not create a duplicate on the next poll tick.
7. Persistence round-trip: entries reload from disk on a fresh store.
8. Corrupt JSON file → empty history, no throw.
9. `clearHistory` empties memory and removes the file.

## Out of scope (v1)

Images/files, pinning/favorites, search within history, auto-paste into the
active app, configurable size/interval, sync.

## Files

- **New:** `Ink/Core/Services/ClipboardHistoryStore.swift`
- **New:** `Ink/Core/Models/ClipEntry.swift` (or nested in the store)
- **New:** `Ink/Tests/ClipboardHistoryStoreTests.swift`
- **Modified:** `Ink/InkApp.swift` (own + start the store; build submenu)
