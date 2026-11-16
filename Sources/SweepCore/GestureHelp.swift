/// Rows for the gesture lists in the settings window. Each row's `steps` are the
/// primitives the recognizer gives for that gesture, so tests can check the row against the mapper.
public struct GestureHelpRow: Sendable, Equatable {
    public let gesture: String
    public let action: String
    /// Modifier role that must be held, or nil.
    public let role: ModifierRole?
    public let steps: [Primitive]
}

public enum GestureHelp {
    public static let menubar: [GestureHelpRow] = [
        GestureHelpRow(gesture: "Double tap", action: "Unsnap all windows on this screen", role: nil, steps: [.tap]),
        GestureHelpRow(gesture: "Double tap", action: "Unsnap all windows on all screens", role: .secondary, steps: [.tap]),
        GestureHelpRow(gesture: "Swipe down", action: "Minimize all windows on this screen", role: nil, steps: [.swipe(.down)]),
        GestureHelpRow(gesture: "Swipe down twice", action: "Minimize all windows on all screens", role: nil,
                       steps: [.swipe(.down), .pause, .swipe(.down)]),
        GestureHelpRow(gesture: "Swipe up", action: "Bring back all minimized windows on this screen", role: nil,
                       steps: [.swipe(.up)]),
        GestureHelpRow(gesture: "Swipe up twice", action: "Bring back all minimized windows on all screens", role: nil,
                       steps: [.swipe(.up), .pause, .swipe(.up)]),
        GestureHelpRow(gesture: "Swipe right / left", action: "Switch to the next / previous app", role: nil,
                       steps: [.swipe(.right)]),
        GestureHelpRow(gesture: "Swipe toward a screen", action: "Move the snapped windows to that screen", role: .screen,
                       steps: [.swipe(.right)]),
    ]

    public static let titlebar: [GestureHelpRow] = [
        GestureHelpRow(gesture: "Pinch in", action: "Close the window", role: nil, steps: [.pinchIn]),
        GestureHelpRow(gesture: "Swipe down", action: "Close the window", role: .general, steps: [.swipe(.down)]),
        GestureHelpRow(gesture: "Swipe down", action: "Minimize the window", role: nil, steps: [.swipe(.down)]),
        GestureHelpRow(gesture: "Pinch out", action: "Toggle fullscreen", role: nil, steps: [.pinchOut]),
        GestureHelpRow(gesture: "Double tap", action: "Hide the app", role: .general, steps: [.tap]),
        GestureHelpRow(gesture: "Double tap", action: "Hide the other apps", role: .secondary, steps: [.tap]),
    ]

    /// Sweep's name for a modifier role, by what it does. Stored raw values do not change.
    public static func roleName(_ role: ModifierRole) -> String {
        switch role {
        case .general: return "Action"
        case .screen: return "Display"
        case .secondary: return "Extend"
        case .tertiary: return "Fine"
        case .superKey: return "Anywhere"
        }
    }

    /// One line on what holding the role's keys adds.
    public static func roleNote(_ role: ModifierRole) -> String {
        switch role {
        case .general: return "Close with a swipe down, hide the app, move a window to another Space."
        case .screen: return "Move windows to another display."
        case .secondary: return "Thirds and sixths, act on all windows, hide the other apps."
        case .tertiary: return "Ninths: a finer 3 × 3 grid."
        case .superKey: return "Gestures work anywhere on a window, not only on the titlebar. Works with the other keys."
        }
    }

    /// "Display (⌥)": the role and its current keys.
    public static func modifierLabel(_ role: ModifierRole, settings: SweepSettings) -> String {
        "\(roleName(role)) (\(settings.keys(for: role).symbols))"
    }
}
