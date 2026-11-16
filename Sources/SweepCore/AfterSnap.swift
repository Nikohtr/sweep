import CoreGraphics

/// What to do after a snap, when the fingers lift (Snapping tab: activate window, move cursor).
public enum AfterSnap {
    public enum Step: Sendable, Equatable { case activate, moveCursor }

    public static func steps(settings: SweepSettings) -> [Step] {
        var out: [Step] = []
        if settings.activateAfterSnap { out.append(.activate) }
        if settings.moveCursorAfterSnap { out.append(.moveCursor) }
        return out
    }

    /// The middle of the window's titlebar band (12 pt below the top), on whole points.
    public static func cursorTarget(frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX.rounded(.down), y: (frame.minY + 12).rounded(.down))
    }

    /// Runs once per gesture: on lift, and only if the gesture ended with a snap.
    public static func applies(output: RecognizerOutput, lastAction: WindowAction?) -> Bool {
        guard case .ended = output, case .snap = lastAction else { return false }
        return true
    }
}
