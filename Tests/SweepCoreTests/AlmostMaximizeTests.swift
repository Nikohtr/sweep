import CoreGraphics
import Foundation
import Testing
@testable import SweepCore

private let v = CGRect(x: 0, y: 25, width: 1440, height: 800)

@Suite struct AlmostMaximizeTests {
    @Test func leavesAFivePercentMarginPerSide() {
        #expect(SnapLayout.frame(for: .almostMaximize, in: v) == CGRect(x: 72, y: 65, width: 1296, height: 720))
    }

    @Test func gridSpacingDoesNotChangeIt() {
        #expect(SnapLayout.frame(for: .almostMaximize, in: v, spacing: 10, screenEdges: true)
                == SnapLayout.frame(for: .almostMaximize, in: v))
    }

    @Test func settingSwapsSwipeUp() {
        var s = SweepSettings()
        #expect(!s.swipeUpFillsAlmost)
        #expect(TitlebarActions.action(for: [.swipe(.up)], roles: [], settings: s) == .snap(.maximize))
        s.swipeUpFillsAlmost = true
        #expect(TitlebarActions.action(for: [.swipe(.up)], roles: [], settings: s) == .snap(.almostMaximize))
        #expect(TitlebarActions.finalAction(for: [.swipe(.up)], roles: [], settings: s) == .snap(.almostMaximize))
        // Other gestures are not touched.
        #expect(TitlebarActions.action(for: [.swipe(.up), .pause, .swipe(.up)], roles: [], settings: s) == .snap(.topHalf))
    }

    @Test func settingSurvivesJSON() throws {
        var s = SweepSettings()
        s.swipeUpFillsAlmost = true
        #expect(try JSONDecoder().decode(SweepSettings.self, from: JSONEncoder().encode(s)).swipeUpFillsAlmost)
    }
}
