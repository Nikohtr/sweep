/// When pinch or swipe events stop arriving, a short display sleep resets the system's gesture
/// state. The displays sleep only briefly.
public enum InputFix {
    public enum Step: Sendable, Equatable {
        case sleepDisplays
        case wakeDisplays
        case restartInput
        case wait(Double)
    }

    public static let steps: [Step] = [.sleepDisplays, .wait(2), .wakeDisplays, .wait(1), .restartInput]

    public static let confirmText = "Your displays turn off for about two seconds and then on again, "
        + "and Sweep restarts its gesture input. No setting is changed."
}
