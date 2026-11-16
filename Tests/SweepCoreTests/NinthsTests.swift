import Testing
@testable import SweepCore

@Suite struct NinthsMappingTests {
    private let tertiary: Set<ModifierRole> = [.tertiary]
    private func cell(_ x: Range<Int>, _ y: Range<Int>) -> WindowAction {
        .snap(.grid(GridSpan(columns: 3, rows: 3, x: x, y: y)))
    }

    @Test func oneNinthFromBothAxes() {
        #expect(TitlebarActions.action(for: [.swipe(.left), .swipe(.up)], roles: tertiary) == cell(0..<1, 0..<1))
        #expect(TitlebarActions.action(for: [.swipe(.down), .swipe(.right)], roles: tertiary) == cell(2..<3, 2..<3))
    }

    @Test func missingAxisMeansCenter() {
        #expect(TitlebarActions.action(for: [.swipe(.left)], roles: tertiary) == cell(0..<1, 1..<2))
        #expect(TitlebarActions.action(for: [.swipe(.up)], roles: tertiary) == cell(1..<2, 0..<1))
        #expect(TitlebarActions.action(for: [.hold], roles: tertiary) == cell(1..<2, 1..<2))
    }

    @Test func repeatWidensToTwoNinths() {
        #expect(TitlebarActions.action(for: [.swipe(.left), .pause, .swipe(.left), .swipe(.up)], roles: tertiary)
                == cell(0..<2, 0..<1))
        #expect(TitlebarActions.action(for: [.swipe(.right), .swipe(.up), .pause, .swipe(.up)], roles: tertiary)
                == cell(2..<3, 0..<2))
    }

    @Test func repeatOnBothAxesIsFourNinths() {
        #expect(TitlebarActions.action(for: [.swipe(.right), .pause, .swipe(.right), .swipe(.down), .pause, .swipe(.down)],
                                       roles: tertiary) == cell(1..<3, 1..<3))
    }

    @Test func thirdRepeatGoesBackToOneCell() {
        #expect(TitlebarActions.action(for: [.swipe(.left), .pause, .swipe(.left), .pause, .swipe(.left)],
                                       roles: tertiary) == cell(0..<1, 1..<2))
    }

    @Test func pinchIsNotANinth() {
        #expect(TitlebarActions.finalAction(for: [.pinchIn], roles: tertiary) == nil)
    }

    @Test func tertiaryWinsOverSecondary() {
        #expect(TitlebarActions.action(for: [.swipe(.left)], roles: [.tertiary, .secondary]) == cell(0..<1, 1..<2))
    }
}
