import Foundation


/// The version line for the About tab, from the bundle's Info.plist values.
public enum AppVersion {
    /// "Version 1.0.0 (212)", "Version 1.0.0" with no build number,
    /// or "Development build" when there is no bundle version (for example `swift run`).
    public static func display(short: String?, build: String?) -> String {
        let version = short?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !version.isEmpty else { return "Development build" }
        let number = build?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return number.isEmpty ? "Version \(version)" : "Version \(version) (\(number))"
    }
}
