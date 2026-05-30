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

                    Spacer()

                    HStack(spacing: 14) {
                        Button {
                            controller.showActionPanel()
                        } label: {
                            Image(systemName: "command")
                        }
                        .help("Action Panel (⌘K)")

                        Button {
                            controller.showBrowse()
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
                        }
                        .help("Browse Notes (⌘P)")

                        Button {
                            controller.createAndShow()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("New Note (⌘N)")

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

                    case .actionPalette:
                        // Action palette is rendered as an overlay on whatever was underneath
                        ZStack {
                            // Dim the background slightly
                            Color.black.opacity(0.25)
                                .ignoresSafeArea()

                            if let note = noteStore.currentNote {
                                InkEditorView(note: note)
                                    .id(note.id)
                                    .blur(radius: 1.5)
                            } else {
                                NotesBrowserView()
                                    .blur(radius: 1.5)
                            }

                            ActionPanelView(onDismiss: {
                                controller.dismissActionPanel()
                            })
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 620, minHeight: 420)
        .preferredColorScheme(.dark)
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
            Text("Press ⌘N or tap the button below to capture your first thought.")
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