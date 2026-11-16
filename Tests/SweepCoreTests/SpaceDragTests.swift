import CoreGraphics
import Testing
@testable import SweepCore

/// In Mission Control, a swipe on a Space in the Spaces bar moves it to the next screen.
@Suite struct SpaceDragTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test func spacesBarIsTheTopBand() {
        #expect(MissionControlSpaces.isInSpacesBar(cursor: CGPoint(x: 500, y: 60), screenFrame: screen))
        #expect(MissionControlSpaces.isInSpacesBar(cursor: CGPoint(x: 500, y: 120), screenFrame: screen))
        #expect(!MissionControlSpaces.isInSpacesBar(cursor: CGPoint(x: 500, y: 121), screenFrame: screen))
        #expect(!MissionControlSpaces.isInSpacesBar(cursor: CGPoint(x: 1500, y: 60), screenFrame: screen))
    }

    private func hit(_ y: CGFloat) -> HitInfo {
        HitInfo(cursor: CGPoint(x: 500, y: y), role: "AXButton", windowFrame: nil, isFullscreen: false,
                screenVisibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875), inMissionControl: true,
                screenFrame: screen)
    }

    @Test func originForTheSpacesBar() {
        #expect(OriginClassifier.classify(hit(60)) == .missionControlSpace)
        #expect(OriginClassifier.classify(hit(400)) == .missionControl)
    }

    @Test func targetIsTheTopCenterOfTheScreen() {
        let right = CGRect(x: 1440, y: -90, width: 1920, height: 1080)
        #expect(SpaceDragPlan.target(screen: right) == CGPoint(x: 2400, y: -30))
    }

    @Test func dragSteps() {
        let from = CGPoint(x: 100, y: 60)
        let to = CGPoint(x: 700, y: 60)
        let steps = SpaceDragPlan.steps(from: from, to: to, cursor: from)
        #expect(steps.first == .mouseDown(from))
        let drags = steps.compactMap { if case .drag(let p) = $0 { return p } else { return nil } }
        #expect(drags.count == 6)
        #expect(drags.last == to)
        #expect(Array(steps.suffix(3)) == [.wait(0.3), .mouseUp(to), .warp(from)])
    }

    @Test func onlyOneSwipeMoves() {
        #expect(MissionControlSpaces.direction(for: [.swipe(.right)]) == .right)
        #expect(MissionControlSpaces.direction(for: [.pause, .swipe(.up)]) == .up)
        #expect(MissionControlSpaces.direction(for: [.swipe(.right), .swipe(.left)]) == nil)
        #expect(MissionControlSpaces.direction(for: [.pinchIn]) == nil)
    }
}
