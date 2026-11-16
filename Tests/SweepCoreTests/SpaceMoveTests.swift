import CoreGraphics
import Testing
@testable import SweepCore

/// Tap-and-hold then swipe left/right, or the general modifier + swipe left/right, moves the
/// window to the Space on that side.
@Suite struct SpaceMoveTests {
    @Test func holdThenSwipe() {
        #expect(TitlebarActions.finalAction(for: [.hold, .swipe(.left)]) == .moveToSpace(.left))
        #expect(TitlebarActions.finalAction(for: [.hold, .pause, .swipe(.right)]) == .moveToSpace(.right))
    }

    @Test func generalSwipe() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.left)], roles: [.general]) == .moveToSpace(.left))
        #expect(TitlebarActions.finalAction(for: [.swipe(.right)], roles: [.general]) == .moveToSpace(.right))
    }

    @Test func onlyOnLift() {
        #expect(TitlebarActions.action(for: [.hold, .swipe(.left)]) == nil)
        #expect(TitlebarActions.action(for: [.swipe(.left)], roles: [.general]) == nil)
    }

    @Test func generalDoubleHorizontalDoesNothing() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.left), .pause, .swipe(.left)], roles: [.general]) == nil)
    }

    @Test func otherRulesStay() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.left)]) == .snap(.leftHalf))
        #expect(TitlebarActions.finalAction(for: [.hold, .swipe(.up)]) == .toggleFullscreen)
        #expect(TitlebarActions.finalAction(for: [.hold, .swipe(.down)]) == .minimize)
        #expect(TitlebarActions.finalAction(for: [.swipe(.down)], roles: [.general]) == .close)
    }

    @Test func grabPointIsOnTheTitlebarPastTheButtons() {
        let frame = CGRect(x: 100, y: 50, width: 800, height: 600)
        #expect(SpaceMovePlan.grabPoint(frame: frame) == CGPoint(x: 200, y: 62))
        let narrow = CGRect(x: 0, y: 0, width: 120, height: 300)
        #expect(SpaceMovePlan.grabPoint(frame: narrow) == CGPoint(x: 60, y: 12))
    }

    @Test func planHoldsTheWindowWhileSwitchingSpaces() {
        let grab = CGPoint(x: 200, y: 62)
        let cursor = CGPoint(x: 500, y: 300)
        #expect(SpaceMovePlan.steps(grab: grab, direction: .right, cursor: cursor) == [
            .mouseDown(grab), .drag(grab), .wait(0.1),
            .key(KeyChord(keyCode: 124, modifiers: [.control])), .wait(0.4),
            .mouseUp(grab), .warp(cursor),
        ])
        if case .key(let chord) = SpaceMovePlan.steps(grab: grab, direction: .left, cursor: cursor)[3] {
            #expect(chord.keyCode == 123)
        } else {
            Issue.record("no key step")
        }
    }

    @Test func noPlanForVerticalDirections() {
        #expect(SpaceMovePlan.steps(grab: .zero, direction: .up, cursor: .zero).isEmpty)
    }
}
