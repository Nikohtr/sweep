import CoreGraphics
import Testing
@testable import SweepCore

private let visible = CGRect(x: 0, y: 25, width: 1440, height: 800)

private func menuHit(role: String, isAppMenu: Bool) -> HitInfo {
    HitInfo(cursor: CGPoint(x: 60, y: 10), role: role, windowFrame: nil, isFullscreen: false,
            screenVisibleFrame: visible, isAppMenu: isAppMenu)
}

@Suite struct AppMenuTests {
    @Test func appNameMenuIsItsOwnOrigin() {
        #expect(OriginClassifier.classify(menuHit(role: "AXMenuBarItem", isAppMenu: true)) == .appMenu)
    }

    @Test func otherMenuItemsStayIgnored() {
        #expect(OriginClassifier.classify(menuHit(role: "AXMenuBarItem", isAppMenu: false)) == nil)
    }

    @Test func toggleTurnsItOff() {
        var s = SweepSettings()
        #expect(GestureGate.origin(hit: menuHit(role: "AXMenuBarItem", isAppMenu: true), held: [], settings: s) == .appMenu)
        s.appMenuGestures = false
        #expect(GestureGate.origin(hit: menuHit(role: "AXMenuBarItem", isAppMenu: true), held: [], settings: s) == nil)
    }

    @Test func appMenuUsesTheDockGestures() {
        #expect(DockActions.finalAction(for: [.pinchIn], roles: []) == .quit)   // same table as the Dock
    }
}
