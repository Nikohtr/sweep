import CoreGraphics
import Testing
@testable import SweepCore

/// Pinch in on a tab closes that tab.
@Suite struct TabCloseTests {
    private let window = CGRect(x: 0, y: 25, width: 1000, height: 700)
    private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

    private func hit(_ y: CGFloat, role: String = "AXRadioButton", isTab: Bool = true) -> HitInfo {
        HitInfo(cursor: CGPoint(x: 300, y: y), role: role, windowFrame: window, isFullscreen: false,
                screenVisibleFrame: screen, isTab: isTab)
    }

    @Test func aTabIsItsOwnOrigin() {
        #expect(OriginClassifier.classify(hit(60)) == .tab)
        // Even inside the plain titlebar band.
        #expect(OriginClassifier.classify(hit(35)) == .tab)
    }

    @Test func superModifierStillMeansWindow() {
        #expect(OriginClassifier.classify(hit(60), superModifier: true) == .window)
    }

    @Test func nonTabsAreUnchanged() {
        #expect(OriginClassifier.classify(hit(35, role: "AXGroup", isTab: false)) == .titlebar)
        #expect(OriginClassifier.classify(hit(60, role: "AXRadioButton", isTab: false)) == nil)
    }

    @Test func tabOutsideTheWindowIsIgnored() {
        var h = hit(60)
        h.windowFrame = nil
        #expect(OriginClassifier.classify(h) == nil)
    }

    @Test func pinchInClosesTheTab() {
        #expect(TabActions.finalAction(for: [.pinchIn]) == .closeTab)
        #expect(TabActions.finalAction(for: [.pause, .pinchIn]) == .closeTab)
    }

    @Test func otherGesturesAreLeftToTheWindow() {
        #expect(TabActions.finalAction(for: [.swipe(.left)]) == nil)
        #expect(TabActions.finalAction(for: [.pinchIn, .pinchIn]) == nil)
    }

    @Test func closeTabIsCommandW() {
        #expect(TabAction.closeTab.chord == KeyChord(keyCode: 13, modifiers: [.command]))
    }
}

/// Pinch out on a tab opens a new tab.
@Suite struct NewTabTests {
    @Test func pinchOutOpensANewTab() {
        #expect(TabActions.finalAction(for: [.pinchOut]) == .newTab)
    }

    @Test func pinchOutTwiceIsLeftToTheWindow() {
        #expect(TabActions.finalAction(for: [.pinchOut, .pause, .pinchOut]) == nil)
    }

    @Test func newTabIsCommandT() {
        #expect(TabAction.newTab.chord == KeyChord(keyCode: 17, modifiers: [.command]))
    }

    @Test func onlyCloseSelectsTheTabFirst() {
        #expect(TabAction.closeTab.selectsTabFirst)
        #expect(!TabAction.newTab.selectsTabFirst)
    }
}

/// Tap and hold on a tab detaches it into a new window; the rest of the gesture acts on that window.
@Suite struct TabDetachTests {
    @Test func holdFirstDetaches() {
        #expect(TabActions.liveAction(newStep: .hold, steps: [.hold]) == .detachTab)
    }

    @Test func holdLaterDoesNotDetach() {
        #expect(TabActions.liveAction(newStep: .hold, steps: [.swipe(.left), .hold]) == nil)
        #expect(TabActions.liveAction(newStep: .swipe(.up), steps: [.hold, .swipe(.up)]) == nil)
    }

    @Test func chainedStepsFollowTheHold() {
        #expect(TabActions.chainedSteps([.hold, .swipe(.left), .swipe(.up)]) == [.swipe(.left), .swipe(.up)])
        #expect(TabActions.chainedSteps([.hold]) == [])
        #expect(TabActions.chainedSteps([.pinchIn]) == nil)
    }

    @Test func detachHasNoKeyChord() {
        #expect(TabAction.detachTab.chord == nil)
    }

    @Test func planDragsTheTabDownAndRestoresTheCursor() {
        let tab = CGRect(x: 100, y: 40, width: 200, height: 30)
        let cursor = CGPoint(x: 150, y: 50)
        let c = CGPoint(x: 200, y: 55)
        #expect(TabDetachPlan.steps(tab: tab, cursor: cursor) == [
            .mouseDown(c),
            .drag(CGPoint(x: 200, y: 85)), .drag(CGPoint(x: 200, y: 115)),
            .drag(CGPoint(x: 200, y: 145)), .drag(CGPoint(x: 200, y: 175)),
            .wait(0.2), .mouseUp(CGPoint(x: 200, y: 175)), .warp(cursor),
        ])
        #expect(TabDetachPlan.dragDistance == 120)
    }
}
