import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The full Action Panel (⌥⌘K) — the powerful command palette.
/// Renders exactly the commands and keyboard hints from the provided screenshot.
struct ActionPanelView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var controller: FloatingPanelController

    @State private var filter: String = ""
    let onDismiss: () -> Void

    private var commands: [Command] {
        let all: [Command] = [
            Command(title: "New Note", subtitle: nil, shortcut: "⌥⌘N", action: {
                if noteStore.createNewNote() != nil {
                    controller.showEditor()
                }
                onDismiss()
            }),
            Command(title: "Browse Notes", subtitle: nil, shortcut: "⌥⌘P", action: {
                controller.showBrowse()
                onDismiss()
            }),
            Command(title: "Copy Note As...", subtitle: nil, shortcut: "⇧⌘C", action: {
                copyCurrentNote()
                onDismiss()
            }),
            Command(title: "Copy Deeplink", subtitle: nil, shortcut: "⇧⌘D", action: {
                copyDeeplink()
                onDismiss()
            }),
            Command(title: "Export...", subtitle: nil, shortcut: "⇧⌘E", action: {
                exportCurrentNote()
                onDismiss()
            })
        ]

        let f = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !f.isEmpty else { return all }

        return all.filter { $0.title.lowercased().contains(f) || ($0.subtitle?.lowercased().contains(f) ?? false) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search / filter
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search for actions...", text: $filter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
            }
            .padding(12)
            .background(.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Divider().padding(.vertical, 4)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(commands) { cmd in
                        Button {
                            cmd.action()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(cmd.title)
                                        .font(.system(size: 14, weight: .medium))
                                    if let sub = cmd.subtitle {
                                        Text(sub)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(cmd.shortcut)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { _ in }   // keeps hover highlight nice

                        if cmd.id != commands.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 380)
            .padding(.horizontal, 4)
        }
        .frame(width: 380)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        .onExitCommand {
            onDismiss()
        }
    }

    // MARK: - Command implementations

    private func copyCurrentNote() {
        guard let note = noteStore.currentNote else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(note.content, forType: .string)
    }

    private func copyDeeplink() {
        guard let note = noteStore.currentNote else { return }
        let link = "ink://note/\(note.id.uuidString)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
    }

    private func exportCurrentNote() {
        guard let note = noteStore.currentNote else { return }
        noteStore.flushPendingSave(for: note.id)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = note.fileURL.lastPathComponent
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: note.fileURL, to: destination)
        } catch {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(note.content, forType: .string)
        }
    }
}

struct Command: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let shortcut: String
    let action: () -> Void
}
