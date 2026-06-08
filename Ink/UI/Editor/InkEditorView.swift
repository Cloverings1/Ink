import SwiftUI

/// The main writing surface for Ink.
/// Plain Markdown (as chosen by the user) with a beautiful bottom formatting toolbar
/// that inserts the correct Markdown syntax (exactly as shown in the provided screenshots).
struct InkEditorView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var controller: FloatingPanelController

    let note: Note

    @State private var text: String = ""
    @FocusState private var isEditorFocused: Bool

    // For the H~ dropdown
    @State private var showingHeadingMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // The actual editor — plain Markdown with native feel
            TextEditor(text: $text)
                .font(.system(size: 15, design: .default))
                .lineSpacing(4)
                .padding(16)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($isEditorFocused)
                .onChange(of: text) { _, newValue in
                    noteStore.updateCurrentNoteContent(newValue)
                }
                .onChange(of: note.content) { _, newValue in
                    if newValue != text {
                        text = newValue
                    }
                }
                .onAppear {
                    text = note.content
                    // Auto-focus when the view appears (triggered by the controller)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isEditorFocused = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .focusEditor)) { _ in
                    isEditorFocused = true
                }

            // Bottom formatting toolbar — matches the screenshots 1:1
            EditorToolbar(
                onBold: { insert("**", "**") },
                onItalic: { insert("*", "*") },
                onStrikethrough: { insert("~~", "~~") },
                onUnderline: { insert("<u>", "</u>") },   // Markdown-ish; many people use HTML underline
                onCode: { insert("`", "`") },
                onLink: { insert("[", "](url)") },
                onHeading: { level in insertHeading(level) },
                onBulletList: { insertLinePrefix(bulleted: true) },
                onNumberedList: { insertLinePrefix(bulleted: false) },
                onMore: { controller.showActionPanel() }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.2))
        }
    }

    // MARK: - Syntax insertion helpers (the heart of the toolbar)

    private func insert(_ prefix: String, _ suffix: String) {
        guard let textView = findTextView() else {
            // Fallback: just append at end
            text += prefix + suffix
            return
        }

        let selectedRange = textView.selectedRange
        let selectedText = (text as NSString).substring(with: selectedRange)

        let newText = prefix + selectedText + suffix
        let newSelectedRange = NSRange(location: selectedRange.location + (prefix as NSString).length,
                                       length: (selectedText as NSString).length)

        text = (text as NSString).replacingCharacters(in: selectedRange, with: newText)

        // Restore selection inside the newly wrapped text
        DispatchQueue.main.async {
            // Clamp to the textview's current length — the string may not have synced yet
            // (e.g. a brand-new empty note), which would make the range out of bounds.
            let maxLen = (textView.string as NSString).length
            let location = max(0, min(newSelectedRange.location, maxLen))
            let length = max(0, min(newSelectedRange.length, maxLen - location))
            textView.setSelectedRange(NSRange(location: location, length: length))
        }
    }

    private func insertHeading(_ level: Int) {
        let prefix = String(repeating: "#", count: level) + " "
        // Insert at start of current line
        guard let textView = findTextView() else {
            text = prefix + text
            return
        }

        let selectedRange = textView.selectedRange
        let nsText = text as NSString
        var lineStart = selectedRange.location
        nsText.getLineStart(&lineStart, end: nil, contentsEnd: nil, for: selectedRange)

        let insertionPoint = NSRange(location: lineStart, length: 0)
        text = nsText.replacingCharacters(in: insertionPoint, with: prefix)

        DispatchQueue.main.async {
            // Clamp to the textview's current length in case the string hasn't synced yet.
            let maxLen = (textView.string as NSString).length
            let location = max(0, min(lineStart + (prefix as NSString).length, maxLen))
            textView.setSelectedRange(NSRange(location: location, length: 0))
        }
    }

    /// Anchors a list marker at the START of every line covered by the selection
    /// (or the caret's line when the selection is empty), so it always produces
    /// valid Markdown instead of wrapping at the caret.
    /// - `bulleted: true`  → prepends `- ` to each line.
    /// - `bulleted: false` → prepends an incrementing `1. `, `2. `, … to each line.
    private func insertLinePrefix(bulleted: Bool) {
        guard let textView = findTextView() else {
            // Fallback: just prepend a single marker at the very start.
            text = (bulleted ? "- " : "1. ") + text
            return
        }

        let selectedRange = textView.selectedRange
        let nsText = text as NSString
        let selEnd = selectedRange.location + selectedRange.length

        // Collect the start location of every line touched by the selection.
        var lineStarts: [Int] = []
        var index = selectedRange.location
        while true {
            var lineStart = 0
            var lineEnd = 0
            nsText.getLineStart(&lineStart, end: &lineEnd, contentsEnd: nil,
                                for: NSRange(location: index, length: 0))
            lineStarts.append(lineStart)
            // Advance to the next line. Stop once we pass the selection's end,
            // make no forward progress, or reach the end of the string.
            if lineEnd <= index || lineEnd > selEnd || lineEnd >= nsText.length {
                break
            }
            index = lineEnd
        }

        // Build the per-line prefixes (numbered markers vary in width: "10. ").
        let prefixes: [String] = lineStarts.indices.map { i in
            bulleted ? "- " : "\(i + 1). "
        }

        // Insert from the LAST line to the FIRST so earlier offsets stay valid.
        let mutable = NSMutableString(string: text)
        for i in stride(from: lineStarts.count - 1, through: 0, by: -1) {
            mutable.insert(prefixes[i], at: lineStarts[i])
        }
        text = mutable as String

        // Total UTF-16 units inserted, for restoring the selection.
        let totalInserted = prefixes.reduce(0) { $0 + ($1 as NSString).length }
        let firstLineStart = lineStarts.first ?? selectedRange.location
        let firstPrefixLen = (prefixes.first.map { ($0 as NSString).length }) ?? 0

        let restored: NSRange
        if selectedRange.length == 0 {
            // Empty selection → drop the caret after the first marker so the user can type.
            restored = NSRange(location: firstLineStart + firstPrefixLen, length: 0)
        } else {
            // Non-empty → keep the whole prefixed block selected.
            restored = NSRange(location: firstLineStart, length: selEnd + totalInserted - firstLineStart)
        }

        DispatchQueue.main.async {
            // Clamp to the textview's current length in case the string hasn't synced yet.
            let maxLen = (textView.string as NSString).length
            let location = max(0, min(restored.location, maxLen))
            let length = max(0, min(restored.length, maxLen - location))
            textView.setSelectedRange(NSRange(location: location, length: length))
        }
    }

    /// Finds the underlying NSTextView inside the SwiftUI TextEditor.
    /// This is the reliable way to manipulate selection and perform advanced edits.
    private func findTextView() -> NSTextView? {
        // Walk the view hierarchy (works reliably in macOS 14+)
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return nil }
        return window.firstDescendant(of: NSTextView.self)
    }
}

