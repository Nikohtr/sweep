import Foundation
import Testing
@testable import SweepCore

/// Settings export and import.
@Suite struct SettingsFileTests {
    var custom: SweepSettings {
        var s = SweepSettings()
        s.sensitivity = 1
        s.gridSpacing = 7
        s.ignoredApps = ["com.example.game"]
        s.disabledGestures = [.close]
        s.disabledDockMenuGestures = [.dockQuit]
        s.undoHotkey = true
        return s
    }

    @Test func roundTrip() throws {
        let data = try SettingsFile.export(custom)
        let back = try SettingsFile.imported(data, current: SweepSettings())
        var expected = custom
        expected.tutorialSeen = SweepSettings().tutorialSeen
        #expect(back == expected)
    }

    @Test func fileHasAppNameAndFormatVersion() throws {
        let object = try JSONSerialization.jsonObject(with: SettingsFile.export(custom)) as? [String: Any]
        #expect(object?["app"] as? String == "Sweep")
        #expect(object?["formatVersion"] as? String == SettingsFile.formatVersion)
        #expect(SettingsFile.formatVersion == "1.0")
        let settings = object?["settings"] as? [String: Any]
        #expect(settings?["ignoredApps"] as? [String] == ["com.example.game"])
    }

    @Test func importKeepsThisMacsTutorialState() throws {
        var current = SweepSettings()
        current.tutorialSeen = true
        var other = custom
        other.tutorialSeen = false
        let back = try SettingsFile.imported(SettingsFile.export(other), current: current)
        #expect(back.tutorialSeen)
    }

    @Test func importKeepsThisMacsLoginItemState() throws {
        var other = custom
        other.launchAtLogin = true
        #expect(!(try SettingsFile.imported(SettingsFile.export(other), current: SweepSettings())).launchAtLogin)
    }

    @Test func unknownKeysAreIgnored() throws {
        let json = #"{"app":"Sweep","formatVersion":"1.3","futureTopLevel":1,"settings":{"sensitivity":2,"futureSetting":true}}"#
        let s = try SettingsFile.imported(Data(json.utf8), current: SweepSettings())
        #expect(s.sensitivity == 2)
    }

    @Test func missingSettingsKeysGetTheOldDefaults() throws {
        // An export from an older version: keys it did not know get the plain defaults (all gestures on).
        let json = #"{"app":"Sweep","formatVersion":"1.0","settings":{"sensitivity":4}}"#
        let s = try SettingsFile.imported(Data(json.utf8), current: SweepSettings.newInstall())
        #expect(s.sensitivity == 4)
        #expect(s.allows(.dockQuit))
    }

    @Test func newerMajorFormatIsRejected() {
        let json = #"{"app":"Sweep","formatVersion":"2.0","settings":{"sensitivity":2}}"#
        #expect(throws: SettingsFile.ImportError.newerFormat("2.0")) {
            try SettingsFile.imported(Data(json.utf8), current: SweepSettings())
        }
    }

    @Test func badFilesAreRejected() {
        let cases: [(String, SettingsFile.ImportError)] = [
            ("not json at all", .notASettingsFile),
            (#"{"formatVersion":"1.0","settings":{}}"#, .notASettingsFile),             // no "app"
            (#"{"app":"Other","formatVersion":"1.0","settings":{}}"#, .notASettingsFile),
            (#"{"app":"Sweep","settings":{}}"#, .notASettingsFile),                     // no version
            (#"{"app":"Sweep","formatVersion":"one","settings":{}}"#, .notASettingsFile),
            (#"{"app":"Sweep","formatVersion":"1.0"}"#, .notASettingsFile),             // no settings
            (#"{"app":"Sweep","formatVersion":"1.0","settings":{"sensitivity":"high"}}"#, .badSettings),
        ]
        for (json, error) in cases {
            #expect(throws: error) { try SettingsFile.imported(Data(json.utf8), current: SweepSettings()) }
        }
    }

    @Test func outOfRangeNumbersAreClamped() throws {
        let json = #"{"app":"Sweep","formatVersion":"1.0","settings":{"sensitivity":99}}"#
        #expect(try SettingsFile.imported(Data(json.utf8), current: SweepSettings()).sensitivity
            == SweepSettings.sensitivityRange.upperBound)
    }

    @Test func errorTextsAreShort() {
        #expect(SettingsFile.ImportError.newerFormat("2.0").message
            == "This file is from a newer version of Sweep (format 2.0). Update Sweep, then try again.")
        #expect(SettingsFile.ImportError.notASettingsFile.message == "This is not a Sweep settings file.")
        #expect(SettingsFile.ImportError.badSettings.message
            == "This settings file is damaged. Nothing was changed.")
        #expect(SettingsFile.suggestedName == "Sweep Settings.json")
    }
}
