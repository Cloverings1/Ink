import SwiftUI

/// The "Browse Notes" experience (⌥⌘P).
/// Matches the exact layout and typography from the provided screenshot:
/// - Search bar at top
/// - "Notes  X/Y Notes" header
/// - Rows with title, "Opened X ago • N Characters", Current pill, quick actions
struct NotesBrowserView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var controller: FloatingPanelController

    @State private var searchText: String = ""
    @State private var selectedNoteID: UUID?
    @FocusState private var isSearchFocused: Bool

    private var filteredNotes: [Note] {
        noteStore.searchNotes(query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar (exactly like screenshot)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search for notes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($isSearchFocused)
                    .onSubmit {
                        openSelectedNote()
                    }
            }
            .padding(10)
            .background(.black.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Header
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Text("\(filteredNotes.count)/\(noteStore.notes.count) Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    // Info about notes (future)
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            // The list
            ScrollView {
                LazyVStack(spacing: 2, pinnedViews: []) {
                    ForEach(filteredNotes) { note in
                        NoteRow(
                            note: note,
                            isCurrent: note.id == noteStore.currentNoteID,
                            isSelected: note.id == selectedNoteID,
                            onSelect: {
                                selectedNoteID = note.id
                                openSelectedNote()
                            },
                            onDelete: {
                                noteStore.deleteNote(id: note.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            .scrollIndicators(.hidden)

            // Bottom hint bar (matches screenshot chrome)
            HStack {
                Text("⌥⌘N  New   •   ⌥⌘K  Actions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.black.opacity(0.1))
        }
        .onAppear {
            updateSelection()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusBrowseSearch)) { _ in
            isSearchFocused = true
        }
        .onChange(of: searchText) { _, _ in
            updateSelection()
        }
        .onChange(of: noteStore.notes) { _, _ in
            updateSelection()
        }
        .onMoveCommand { direction in
            moveSelection(direction)
        }
        .onDeleteCommand {
            deleteSelectedNote()
        }
        .background(
            Button("") {
                copySelectedDeeplink()
            }
            .keyboardShortcut("d", modifiers: [.shift, .command])
            .hidden()
        )
    }

    private func updateSelection() {
        let results = filteredNotes
        guard !results.isEmpty else {
            selectedNoteID = nil
            return
        }

        if let selectedNoteID, results.contains(where: { $0.id == selectedNoteID }) {
            return
        }

        if let currentID = noteStore.currentNoteID, results.contains(where: { $0.id == currentID }) {
            selectedNoteID = currentID
        } else {
            selectedNoteID = results.first?.id
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        let results = filteredNotes
        guard !results.isEmpty else { return }

        let currentIndex = selectedNoteID.flatMap { id in
            results.firstIndex(where: { $0.id == id })
        } ?? 0

        switch direction {
        case .up:
            selectedNoteID = results[max(currentIndex - 1, 0)].id
        case .down:
            selectedNoteID = results[min(currentIndex + 1, results.count - 1)].id
        default:
            break
        }
    }

    private func openSelectedNote() {
        guard let selectedNoteID else { return }
        noteStore.selectNote(id: selectedNoteID)
        controller.showEditor()
    }

    private func deleteSelectedNote() {
        guard let selectedNoteID else { return }
        noteStore.deleteNote(id: selectedNoteID)
        updateSelection()
    }

    private func copySelectedDeeplink() {
        guard let selectedNoteID else { return }
        let link = "ink://note/\(selectedNoteID.uuidString)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
    }
}

// MARK: - Individual row (pixel-perfect to screenshot)

struct NoteRow: View {
    let note: Note
    let isCurrent: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text("\(relativeDate(note.updatedAt)) • \(note.charCount) Characters")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isCurrent {
                Text("Current")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Quick actions (copy deep link + delete) — icons only like screenshot
            HStack(spacing: 4) {
                Button {
                    // Copy deep link (we'll implement in polish)
                    let link = "ink://note/\(note.id.uuidString)"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(link, forType: .string)
                } label: {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Copy deeplink")

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Delete note")
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .background(
            isSelected ? Color.white.opacity(0.10) : (isCurrent ? Color.white.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.white.opacity(0.16) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
