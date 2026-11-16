import Foundation

extension SweepSettings {
    /// Gestures that start off for a new install: one slip would quit an app or minimize every window.
    public static let offForNewInstalls: [DockMenuGestureKind] = [.dockQuit, .menubarMinimizeAll]

    /// The settings a new install starts with. The plain `SweepSettings()` defaults stay "all on", because
    /// stored settings from older versions decode missing keys with them (old behavior).
    public static func newInstall() -> SweepSettings {
        var s = SweepSettings()
        s.disabledDockMenuGestures = offForNewInstalls
        return s
    }
}

/// Which settings to start with at launch.
public enum SettingsLoad {
    /// - Parameter stored: the saved settings JSON, read after the old-bundle-ID copy (`LegacyDefaults`).
    ///   Nil or unreadable = a new install, so it gets the safer defaults and the app saves them at once.
    public static func initial(stored: Data?) -> (settings: SweepSettings, isNewInstall: Bool) {
        if let stored, let saved = try? JSONDecoder().decode(SweepSettings.self, from: stored) {
            return (saved, false)
        }
        return (SweepSettings.newInstall(), true)
    }
}
