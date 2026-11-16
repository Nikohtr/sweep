import Foundation

/// How long Sweep waits for another app to answer an Accessibility request (seconds).
/// macOS waits about 6 s by default, so one hung app could freeze every gesture.
public enum AXTimeouts {
    /// Global value (set on the system-wide element): hit tests under the cursor.
    public static let hitTest: Float = 0.25
    /// Set on each window or app element before Sweep moves, resizes, minimizes or closes it.
    public static let windowAction: Float = 1.0
}

/// The result of one Accessibility call, as far as a hit test cares.
public enum AXCallOutcome: Sendable, Equatable {
    case success
    /// The app did not answer in time (AXError.cannotComplete).
    case timedOut
    /// Any other error, for example a missing attribute. Normal; the hit test goes on.
    case failed
}

/// Rule for a hit test: after the first timed-out call, make no more calls (each one would wait again),
/// and treat the result as "no context": the gesture drops and the events pass through to the app.
public struct HitTestGuard: Sendable {
    public private(set) var timedOut = false

    public init() {}

    /// False after a timeout: skip every further call to that app.
    public var mayCall: Bool { !timedOut }

    /// False after a timeout: there is no gesture context.
    public var givesContext: Bool { !timedOut }

    public mutating func record(_ outcome: AXCallOutcome) {
        if outcome == .timedOut { timedOut = true }
    }

    /// `value`, or nil when a call timed out.
    public func context<T>(_ value: T?) -> T? { givesContext ? value : nil }
}
