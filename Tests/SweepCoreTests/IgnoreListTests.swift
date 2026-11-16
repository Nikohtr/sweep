import CoreGraphics
import Foundation
import Testing
@testable import SweepCore

private let visible = CGRect(x: 0, y: 25, width: 1440, height: 800)

private func titlebarHit(app: String?) -> HitInfo {
    HitInfo(cursor: CGPoint(x: 400, y: 210), role: "AXWindow",
            windowFrame: CGRect(x: 100, y: 200, width: 800, height: 600), isFullscreen: false,
            screenVisibleFrame: visible, appBundleID: app)
}

@Suite struct IgnoreListTests {
    @Test func toggleAddsAndRemovesSorted() {
        var list: [String] = []
        IgnoreList.toggle("com.b", in: &list)
        IgnoreList.toggle("com.a", in: &list)
        #expect(list == ["com.a", "com.b"])
        IgnoreList.toggle("com.b", in: &list)
        #expect(list == ["com.a"])
    }

    @Test func noDuplicates() {
        var list = ["com.a"]
        IgnoreList.add("com.a", to: &list)
        #expect(list == ["com.a"])
    }

    @Test func ignoredAppGetsNoGestures() {
        var s = SweepSettings()
        s.ignoredApps = ["com.example.game"]
        #expect(GestureGate.origin(hit: titlebarHit(app: "com.example.game"), held: [], settings: s) == nil)
        #expect(GestureGate.origin(hit: titlebarHit(app: "com.example.game"), held: [.command], settings: s) == nil)
        #expect(GestureGate.origin(hit: titlebarHit(app: "com.apple.finder"), held: [], settings: s) == .titlebar)
        #expect(GestureGate.origin(hit: titlebarHit(app: nil), held: [], settings: s) == .titlebar)
    }

    @Test func listSurvivesJSON() throws {
        var s = SweepSettings()
        s.ignoredApps = ["com.a"]
        #expect(try JSONDecoder().decode(SweepSettings.self, from: JSONEncoder().encode(s)).ignoredApps == ["com.a"])
    }

    @Test func menuTitle() {
        #expect(IgnoreList.menuTitle(appName: "Notes", ignored: false) == "Pause Sweep in Notes")
        #expect(IgnoreList.menuTitle(appName: "Notes", ignored: true) == "Resume Sweep in Notes")
    }
}
