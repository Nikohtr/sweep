/// What Settings › About › Uninstall Sweep… does, in order, after the user confirms.
public enum UninstallPlan {
    public enum Step: Sendable, Equatable {
        case unregisterLoginItem
        /// `tccutil reset Accessibility <bundle ID>`. If it fails: `fallback(for:)`.
        case resetAccessibility(bundleID: String)
        /// Opens System Settings at Accessibility so the user can remove Sweep by hand.
        case openAccessibilitySettings
        case removeDefaults(domain: String)
        case removeFolder(String)
        /// `NSWorkspace.recycle`: the user can still put it back.
        case trashApp(String)
        case quit
    }

    public static func steps(bundleID: String, appPath: String, location: MoveToApplications.Location,
                             homeDirectory: String) -> [Step] {
        var steps: [Step] = [
            .unregisterLoginItem,
            .resetAccessibility(bundleID: bundleID),
            .removeDefaults(domain: bundleID),
            .removeDefaults(domain: LegacyDefaults.oldDomain),
            .removeFolder("\(homeDirectory)/Library/Caches/\(bundleID)"),
            .removeFolder("\(homeDirectory)/Library/HTTPStorages/\(bundleID)"),
        ]
        if trashesApp(location) { steps.append(.trashApp(appPath)) }
        steps.append(.quit)
        return steps
    }

    /// Never the repo's dev build, and never a translocated path (a read-only view of the real file).
    public static func trashesApp(_ location: MoveToApplications.Location) -> Bool {
        location == .applications || location == .elsewhere
    }

    /// What to do when a step fails; nil = go on with the next step.
    public static func fallback(for step: Step) -> Step? {
        if case .resetAccessibility = step { return .openAccessibilitySettings }
        return nil
    }

    public static func tccutilArguments(bundleID: String) -> [String] { ["reset", "Accessibility", bundleID] }

    public static let accessibilitySettingsURL =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    public static let confirmTitle = "Uninstall Sweep?"

    public static func confirmText(trashesApp: Bool) -> String {
        trashesApp
            ? "Sweep turns off Open at login, deletes its settings, removes its Accessibility permission "
                + "and moves itself to the Trash. Then it quits. This cannot be undone."
            : "Sweep turns off Open at login, deletes its settings and removes its Accessibility permission. "
                + "Then it quits. Delete the app yourself. This cannot be undone."
    }

    public static let accessibilityHint =
        "In Privacy & Security › Accessibility, select Sweep and click the minus button (−)."
}
