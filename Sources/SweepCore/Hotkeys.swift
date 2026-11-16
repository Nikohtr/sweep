import Foundation

/// Key codes for the keyboard hotkeys. Key codes are physical key positions.
/// The Dvorak set: the physical keys that type W, A, S, D on a Dvorak layout.
public enum HotkeyMap {
    public static func direction(keyCode: UInt16, keys: SweepSettings.ArrowKeys) -> Direction? {
        codes(keys).first { $0.value == keyCode }?.key
    }

    public static func keyCode(for center: SweepSettings.CenterKey) -> UInt16 {
        switch center {
        case .escape: return 53
        case .backspace: return 51
        case .returnKey: return 36
        }
    }

    /// Every key code to register as a hotkey (with the super modifier) for these settings.
    public static func registeredKeyCodes(settings: SweepSettings) -> [UInt16] {
        Array(codes(settings.arrowKeys).values) + [keyCode(for: settings.centerKey)]
    }

    private static func codes(_ keys: SweepSettings.ArrowKeys) -> [Direction: UInt16] {
        switch keys {
        case .arrows: return [.left: 123, .right: 124, .down: 125, .up: 126]
        case .wasd: return [.up: 13, .left: 0, .down: 1, .right: 2]
        case .dvorak: return [.up: 43, .left: 0, .down: 41, .right: 4]
        }
    }
}

/// Builds a snap from key presses the way swipes build one: presses that come within the
/// timeout of the previous one join the same sequence, so ← then ↑ gives the top-left quarter.
public struct HotkeySequence {
    public let timeout: Double
    private var steps: [Primitive] = []
    private var last: Double?

    public init(timeout: Double) { self.timeout = timeout }

    /// Uses the gesture cancel timeout.
    public init(settings: SweepSettings) { self.init(timeout: Double(settings.cancelTimeoutMs) / 1000) }

    public mutating func press(_ direction: Direction, at time: Double) -> WindowAction? {
        if let last, time - last > timeout { steps = [] }
        last = time
        steps.append(.swipe(direction))
        return TitlebarActions.action(for: steps)
    }

    public mutating func pressCenter() -> WindowAction {
        steps = []
        last = nil
        return .center
    }
}
