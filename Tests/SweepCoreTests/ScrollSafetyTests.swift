import CoreGraphics
import Testing
@testable import SweepCore

private let visible = CGRect(x: 0, y: 25, width: 1440, height: 800)
private let window = CGRect(x: 100, y: 200, width: 800, height: 600)

private func hit(_ role: String?, y: Double) -> HitInfo {
    HitInfo(cursor: CGPoint(x: 400, y: y), role: role, windowFrame: window, isFullscreen: false,
            screenVisibleFrame: visible)
}

@Suite struct ScrollSafetyTests {
    static let scrollingRoles = ["AXScrollArea", "AXScrollBar", "AXTextArea", "AXTextField", "AXWebArea",
                                 "AXTable", "AXOutline", "AXList", "AXSplitter"]

    @Test(arguments: scrollingRoles)
    func scrollingRolesNeverStartAGesture(role: String) {
        #expect(OriginClassifier.classify(hit(role, y: 205)) == nil)   // titlebar band
        #expect(OriginClassifier.classify(hit(role, y: 280)) == nil)   // toolbar band
        #expect(OriginClassifier.classify(hit(role, y: 600)) == nil)   // content
    }

    @Test func unknownRoleBelowToolbarIsContent() {
        #expect(OriginClassifier.classify(hit(nil, y: 400)) == nil)
    }

    @Test func superModifierOverridesOnPurpose() {
        // Holding super means "the whole window", so scrolling content is taken over by design.
        #expect(OriginClassifier.classify(hit("AXScrollArea", y: 600), superModifier: true) == .window)
    }

    @Test(arguments: [(TouchPhase?.some(.began), false, true), (.changed, false, true), (.mayBegin, false, true),
                      (.ended, false, true), (nil, false, false), (.changed, true, false), (nil, true, false)])
    func onlyFingerScrollsReachTheRecognizer(phase: TouchPhase?, momentum: Bool, expected: Bool) {
        #expect(ScrollFilter.isFingerScroll(phase: phase, momentum: momentum) == expected)
    }
}
