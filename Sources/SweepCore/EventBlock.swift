/// With the "active event listener" on, Sweep swallows the scroll and pinch events of a gesture
/// it is handling, so the window under the cursor does not scroll or zoom at the same time.
/// Keys, mouse buttons and raw touch (gesture) events always pass, so nothing else breaks.
public enum EventBlockPolicy {
    public enum Kind: Sendable, Equatable { case scroll, magnify, smartMagnify, other }

    public static func shouldBlock(kind: Kind, activeListener: Bool, gestureActive: Bool) -> Bool {
        guard activeListener, gestureActive else { return false }
        return kind != .other
    }

    /// The event tap must be able to drop events (not listen-only) only when the setting is on.
    public static func needsActiveTap(settings: SweepSettings) -> Bool { settings.activeEventListener }
}
