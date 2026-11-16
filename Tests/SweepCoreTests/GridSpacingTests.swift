import CoreGraphics
import Testing
@testable import SweepCore

private let v = CGRect(x: 0, y: 25, width: 1440, height: 800)

private func f(_ t: SnapTarget, _ g: Int, edges: Bool = false, in r: CGRect = v) -> CGRect {
    SnapLayout.frame(for: t, in: r, spacing: CGFloat(g), screenEdges: edges)
}

@Suite struct GridSpacingTests {
    @Test func zeroSpacingMatchesOldLayout() {
        for t in [SnapTarget.leftHalf, .rightHalf, .topHalf, .bottomHalf, .maximize, .topLeft, .bottomRight] {
            #expect(f(t, 0) == SnapLayout.frame(for: t, in: v))
            #expect(f(t, 0, edges: true) == SnapLayout.frame(for: t, in: v))
        }
    }

    @Test func gapBetweenHalvesWithoutEdges() {
        let l = f(.leftHalf, 8), r = f(.rightHalf, 8)
        #expect(l == CGRect(x: 0, y: 25, width: 716, height: 800))
        #expect(r == CGRect(x: 724, y: 25, width: 716, height: 800))
        #expect(r.minX - l.maxX == 8)
    }

    @Test func edgesInsetEveryOuterSide() {
        let l = f(.leftHalf, 8, edges: true)
        #expect(l == CGRect(x: 8, y: 33, width: 708, height: 784))
        #expect(f(.maximize, 8, edges: true) == v.insetBy(dx: 8, dy: 8))
        #expect(f(.maximize, 8) == v)
    }

    @Test(arguments: [1, 5, 7, 12])
    func oddAndEvenGapsAreExactAndWhole(g: Int) {
        let tl = f(.topLeft, g), tr = f(.topRight, g), bl = f(.bottomLeft, g)
        #expect(tr.minX - tl.maxX == CGFloat(g))
        #expect(bl.minY - tl.maxY == CGFloat(g))
        for r in [tl, tr, bl] {
            #expect(r.minX == r.minX.rounded() && r.width == r.width.rounded())
            #expect(r.minY == r.minY.rounded() && r.height == r.height.rounded())
        }
    }

    @Test func minusOneOverlapsNeighboursByOnePoint() {
        let l = f(.leftHalf, -1), r = f(.rightHalf, -1)
        #expect(l.maxX - r.minX == 1)
        // A negative gap never pushes windows past the screen edge.
        #expect(f(.leftHalf, -1, edges: true).minX == v.minX)
    }

    @Test func settingsDriveTheLayout() {
        var s = SweepSettings()
        s.gridSpacing = 6
        s.gridIncludesScreenEdges = true
        #expect(SnapLayout.frame(for: .maximize, in: v, settings: s) == v.insetBy(dx: 6, dy: 6))
    }
}
