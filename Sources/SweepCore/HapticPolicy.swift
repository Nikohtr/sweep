/// When to give a haptic tap on the trackpad during a gesture.
///
/// Rule: tap when a step changes what the gesture will do,
/// and on hold and pause steps, which confirm that the gesture can continue (chain / repeat).
public enum HapticPolicy {
    public static func shouldTap(output: RecognizerOutput, previousAction: WindowAction?,
                                 newAction: WindowAction?, enabled: Bool) -> Bool {
        guard enabled, case .step(let step) = output else { return false }
        if step == .hold || step == .pause { return true }
        return newAction != nil && newAction != previousAction
    }
}
