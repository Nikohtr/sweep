import CoreGraphics
import Testing
@testable import SweepCore

private let v = CGRect(x: 0, y: 25, width: 1441, height: 800)

@Suite struct ThirdsLayoutTests {
    @Test func thirdsTileTheWidth() {
        let l = SnapLayout.frame(for: .leftThird, in: v)
        let c = SnapLayout.frame(for: .centerThird, in: v)
        let r = SnapLayout.frame(for: .rightThird, in: v)
        #expect(l.minX == 0 && l.maxX == c.minX && c.maxX == r.minX && r.maxX == v.maxX)
        #expect(l.width == 480 && c.width == 480 && r.width == 481)
        #expect(l.height == v.height)
    }

    @Test func twoThirdsShareEdgesWithThirds() {
        let l2 = SnapLayout.frame(for: .leftTwoThirds, in: v)
        let r2 = SnapLayout.frame(for: .rightTwoThirds, in: v)
        #expect(l2.minX == v.minX && l2.maxX == SnapLayout.frame(for: .rightThird, in: v).minX)
        #expect(r2.maxX == v.maxX && r2.minX == SnapLayout.frame(for: .centerThird, in: v).minX)
    }

    @Test func spacingAppliesToThirds() {
        let l = SnapLayout.frame(for: .leftThird, in: v, spacing: 8, screenEdges: false)
        let c = SnapLayout.frame(for: .centerThird, in: v, spacing: 8, screenEdges: false)
        #expect(c.minX - l.maxX == 8)
        #expect(l.minX == v.minX)
    }
}

@Suite struct ThirdsMappingTests {
    private let secondary: Set<ModifierRole> = [.secondary]

    @Test func oneSwipeIsAThird() {
        #expect(TitlebarActions.action(for: [.swipe(.left)], roles: secondary) == .snap(.leftThird))
        #expect(TitlebarActions.action(for: [.swipe(.right)], roles: secondary) == .snap(.rightThird))
    }

    @Test func repeatSwitchesToTwoThirdsAndBack() {
        #expect(TitlebarActions.action(for: [.swipe(.left), .pause, .swipe(.left)], roles: secondary)
                == .snap(.leftTwoThirds))
        #expect(TitlebarActions.action(for: [.swipe(.left), .pause, .swipe(.left), .pause, .swipe(.left)],
                                       roles: secondary) == .snap(.leftThird))
        #expect(TitlebarActions.action(for: [.swipe(.right), .pause, .swipe(.right)], roles: secondary)
                == .snap(.rightTwoThirds))
    }

    @Test func directionChangeStartsANewRun() {
        #expect(TitlebarActions.action(for: [.swipe(.left), .pause, .swipe(.left), .swipe(.right)], roles: secondary)
                == .snap(.rightThird))
    }

    @Test func holdIsCenterThird() {
        #expect(TitlebarActions.action(for: [.hold], roles: secondary) == .snap(.centerThird))
        #expect(TitlebarActions.finalAction(for: [.hold], roles: secondary) == .snap(.centerThird))
    }

    @Test func verticalAndPinchAreNotThirds() {
        #expect(TitlebarActions.action(for: [.swipe(.up)], roles: secondary) == nil)
        #expect(TitlebarActions.finalAction(for: [.pinchIn], roles: secondary) == nil)
    }

    @Test func withoutSecondaryHalvesStay() {
        #expect(TitlebarActions.action(for: [.swipe(.left)], roles: []) == .snap(.leftHalf))
        #expect(TitlebarActions.action(for: [.hold], roles: []) == nil)
    }
}