// MARK: - The exact bottom toolbar from the screenshots

struct EditorToolbar: View {
    let onBold: () -> Void
    let onItalic: () -> Void
    let onStrikethrough: () -> Void
    let onUnderline: () -> Void
    let onCode: () -> Void
    let onLink: () -> Void
    let onHeading: (Int) -> Void
    let onBulletList: () -> Void
    let onNumberedList: () -> Void
    let onMore: () -> Void

    @State private var showingHeadingPicker = false

    var body: some View {
        HStack(spacing: 4) {
            // Heading dropdown (H~)
            Menu {
                Button("Heading 1 (#)") { onHeading(1) }
                Button("Heading 2 (##)") { onHeading(2) }
                Button("Heading 3 (###)") { onHeading(3) }
                Button("Heading 4 (####)") { onHeading(4) }
            } label: {
                HStack(spacing: 2) {
                    Text("H~")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 42)
            .accessibilityLabel("Heading")

            Divider().frame(height: 18)

            toolbarButton("bold", "Bold", action: onBold)
            toolbarButton("italic", "Italic", action: onItalic)
            toolbarButton("strikethrough", "Strikethrough", action: onStrikethrough)
            toolbarButton("underline", "Underline", action: onUnderline)

            Divider().frame(height: 18)

            toolbarButton("curlybraces", "Code", action: onCode)           // code
            toolbarButton("link", "Link", action: onLink)

            Divider().frame(height: 18)

            toolbarButton("list.bullet", "Bullet List", action: onBulletList)
            toolbarButton("list.number", "Numbered List", action: onNumberedList)

            Spacer()

            // "..." more actions
            Button(action: onMore) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .help("More actions (⌥⌘K)")
            .accessibilityLabel("More actions")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .font(.system(size: 14))
    }

    private func toolbarButton(_ systemName: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 24)
        }
        .help(label)
        .accessibilityLabel(label)
    }
}

// Small helper to find NSTextView descendants (very useful for all text manipulation)
extension NSWindow {
    func firstDescendant<T: NSView>(of type: T.Type) -> T? {
        var queue: [NSView] = [self.contentView].compactMap { $0 }
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if let match = current as? T { return match }
            queue.append(contentsOf: current.subviews)
        }
        return nil
    }
}
