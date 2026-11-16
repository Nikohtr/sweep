/// Let macOS (15 and later) tile the window with its own shortcuts, so the system knows
/// the window is tiled. The system defaults: ⌃fn + arrow keys for halves and
/// ⌃fn + F for fill. Other targets have no system shortcut and keep our own frames.
public enum NativeTiling {
    public static func chord(for target: SnapTarget) -> KeyChord? {
        let code: UInt16
        switch target {
        case .leftHalf: code = 123
        case .rightHalf: code = 124
        case .bottomHalf: code = 125
        case .topHalf: code = 126
        case .maximize: code = 3   // F
        default: return nil
        }
        return KeyChord(keyCode: code, modifiers: [.control, .function])
    }

    /// A custom grid gap needs our own frames, so the system tiles are only used with no gap.
    public static func useNative(target: SnapTarget, settings: SweepSettings) -> Bool {
        settings.nativeTiling && settings.gridSpacing == 0 && chord(for: target) != nil
    }
}
