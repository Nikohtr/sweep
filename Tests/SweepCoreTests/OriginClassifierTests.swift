import CoreGraphics
import Testing
@testable import SweepCore

// Coordinates are global, top-left origin (like AX).

private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let visible = CGRect(x: 0, y: 25, width: 1440, height: 800)   // menu bar 25 pt, Dock 75 pt
private let window = CGRect(x: 100, y: 200, width: 800, height: 600)

private func hit(y: Double, x: Double = 400, role: String? = "AXGroup", fullscreen: Bool = false,
                 window w: CGRect? = window) -> HitInfo {
    HitInfo(cursor: CGPoint(x: x, y: y), role: role, windowFrame: w, isFullscreen: fullscreen,
            screenVisibleFrame: visible)
}

@Suite struct OriginClassifierTests {
    @Test(arguments: [200.0, 210, 223])
    func topBandIsTitlebar(y: Double) {
        #expect(OriginClassifier.classify(hit(y: y, role: "AXWindow")) == .titlebar)
    }

    @Test func titlebarBandAcceptsButtons() {
        #expect(OriginClassifier.classify(hit(y: 210, role: "AXButton")) == .titlebar)
    }

    @Test(arguments: ["AXToolbar", "AXGroup", "AXWindow", "AXStaticText"])
    func toolbarAreaOverBackground(role: String) {
        #expect(OriginClassifier.classify(hit(y: 260, role: role)) == .toolbar)
        #expect(OriginClassifier.classify(hit(y: 320, role: role)) == .toolbar)   // d = 120
    }

    @Test func belowToolbarCapIsRejected() {
        #expect(OriginClassifier.classify(hit(y: 321, role: "AXGroup")) == nil)
    }

    @Test(arguments: ["AXButton", "AXTextField", "AXPopUpButton", "AXCheckBox", "AXSlider"])
    func controlsBelowTitlebarAreRejected(role: String) {
        #expect(OriginClassifier.classify(hit(y: 260, role: role)) == nil)
    }

    @Test(arguments: ["AXScrollArea", "AXScrollBar", "AXTextArea", "AXSplitter"])
    func scrollAndTextAreasAreAlwaysRejected(role: String) {
        #expect(OriginClassifier.classify(hit(y: 210, role: role)) == nil)
        #expect(OriginClassifier.classify(hit(y: 260, role: role)) == nil)
    }

    @Test func outsideWindowIsRejected() {
        #expect(OriginClassifier.classify(hit(y: 210, x: 50)) == nil)
        #expect(OriginClassifier.classify(hit(y: 190)) == nil)
    }

    @Test func noWindowIsRejected() {
        #expect(OriginClassifier.classify(hit(y: 210, window: nil)) == nil)
    }

    @Test func superModifierUsesWholeWindow() {
        #expect(OriginClassifier.classify(hit(y: 700, role: "AXScrollArea"), superModifier: true) == .window)
        #expect(OriginClassifier.classify(hit(y: 700, x: 50), superModifier: true) == nil)
    }

    @Test func fullscreenAcceptsOnlyTheTitlebarBand() {
        // The hidden titlebar slides in at the top; below it is app content.
        #expect(OriginClassifier.classify(hit(y: 205, fullscreen: true)) == .titlebar)
        #expect(OriginClassifier.classify(hit(y: 252, fullscreen: true)) == .titlebar)   // below the menu bar
        #expect(OriginClassifier.classify(hit(y: 253, fullscreen: true)) == nil)
        #expect(OriginClassifier.classify(hit(y: 260, fullscreen: true)) == nil)
        #expect(OriginClassifier.classify(hit(y: 260, fullscreen: true), superModifier: true) == .window)
    }

    @Test func dockItemIsDock() {
        let h = HitInfo(cursor: CGPoint(x: 700, y: 870), role: "AXDockItem", windowFrame: nil,
                        isFullscreen: false, screenVisibleFrame: visible)
        #expect(OriginClassifier.classify(h) == .dock)
        let app = HitInfo(cursor: CGPoint(x: 700, y: 870), role: "AXApplicationDockItem", windowFrame: nil,
                          isFullscreen: false, screenVisibleFrame: visible)
        #expect(OriginClassifier.classify(app) == .dock)
    }

    @Test func emptyMenuBarAboveVisibleFrame() {
        let h = HitInfo(cursor: CGPoint(x: 900, y: 10), role: "AXMenuBar", windowFrame: nil,
                        isFullscreen: false, screenVisibleFrame: visible)
        #expect(OriginClassifier.classify(h) == .menubar)
        let item = HitInfo(cursor: CGPoint(x: 900, y: 10), role: "AXMenuBarItem", windowFrame: nil,
                           isFullscreen: false, screenVisibleFrame: visible)
        #expect(OriginClassifier.classify(item) == nil)
    }

    @Test func flipConvertsBottomLeftToTopLeft() {
        // AppKit rect 25 pt above the bottom of a 900 pt primary screen, 800 pt tall.
        let appKit = CGRect(x: 0, y: 75, width: 1440, height: 800)
        #expect(OriginClassifier.topLeft(appKit, primaryScreenHeight: 900) == CGRect(x: 0, y: 25, width: 1440, height: 800))
    }
}
