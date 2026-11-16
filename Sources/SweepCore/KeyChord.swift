/// A key press with modifiers that the app posts as if the user typed it.
public struct KeyChord: Sendable, Equatable {
    /// macOS virtual key code (48 = Tab).
    public var keyCode: UInt16
    public var modifiers: ModifierKeys

    public init(keyCode: UInt16, modifiers: ModifierKeys) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ⌘⇥ goes to the next app in the switcher order; ⌘⇧⇥ goes back.
    public static func appSwitch(forward: Bool) -> KeyChord {
        KeyChord(keyCode: 48, modifiers: forward ? [.command] : [.command, .shift])
    }
}
