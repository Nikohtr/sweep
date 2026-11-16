/// Menu bar icon rules (General tab: "Show in menu bar"; the window stays reachable from Finder).
public enum MenuBarPolicy {
    public static func iconVisible(settings: SweepSettings) -> Bool { settings.showInMenuBar }

    /// Opening the app again (Finder, Launchpad, Dock) shows the settings window.
    /// Always, so a hidden icon can never lock the user out.
    /// The icon looks dimmed when gestures are paused or Accessibility permission is missing.
    public static func iconDimmed(gesturesEnabled: Bool, permissionGranted: Bool) -> Bool {
        !gesturesEnabled || !permissionGranted
    }

    public static func openSettingsOnReopen(iconVisible: Bool) -> Bool { true }

    /// A problem the menu shows at the top, with one item that fixes it.
    public struct Problem: Sendable, Equatable {
        public enum Fix: Sendable, Equatable { case grantAccess, retryInput }
        public let message: String
        public let fixTitle: String
        public let fix: Fix
    }

    /// The menu shows a warning row only when Sweep cannot work. When all is well (or while the
    /// first permission check runs) it shows nothing, so the menu stays short.
    public static func problem(permission: PermissionFlow.Status, inputFailed: Bool) -> Problem? {
        switch permission {
        case .denied:
            return Problem(message: "Sweep needs Accessibility access", fixTitle: "Grant Access…", fix: .grantAccess)
        case .granted where inputFailed:
            return Problem(message: "Gestures could not start", fixTitle: "Try Again", fix: .retryInput)
        default:
            return nil
        }
    }
}
