import SwiftUI

/// The SwiftUI content that gets hosted inside the NSPanel.
/// It renders the correct child view based on the current mode (editor / browse / action palette).
struct FloatingPanelRootView: View {
    @EnvironmentObject var controller: FloatingPanelController
    @EnvironmentObject var noteStore: NoteStore

    var body: some View {
        ZStack {
            // Beautiful dark frosted background matching the screenshots
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with Ink branding + action buttons
                HStack {
                    Text("Ink")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    SaveStatusView(state: noteStore.saveState)

                    Spacer()

                    HStack(spacing: 14) {
                        Button {
                            controller.showActionPanel()
                        } label: {
                            Image(systemName: "command")
                        }
                        .help("Action Panel (⌥⌘K)")

                        Button {
                            controller.showBrowse()
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
                        }
                        .help("Browse Notes (⌥⌘P)")

                        Button {
                            controller.createAndShow()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("New Note (⌥⌘N)")

                        Button {
                            controller.hide()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .keyboardShortcut(.escape, modifiers: [])
                        .help("Close")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.15))

                // Main content area
                Group {
                    switch controller.mode {
                    case .editor:
                        if let note = noteStore.currentNote {
                            InkEditorView(note: note)
                                .id(note.id)   // force refresh when switching notes
                        } else {
                            // No note yet — offer to create one
                            EmptyEditorPlaceholder {
                                controller.createAndShow()
                            }
                        }

                    case .browse:
                        NotesBrowserView()

                    case .externalRequest:
                        if let request = controller.externalLinkRequest {
                            ExternalLinkConfirmationView(
                                request: request,
                                onCancel: {
                                    controller.cancelExternalRequest()
                                },
                                onConfirm: {
                                    controller.acceptExternalRequest()
                                }
                            )
                        } else {
                            EmptyEditorPlaceholder {
                                controller.createAndShow()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if controller.isActionPanelPresented {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                ActionPanelView(onDismiss: {
                    controller.dismissActionPanel()
                })
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .frame(minWidth: 620, minHeight: 420)
        .preferredColorScheme(.dark)
    }
}

struct ExternalLinkConfirmationView: View {
    let request: ExternalLinkRequest
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: request.systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(request.title)
                    .font(.title3.weight(.semibold))

                Text(request.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape, modifiers: [])

                Button(request.confirmTitle, action: onConfirm)
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SaveStatusView: View {
    let state: NoteStore.SaveState

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .saving:
            Label("Saving", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
                .font(.caption2)
        case .saved:
            Label("Saved", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
                .font(.caption2)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(message)
        }
    }
}

// MARK: - Frosted background helper (matches the screenshots' aesthetic)

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Placeholder when there are zero notes

struct EmptyEditorPlaceholder: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("No note yet")
                .font(.title3.weight(.medium))
            Text("Press ⌥⌘N or tap the button below to capture your first thought.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Create your first note", action: onCreate)
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
