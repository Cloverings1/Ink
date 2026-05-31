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
                onBulletList: { insert("- ", "") },
                onNumberedList: { insert("1. ", "") },
                onMore: { /* Future: open extra actions */ }
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
        let newSelectedRange = NSRange(location: selectedRange.location + prefix.count,
                                       length: selectedText.count)

        text = (text as NSString).replacingCharacters(in: selectedRange, with: newText)

        // Restore selection inside the newly wrapped text
        DispatchQueue.main.async {
            textView.setSelectedRange(newSelectedRange)
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
            textView.setSelectedRange(NSRange(location: lineStart + prefix.count, length: 0))
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

            Divider().frame(height: 18)

            toolbarButton("bold", action: onBold)
            toolbarButton("italic", action: onItalic)
            toolbarButton("strikethrough", action: onStrikethrough)
            toolbarButton("underline", action: onUnderline)

            Divider().frame(height: 18)

            toolbarButton("curlybraces", action: onCode)           // code
            toolbarButton("link", action: onLink)

            Divider().frame(height: 18)

            toolbarButton("list.bullet", action: onBulletList)
            toolbarButton("list.number", action: onNumberedList)

            Spacer()

            // "..." more actions
            Button(action: onMore) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .font(.system(size: 14))
    }

    private func toolbarButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 24)
        }
        .help(systemName.capitalized)
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
