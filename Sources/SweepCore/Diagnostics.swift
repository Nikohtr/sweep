/// System settings the gestures depend on, as read by the app (nil = could not read).
public struct DiagnosticInput: Sendable, Equatable {
    /// Trackpad "Zoom in or out" (pinch) – needed for pinch gestures.
    public var pinchToZoom: Bool?
    /// Trackpad "Smart zoom" (two-finger double tap) – needed for double tap gestures.
    public var smartZoom: Bool?
    /// Trackpad haptic (Force Touch) feedback – needed for Sweep's haptic ticks.
    public var haptics: Bool?
    /// Mission Control "Move left/right a space" shortcuts – needed to move windows between Spaces.
    public var spaceShortcuts: Bool?

    public init(pinchToZoom: Bool?, smartZoom: Bool?, haptics: Bool?, spaceShortcuts: Bool?) {
        self.pinchToZoom = pinchToZoom
        self.smartZoom = smartZoom
        self.haptics = haptics
        self.spaceShortcuts = spaceShortcuts
    }
}

public struct DiagnosticItem: Sendable, Equatable {
    public enum Status: Sendable, Equatable { case ok, problem, unknown }
    public let name: String
    public let status: Status
    /// What to change in System Settings when the status is a problem.
    public let hint: String
}

/// Turns the system settings into a short report. Read-only; Sweep never changes them.
public enum Diagnostics {
    public static func report(_ input: DiagnosticInput) -> [DiagnosticItem] {
        func item(_ name: String, _ value: Bool?, _ hint: String) -> DiagnosticItem {
            DiagnosticItem(name: name, status: value.map { $0 ? .ok : .problem } ?? .unknown, hint: hint)
        }
        return [
            item("Pinch to zoom", input.pinchToZoom,
                 "Turn on System Settings › Trackpad › Scroll & Zoom › Zoom in or out."),
            item("Smart zoom", input.smartZoom,
                 "Turn on System Settings › Trackpad › Scroll & Zoom › Smart zoom."),
            item("Haptic feedback", input.haptics,
                 "Turn on Force Click and haptic feedback in System Settings › Trackpad."),
            item("Mission Control shortcuts", input.spaceShortcuts,
                 "Turn on Move left/right a space in System Settings › Keyboard › Keyboard Shortcuts › Mission Control."),
        ]
    }

    public static func summary(_ items: [DiagnosticItem]) -> String {
        let n = items.filter { $0.status == .problem }.count
        return n == 0 ? "All checks passed." : "\(n) problem\(n == 1 ? "" : "s") found."
    }

    /// One line per item, with the hint under each problem.
    public static func text(_ items: [DiagnosticItem]) -> String {
        items.map { item in
            switch item.status {
            case .ok: return "✓ \(item.name)"
            case .unknown: return "? \(item.name) (could not read)"
            case .problem: return "✗ \(item.name)\n   \(item.hint)"
            }
        }.joined(separator: "\n")
    }
}
