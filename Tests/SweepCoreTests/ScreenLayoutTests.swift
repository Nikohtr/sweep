import CoreGraphics
import Testing
@testable import SweepCore

// Top-left global coordinates. Main 1440×900 at origin; external 1920×1080 to the right;
// a third screen above the main one.
private let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let right = CGRect(x: 1440, y: -90, width: 1920, height: 1080)
private let above = CGRect(x: 0, y: -1080, width: 1440, height: 1080)
private let screens = [main, right, above]

@Suite struct ScreenLayoutTests {
    @Test func neighborsByDirection() {
        #expect(ScreenLayout.neighbor(of: 0, direction: .right, screens: screens) == 1)
        #expect(ScreenLayout.neighbor(of: 1, direction: .left, screens: screens) == 0)
        #expect(ScreenLayout.neighbor(of: 0, direction: .up, screens: screens) == 2)
        #expect(ScreenLayout.neighbor(of: 2, direction: .down, screens: screens) == 0)
    }

    @Test func noScreenInThatDirection() {
        #expect(ScreenLayout.neighbor(of: 0, direction: .left, screens: screens) == nil)
        #expect(ScreenLayout.neighbor(of: 0, direction: .down, screens: screens) == nil)
        #expect(ScreenLayout.neighbor(of: 0, direction: .right, screens: [main]) == nil)
    }

    @Test func overlappingRowBeatsCloserDiagonal() {
        // Two screens to the right: one beside main (overlapping rows), one further right and far below.
        let beside = CGRect(x: 1440, y: 0, width: 1000, height: 900)
        let diagonal = CGRect(x: 1440, y: 900, width: 800, height: 600)
        #expect(ScreenLayout.neighbor(of: 0, direction: .right, screens: [main, diagonal, beside]) == 2)
    }

    @Test func moveKeepsRelativePlaceAndScale() {
        let from = CGRect(x: 0, y: 25, width: 1440, height: 800)
        let to = CGRect(x: 1440, y: -90, width: 1920, height: 1080)
        let left = CGRect(x: 0, y: 25, width: 720, height: 800)    // left half
        #expect(ScreenLayout.move(frame: left, from: from, to: to) == CGRect(x: 1440, y: -90, width: 960, height: 1080))
    }

    @Test func movedWindowStaysInside() {
        let from = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        let to = CGRect(x: 2000, y: 0, width: 800, height: 600)
        let r = ScreenLayout.move(frame: CGRect(x: 1500, y: 900, width: 600, height: 400), from: from, to: to)
        #expect(to.contains(r))
        #expect(r.minX == r.minX.rounded() && r.width == r.width.rounded())
    }

    @Test func screenRoleSwipeMovesWindow() {
        #expect(TitlebarActions.action(for: [.swipe(.right)], roles: [.screen]) == .moveToScreen(.right))
        #expect(TitlebarActions.action(for: [.swipe(.up)], roles: [.screen]) == .moveToScreen(.up))
        #expect(TitlebarActions.finalAction(for: [.swipe(.down)], roles: [.screen]) == .moveToScreen(.down))
    }

    @Test func noRolesKeepsSnapping() {
        #expect(TitlebarActions.action(for: [.swipe(.right)], roles: []) == .snap(.rightHalf))
        #expect(TitlebarActions.finalAction(for: [.swipe(.down)], roles: []) == .minimize)
    }

    @Test func screenRoleOtherSequencesDoNothingYet() {
        #expect(TitlebarActions.action(for: [.swipe(.right), .swipe(.up)], roles: [.screen]) == nil)
        #expect(TitlebarActions.finalAction(for: [.pinchIn], roles: [.screen]) == nil)
    }
}
