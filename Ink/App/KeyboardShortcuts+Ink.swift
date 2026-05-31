import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // The three primary global hotkey commands
    static let createNote = Self("createNote", default: .init(.n, modifiers: [.option, .command]))
    static let toggleNotes = Self("toggleNotes", default: .init(.p, modifiers: [.option, .command]))
    static let showActionPanel = Self("showActionPanel", default: .init(.k, modifiers: [.option, .command]))
}
