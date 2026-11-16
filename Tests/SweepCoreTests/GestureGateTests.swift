import CoreGraphics
import Testing
@testable import SweepCore

private let visible = CGRect(x: 0, y: 25, width: 1440, height: 800)
private let window = CGRect(x: 100, y: 200, width: 800, height: 600)

private func hit(y: Double, role: String = "AXScrollArea") -> HitInfo {
    HitInfo(cursor: CGPoint(x: 400, y: y), role: role, windowFrame: window, isFullscreen: false,
            screenVisibleFrame: visible)
}

@Suite struct GestureGateTests {
    private let s = SweepSettings()

    @Test func superHeldAllowsContentArea() {
        #expect(GestureGate.origin(hit: hit(y: 600), held: [.command], settings: s) == .window)
    }

    @Test func superPlusOtherRoleStillWholeWindow() {
        #expect(GestureGate.origin(hit: hit(y: 600), held: [.command, .shift], settings: s) == .window)
    }

    @Test func withoutSuperContentIsRejected() {
        #expect(GestureGate.origin(hit: hit(y: 600), held: [], settings: s) == nil)
        #expect(GestureGate.origin(hit: hit(y: 600), held: [.control], settings: s) == nil)
    }

    @Test func titlebarWorksWithAndWithoutSuper() {
        #expect(GestureGate.origin(hit: hit(y: 210, role: "AXWindow"), held: [], settings: s) == .titlebar)
        #expect(GestureGate.origin(hit: hit(y: 210, role: "AXWindow"), held: [.command], settings: s) == .window)
    }

    @Test func customSuperKeyIsUsed() {
        var c = s
        c.setKeys([.option, .command], for: .superKey)
        c.setKeys([], for: .screen)
        #expect(GestureGate.origin(hit: hit(y: 600), held: [.command], settings: c) == nil)
        #expect(GestureGate.origin(hit: hit(y: 600), held: [.option, .command], settings: c) == .window)
    }
}

@Suite struct RequireSuperTests {
    private var s: SweepSettings {
        var s = SweepSettings()
        s.requireSuperModifier = true
        return s
    }

    @Test func titlebarNeedsSuperWhenRequired() {
        #expect(GestureGate.origin(hit: hit(y: 210, role: "AXWindow"), held: [], settings: s) == nil)
        #expect(GestureGate.origin(hit: hit(y: 210, role: "AXWindow"), held: [.control], settings: s) == nil)
        #expect(GestureGate.origin(hit: hit(y: 210, role: "AXWindow"), held: [.command], settings: s) == .window)
    }

    @Test func dockAndMenuBarNeedSuperWhenRequired() {
        let dock = HitInfo(cursor: CGPoint(x: 700, y: 870), role: "AXDockItem", windowFrame: nil,
                           isFullscreen: false, screenVisibleFrame: visible)
        #expect(GestureGate.origin(hit: dock, held: [], settings: s) == nil)
        #expect(GestureGate.origin(hit: dock, held: [.command], settings: s) == .dock)
    }

    @Test func offByDefault() {
        #expect(!SweepSettings().requireSuperModifier)
        #expect(GestureGate.origin(hit: hit(y: 210, role: "AXWindow"), held: [], settings: SweepSettings()) == .titlebar)
    }
}

@Suite struct EnableGesturesTests {
    @Test func onByDefault() {
        #expect(SweepSettings().gesturesEnabled)
    }

    @Test func offBlocksEveryGesture() {
        var s = SweepSettings()
        s.gesturesEnabled = false
        #expect(GestureGate.origin(hit: hit(y: 210, role: "AXWindow"), held: [], settings: s) == nil)
        #expect(GestureGate.origin(hit: hit(y: 600), held: [.command], settings: s) == nil)
    }

    @Test func iconDimsWhenOffOrWithoutPermission() {
        #expect(!MenuBarPolicy.iconDimmed(gesturesEnabled: true, permissionGranted: true))
        #expect(MenuBarPolicy.iconDimmed(gesturesEnabled: false, permissionGranted: true))
        #expect(MenuBarPolicy.iconDimmed(gesturesEnabled: true, permissionGranted: false))
    }
}
