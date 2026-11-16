import CoreGraphics
import Testing
@testable import SweepCore

private let v = CGRect(x: 0, y: 25, width: 1441, height: 801)

@Suite struct GridSpanTests {
    @Test func cellsTileTheFrame() {
        let a = SnapLayout.frame(for: .grid(GridSpan(columns: 3, rows: 2, x: 0..<1, y: 0..<1)), in: v)
        let b = SnapLayout.frame(for: .grid(GridSpan(columns: 3, rows: 2, x: 1..<2, y: 1..<2)), in: v)
        #expect(a == CGRect(x: 0, y: 25, width: 480, height: 400))
        #expect(b.minX == a.maxX && b.minY == a.maxY)
        let last = SnapLayout.frame(for: .grid(GridSpan(columns: 3, rows: 2, x: 2..<3, y: 1..<2)), in: v)
        #expect(last.maxX == v.maxX && last.maxY == v.maxY)
    }

    @Test func spanMatchesThirds() {
        #expect(SnapLayout.frame(for: .grid(GridSpan(columns: 3, rows: 1, x: 0..<2, y: 0..<1)), in: v)
                == SnapLayout.frame(for: .leftTwoThirds, in: v))
        #expect(SnapLayout.frame(for: .grid(GridSpan(columns: 3, rows: 1, x: 1..<2, y: 0..<1)), in: v)
                == SnapLayout.frame(for: .centerThird, in: v))
    }

    @Test func spacingWorksOnGridCells() {
        let a = SnapLayout.frame(for: .grid(GridSpan(columns: 3, rows: 2, x: 0..<1, y: 0..<1)), in: v,
                                 spacing: 6, screenEdges: false)
        let b = SnapLayout.frame(for: .grid(GridSpan(columns: 3, rows: 2, x: 0..<1, y: 1..<2)), in: v,
                                 spacing: 6, screenEdges: false)
        #expect(b.minY - a.maxY == 6)
    }
}

@Suite struct SixthsMappingTests {
    private let secondary: Set<ModifierRole> = [.secondary]
    private func cell(_ x: Range<Int>, _ y: Range<Int>) -> WindowAction {
        .snap(.grid(GridSpan(columns: 3, rows: 2, x: x, y: y)))
    }

    @Test func thirdPlusVerticalInEitherOrder() {
        #expect(TitlebarActions.action(for: [.swipe(.left), .swipe(.up)], roles: secondary) == cell(0..<1, 0..<1))
        #expect(TitlebarActions.action(for: [.swipe(.up), .swipe(.left)], roles: secondary) == cell(0..<1, 0..<1))
        #expect(TitlebarActions.action(for: [.swipe(.right), .swipe(.down)], roles: secondary) == cell(2..<3, 1..<2))
    }

    @Test func twoThirdsPlusVertical() {
        #expect(TitlebarActions.action(for: [.swipe(.left), .pause, .swipe(.left), .swipe(.down)], roles: secondary)
                == cell(0..<2, 1..<2))
    }

    @Test func holdPlusVerticalIsCenterColumn() {
        #expect(TitlebarActions.action(for: [.hold, .swipe(.up)], roles: secondary) == cell(1..<2, 0..<1))
        #expect(TitlebarActions.finalAction(for: [.hold, .swipe(.down)], roles: secondary) == cell(1..<2, 1..<2))
    }

    @Test func lastVerticalWins() {
        #expect(TitlebarActions.action(for: [.swipe(.left), .swipe(.up), .swipe(.down)], roles: secondary)
                == cell(0..<1, 1..<2))
    }

    @Test func verticalAloneIsStillNothing() {
        #expect(TitlebarActions.action(for: [.swipe(.up)], roles: secondary) == nil)
    }
}
