import Foundation
import Testing
@testable import SweepCore

/// Safer defaults for new installs only.
@Suite struct SafeDefaultsTests {
    @Test func newInstallStartsWithQuitAndMinimizeAllOff() {
        let s = SweepSettings.newInstall()
        #expect(!s.allows(.dockQuit))
        #expect(!s.allows(.menubarMinimizeAll))
        // Everything else is as in the plain defaults.
        var rest = s
        rest.disabledDockMenuGestures = []
        #expect(rest == SweepSettings())
    }

    @Test func noStoredSettingsMeansNewInstall() {
        let load = SettingsLoad.initial(stored: nil)
        #expect(load.settings == SweepSettings.newInstall())
        #expect(load.isNewInstall)
    }

    @Test func oldStoredSettingsWithoutTheKeyKeepEveryGestureOn() throws {
        // Saved by an older version: the key is missing, so the old behavior (all on) stays.
        let old = Data(#"{"sensitivity":2,"disabledGestures":["close"]}"#.utf8)
        let load = SettingsLoad.initial(stored: old)
        #expect(!load.isNewInstall)
        #expect(load.settings.allows(.dockQuit))
        #expect(load.settings.allows(.menubarMinimizeAll))
        #expect(load.settings.sensitivity == 2)
    }

    @Test func storedChoicesAreKept() throws {
        var mine = SweepSettings.newInstall()
        mine.disabledDockMenuGestures = []   // the user turned both back on
        let load = SettingsLoad.initial(stored: try JSONEncoder().encode(mine))
        #expect(load.settings == mine)
        #expect(!load.isNewInstall)
    }

    @Test func unreadableStoredSettingsStartSafe() {
        let load = SettingsLoad.initial(stored: Data("not json".utf8))
        #expect(load.settings == SweepSettings.newInstall())
        #expect(load.isNewInstall)
    }

    @Test func restoreAllGoesToTheNewInstallDefaults() {
        var s = SweepSettings()
        s.sensitivity = 1
        s.ignoredApps = ["com.example.game"]
        let r = s.restoredDefaults()
        #expect(!r.allows(.dockQuit))
        #expect(!r.allows(.menubarMinimizeAll))
        #expect(r.ignoredApps == ["com.example.game"])
        #expect(r.sensitivity == SweepSettings().sensitivity)
    }
}
