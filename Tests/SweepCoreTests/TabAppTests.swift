import CoreGraphics
import Foundation
import Testing
@testable import SweepCore

/// Tab gestures can be turned off per kind of app.
@Suite struct TabAppTests {
    @Test(arguments: [
        ("com.apple.Safari", TabApp.safari), ("company.thebrowser.Browser", .arc), ("com.google.Chrome", .chrome),
        ("com.apple.dt.Xcode", .xcode), ("com.microsoft.VSCode", .vscode), ("com.apple.finder", .native),
    ])
    func kindFromBundleID(id: String, kind: TabApp) {
        #expect(TabApp.of(bundleID: id) == kind)
    }

    @Test func unknownAppIsNative() {
        #expect(TabApp.of(bundleID: nil) == .native)
    }

    private func tabHit(_ app: String) -> HitInfo {
        HitInfo(cursor: CGPoint(x: 300, y: 60), role: "AXRadioButton",
                windowFrame: CGRect(x: 0, y: 25, width: 1000, height: 700), isFullscreen: false,
                screenVisibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875), appBundleID: app, isTab: true)
    }

    @Test func enabledByDefault() {
        #expect(SweepSettings().disabledTabApps.isEmpty)
        #expect(GestureGate.origin(hit: tabHit("com.apple.Safari"), held: [], settings: SweepSettings()) == .tab)
    }

    @Test func disabledKindFallsBackToTheTitlebar() {
        var s = SweepSettings()
        s.disabledTabApps = [.safari]
        #expect(GestureGate.origin(hit: tabHit("com.apple.Safari"), held: [], settings: s) == .titlebar)
        #expect(GestureGate.origin(hit: tabHit("com.google.Chrome"), held: [], settings: s) == .tab)
    }

    @Test func oldSettingsDecodeWithoutTheKey() throws {
        let s = try JSONDecoder().decode(SweepSettings.self, from: Data(#"{"sensitivity": 2}"#.utf8))
        #expect(s.disabledTabApps.isEmpty)
    }

    @Test func roundTrip() throws {
        var s = SweepSettings()
        s.disabledTabApps = [.xcode, .native]
        let back = try JSONDecoder().decode(SweepSettings.self, from: JSONEncoder().encode(s))
        #expect(back.disabledTabApps == [.xcode, .native])
    }
}
