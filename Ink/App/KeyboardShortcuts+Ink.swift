import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // The three primary global hotkey commands
    static let createNote = Self("createNote", default: .init(.n, modifiers: [.command]))
    static let toggleNotes = Self("toggleNotes", default: .init(.p, modifiers: [.command]))
    static let showActionPanel = Self("showActionPanel", default: .init(.k, modifiers: [.command]))
}