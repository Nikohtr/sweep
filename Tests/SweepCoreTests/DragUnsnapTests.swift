import CoreGraphics
import Testing
@testable import SweepCore

@Suite struct DragUnsnapTests {
    @Test func keepsTheCursorAtTheSameRelativeX() {
        // Left half 720 wide, grabbed at a quarter of its width; original size 400×300.
        let current = CGRect(x: 0, y: 25, width: 720, height: 800)
        let r = DragUnsnap.frame(originalSize: CGSize(width: 400, height: 300), current: current,
                                 cursor: CGPoint(x: 180, y: 35))
        #expect(r == CGRect(x: 80, y: 25, width: 400, height: 300))
        #expect(r.contains(CGPoint(x: 180, y: 35)))   // the cursor stays on the titlebar
    }

    @Test func startsOnlyAfterARealDrag() {
        #expect(!DragUnsnap.dragStarted(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 102, y: 101)))
        #expect(DragUnsnap.dragStarted(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 105, y: 100)))
    }

    @Test func settingAndSecondaryModifier() {
        var s = SweepSettings()
        #expect(DragUnsnap.applies(settings: s, held: []))
        #expect(!DragUnsnap.applies(settings: s, held: [.shift]))        // secondary skips it
        s.dragToUnsnap = false
        #expect(!DragUnsnap.applies(settings: s, held: []))
    }

    @Test func memoryCanBeReadWithoutForgetting() {
        var m = UnsnapMemory<String>()
        m.willSnap("w", from: CGRect(x: 0, y: 0, width: 400, height: 300))
        #expect(m.original("w")?.size == CGSize(width: 400, height: 300))
        #expect(m.keys == ["w"])
    }
}
