import CoreGraphics
import Testing
@testable import SweepCore

private let left = CGRect(x: 0, y: 25, width: 720, height: 800)
private let right = CGRect(x: 720, y: 25, width: 720, height: 800)

@Suite struct AdjacentResizeTests {
    @Test func movingTheSharedEdgeResizesTheNeighbour() {
        let snapped = ["L": left, "R": right]
        var current = snapped
        current["L"] = CGRect(x: 0, y: 25, width: 900, height: 800)   // user dragged L's right edge
        let out = AdjacentResize.adjust(snapped: snapped, current: current)
        #expect(out == ["R": CGRect(x: 900, y: 25, width: 540, height: 800)])
    }

    @Test func gapIsKept() {
        let l = CGRect(x: 0, y: 25, width: 716, height: 800)
        let r = CGRect(x: 724, y: 25, width: 716, height: 800)     // 8 pt grid spacing
        let out = AdjacentResize.adjust(snapped: ["L": l, "R": r],
                                        current: ["L": CGRect(x: 0, y: 25, width: 816, height: 800), "R": r])
        #expect(out["R"] == CGRect(x: 824, y: 25, width: 616, height: 800))
    }

    @Test func verticalNeighbours() {
        let top = CGRect(x: 0, y: 25, width: 1440, height: 400)
        let bottom = CGRect(x: 0, y: 425, width: 1440, height: 400)
        let out = AdjacentResize.adjust(snapped: ["T": top, "B": bottom],
                                        current: ["T": CGRect(x: 0, y: 25, width: 1440, height: 300), "B": bottom])
        #expect(out["B"] == CGRect(x: 0, y: 325, width: 1440, height: 500))
    }

    @Test func aMovedWindowIsNotAResize() {
        let out = AdjacentResize.adjust(snapped: ["L": left, "R": right],
                                        current: ["L": left.offsetBy(dx: 50, dy: 0), "R": right])
        #expect(out.isEmpty)
    }

    @Test func neighboursMustOverlapOnTheOtherAxis() {
        let farBelow = CGRect(x: 720, y: 900, width: 720, height: 300)
        let out = AdjacentResize.adjust(snapped: ["L": left, "X": farBelow],
                                        current: ["L": CGRect(x: 0, y: 25, width: 900, height: 800), "X": farBelow])
        #expect(out.isEmpty)
    }

    @Test func neighbourNeverGetsTooSmall() {
        let out = AdjacentResize.adjust(snapped: ["L": left, "R": right],
                                        current: ["L": CGRect(x: 0, y: 25, width: 1400, height: 800), "R": right])
        #expect(out["R"]!.width >= AdjacentResize.minimumSize)
    }
}
