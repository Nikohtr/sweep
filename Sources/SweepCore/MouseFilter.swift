/// Drops gesture input that is not backed by fingers on the trackpad (e.g. a Magic Mouse).
///
/// Rule: remember when a gesture event last showed more than one
/// trackpad touch; with the filter on, gesture input 0.2 s or more after that is ignored.
public struct MouseFilter: Sendable {
    public static let window = 0.2
    private var lastMultiTouch: Double?

    public init() {}

    public mutating func noteTouches(count: Int, time: Double) {
        if count > 1 { lastMultiTouch = time }
    }

    /// True when no trackpad multi-touch was seen in the last 0.2 s: the input comes from a mouse.
    public func isMouse(time: Double) -> Bool {
        guard let last = lastMultiTouch else { return true }
        return time - last >= Self.window
    }

    public func accepts(time: Double, disableMouse: Bool) -> Bool {
        guard disableMouse else { return true }
        guard let last = lastMultiTouch else { return false }
        return time - last < Self.window
    }
}

/// Whether a gesture may start. Trackpad gestures always may. Mouse gestures (Magic Mouse) need
/// at least one modifier role held, so ordinary mouse scrolling never moves windows, and are
/// off when "Disable Magic Mouse" is on.
public enum MouseGesturePolicy {
    public static func allows(fromMouse: Bool, roles: Set<ModifierRole>, settings: SweepSettings) -> Bool {
        guard fromMouse else { return true }
        return !settings.disableMagicMouse && !roles.isEmpty
    }
}
