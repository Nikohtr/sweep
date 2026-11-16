import Foundation

/// Rules for in-app updates. The updater itself (Sparkle) lives in the app target.
public enum UpdatePolicy {
    /// Updates run only in a build that has both the public update key and the feed URL.
    /// Contributor builds and `swift run` have neither, so they run with updates off.
    public static func isEnabled(publicKey: String?, feedURL: String?) -> Bool {
        let key = publicKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let feed = feedURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !key.isEmpty && !feed.isEmpty
    }

    /// Title of the menu row for an update that waits, or nil when there is none.
    public static func menuTitle(pendingVersion: String?) -> String? {
        pendingVersion.map { "Update Available: \($0)…" }
    }

    /// A scheduled check that finds an update shows a quiet menu row and icon badge
    /// instead of a window. Only with a visible icon: otherwise nobody would see it.
    public static func useGentleReminder(iconVisible: Bool) -> Bool { iconVisible }
}
