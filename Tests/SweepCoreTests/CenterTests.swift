import CoreGraphics
import Testing
@testable import SweepCore

private let v = CGRect(x: 0, y: 25, width: 1440, height: 800)

@Suite struct CenterTests {
    @Test func doubleTapCenters() {
        #expect(TitlebarActions.action(for: [.tap]) == .center)
        #expect(TitlebarActions.finalAction(for: [.tap]) == .center)
        #expect(TitlebarActions.action(for: [.tap], roles: []) == .center)
    }

    @Test func centeredFrameIsWholeAndInside() {
        let r = SnapLayout.centered(size: CGSize(width: 801, height: 601), in: v)
        #expect(r == CGRect(x: 319, y: 124, width: 801, height: 601))   // odd remainders round down
    }

    @Test func tooLargeSizeIsClamped() {
        #expect(SnapLayout.centered(size: CGSize(width: 3000, height: 2000), in: v) == v)
    }

    @Test func memoryKeepsTheFirstPreSnapFrame() {
        var m = UnsnapMemory<String>()
        let original = CGRect(x: 10, y: 40, width: 600, height: 400)
        m.willSnap("w", from: original)
        m.willSnap("w", from: CGRect(x: 0, y: 25, width: 720, height: 800))   // second snap: keep the first
        #expect(m.takeOriginal("w") == original)
        #expect(m.takeOriginal("w") == nil)   // unsnap forgets it
    }

    @Test func memoryIsPerWindow() {
        var m = UnsnapMemory<Int>()
        m.willSnap(1, from: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(m.takeOriginal(2) == nil)
        m.forget(1)
        #expect(m.takeOriginal(1) == nil)
    }
}
