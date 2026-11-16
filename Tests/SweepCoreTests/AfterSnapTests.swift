import CoreGraphics
import Testing
@testable import SweepCore

@Suite struct AfterSnapTests {
    @Test func stepsFollowSettings() {
        var s = SweepSettings()
        s.activateAfterSnap = true
        s.moveCursorAfterSnap = false
        #expect(AfterSnap.steps(settings: s) == [.activate])
        s.moveCursorAfterSnap = true
        #expect(AfterSnap.steps(settings: s) == [.activate, .moveCursor])
        s.activateAfterSnap = false
        #expect(AfterSnap.steps(settings: s) == [.moveCursor])
        s.moveCursorAfterSnap = false
        #expect(AfterSnap.steps(settings: s).isEmpty)
    }

    @Test func cursorGoesToTheTitlebarMiddle() {
        #expect(AfterSnap.cursorTarget(frame: CGRect(x: 0, y: 25, width: 721, height: 800)) == CGPoint(x: 360, y: 37))
    }

    @Test func onlyAfterASnapOnLift() {
        #expect(AfterSnap.applies(output: .ended([.swipe(.left)]), lastAction: .snap(.leftHalf)))
        #expect(!AfterSnap.applies(output: .step(.swipe(.left)), lastAction: .snap(.leftHalf)))
        #expect(!AfterSnap.applies(output: .ended([.swipe(.down)]), lastAction: .minimize))
        #expect(!AfterSnap.applies(output: .cancelled, lastAction: .snap(.leftHalf)))
    }
}
