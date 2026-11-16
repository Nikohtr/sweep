/// Which scroll events may feed the gesture recognizer.
public enum ScrollFilter {
    /// Only events from fingers on the trackpad count. Mouse-wheel ticks have no phase, and momentum
    /// (inertia after the fingers lift) is not a gesture — so normal scrolling is never taken over.
    public static func isFingerScroll(phase: TouchPhase?, momentum: Bool) -> Bool {
        phase != nil && !momentum
    }
}
