import Foundation

/// Log names and gesture line texts. The app writes them with `os.Logger`; gesture lines are debug level,
/// so macOS keeps them only while someone streams them (`streamCommand`).
public enum SweepLog {
    /// Same as the bundle ID (also under `swift run`, where there is no bundle).
    public static let subsystem = "io.github.nikohtr.sweep"
    /// Recognized gestures, steps, cancels and dropped hit tests (debug level).
    public static let gestureCategory = "gesture"
    /// Start-up and input problems (error level).
    public static let appCategory = "app"

    /// The Terminal command that shows every Sweep line, debug lines included.
    public static var streamCommand: String {
        "log stream --style compact --level debug --predicate 'subsystem == \"\(subsystem)\"'"
    }

    /// " on <origin> [role+role]", or "" with no context. Roles are the stored modifier names.
    public static func place(origin: String?, roles: [String]) -> String {
        guard let origin else { return "" }
        return " on \(origin)" + (roles.isEmpty ? "" : " [" + roles.joined(separator: "+") + "]")
    }

    public static func ended(place: String, steps: [String]) -> String {
        "Sweep gesture\(place): " + (steps.isEmpty ? "none" : steps.joined(separator: ", "))
    }

    public static func cancelled(place: String) -> String { "Sweep gesture\(place): cancelled" }

    public static func step(_ step: String) -> String { "Sweep gesture step: \(step)" }

    public static let dropped = "Sweep gesture: dropped (the app under the cursor did not answer)"
}
