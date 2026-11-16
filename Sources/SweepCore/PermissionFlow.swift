/// Decides what the app does as Accessibility trust changes.
///
/// Sweep needs Accessibility trust for its event tap and for moving windows. The app checks
/// trust, passes the result here, and runs the returned actions. Rules:
/// - First check, not trusted: show the system prompt once, then poll. When the Welcome window
///   asks instead (`promptAtLaunch: false`), only poll.
/// - Trust appears: start input. Trust goes away: stop input, poll, never prompt again.
/// - The user can ask at any time while trust is missing: the first ask shows the system prompt
///   (it also adds Sweep to the Accessibility list), later asks open the settings page.
public struct PermissionFlow: Sendable, Equatable {
    public enum Status: Sendable, Equatable { case unknown, granted, denied }

    public enum Action: Sendable, Equatable {
        case promptSystem
        case openSettings
        case startInput
        case stopInput
        case recheck(after: Double)
    }

    /// Seconds between checks while trust is missing (fast, so input starts soon after a grant).
    public static let deniedRecheck = 1.0
    /// Seconds between checks while trusted (slow; catches a revoke after a new ad-hoc build).
    public static let grantedRecheck = 5.0

    public private(set) var status: Status = .unknown
    public private(set) var hasPrompted = false
    public let promptAtLaunch: Bool

    public init(promptAtLaunch: Bool = true) { self.promptAtLaunch = promptAtLaunch }

    public mutating func update(trusted: Bool) -> [Action] {
        let previous = status
        status = trusted ? .granted : .denied
        switch (previous, status) {
        case (.granted, .granted):
            return [.recheck(after: Self.grantedRecheck)]
        case (_, .granted):
            return [.startInput, .recheck(after: Self.grantedRecheck)]
        case (.granted, .denied):
            hasPrompted = true
            return [.stopInput, .recheck(after: Self.deniedRecheck)]
        case (.unknown, .denied) where !hasPrompted && promptAtLaunch:
            hasPrompted = true
            return [.promptSystem, .recheck(after: Self.deniedRecheck)]
        default:
            return [.recheck(after: Self.deniedRecheck)]
        }
    }

    public mutating func userRequested() -> [Action] {
        if status == .granted { return [] }
        if !hasPrompted {
            hasPrompted = true
            return [.promptSystem]
        }
        return [.openSettings]
    }
}
